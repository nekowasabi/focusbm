---
title: "ローマ字絞り込み（案 B）実装計画"
status: planning
created: "2026-08-15"
---

# ローマ字絞り込み（案 B）実装計画

jsmigemo の runtime を FocusBMLib に Swift 移植し、既存 fuzzy と OR する。gomigemo は移植しない。辞書は MIT の `migemo-compact-dict`（約 1.4MB）をバンドルする。

---

## Commander's Intent

**Purpose**: 絞り込みパネルで `kensaku` と打つと「検索 / けんさく / ケンサク」が当たる。英語エイリアスの既存 fuzzy は壊さない。

**End State**:
- `swift test` 全 green
- `kensaku` が `検索` に当たるテストが FocusBMLib にある
- ブックマークの browser `title` / app `windowTitle` / `urlPattern` も検索対象
- 辞書欠落・パース失敗時は fuzzy のみでパネルが開く
- autoExecute は fuzzy 単独 1 件のときだけ発火

**非目標**:
- gomigemo / SKK-JISYO.L の移植
- Raycast / Alfred への同時展開
- YAML 設定フラグ
- IME を日本語のままにする変更

---

## 確定判断（実装中に再質問しない）

| ID | 判断 | 内容 |
|---|---|---|
| D1 | 移植元 | [oguna/jsmigemo](https://github.com/oguna/jsmigemo) runtime。gomigemo は使わない |
| D2 | 辞書 | 同リポジトリの `migemo-compact-dict`（1,384,379 bytes）。[yet-another-migemo-dict](https://github.com/oguna/yet-another-migemo-dict) 由来で MIT |
| D3 | 移植範囲 | runtime のみ。Builder / DoubleArray / RomajiProcessor1 は移植しない |
| D4 | 公開 API | `MigemoEngine.shared.regex(for:)` と `BookmarkSearcher.matches`。jsmigemo の `setRxop` は持たない（デフォルト演算子固定） |
| D5 | マッチ合成 | fuzzy OR migemo。スコアは `fuzzyScore ?? (migemo ? 1 : nil)` |
| D6 | 検索フィールド | `SearchItem.searchableTexts` に集約。bookmark は id / appName / context / title / windowTitle / urlPattern |
| D7 | autoExecute | `fuzzy` だけで 1 件のときのみ。migemo だけのヒットでは発火しない |
| D8 | 正規表現 | `NSRegularExpression`、`.caseInsensitive`、アンカーなし（部分一致） |
| D9 | キャッシュ | 直近 8 クエリの compiled regex。キー入力は差分 1 文字なのでほぼヒットする |
| D10 | ロード | `applicationDidFinishLaunching` でバックグラウンド warmup。失敗時 `engine == nil` で fuzzy のみ |
| D11 | エンディアン | JS `DataView.getUint32` は big-endian。Swift も big-endian で読む |
| D12 | 設定 | 常時 ON。YAML フラグは作らない |
| D13 | ライセンス表示 | `Sources/FocusBMLib/Resources/THIRD_PARTY_NOTICES.md` に jsmigemo / yet-another-migemo-dict の MIT を残す |

---

## ★ Constants

| 名前 | 値 | 単位 | 使う Process |
|---|---|---|---|
| `MIGEMO_REGEX_CACHE_LIMIT` | 8 | 件 | P1, P3 |
| `MIGEMO_ONLY_HIT_SCORE` | 1 | 点 | P2 |
| `MIGEMO_DICT_RESOURCE_NAME` | `migemo-compact-dict` | ファイル名 | P1, P4 |
| `MIGEMO_DICT_EXPECTED_MIN_BYTES` | 1_000_000 | byte | P1 |
| `AUTO_EXECUTE_REQUIRES_FUZZY` | true | flag | P3 |

---

## 移植マップ（jsmigemo → Swift）

移植する（runtime）:

| 元ファイル | 行数目安 | Swift 先 |
|---|---|---|
| `BitList.ts` | 1.1K | `Sources/FocusBMLib/Migemo/BitList.swift` |
| `BitVector.ts` | 5.1K | `Sources/FocusBMLib/Migemo/BitVector.swift` |
| `utils.ts`（binarySearch） | 2.0K の一部 | `Sources/FocusBMLib/Migemo/MigemoUtils.swift` |
| `CompactHiraganaString.ts` | 1.3K | `Sources/FocusBMLib/Migemo/CompactHiraganaString.swift` |
| `LOUDSTrie.ts` | 2.4K | `Sources/FocusBMLib/Migemo/LOUDSTrie.swift` |
| `CompactDictionary.ts` | 4.9K | `Sources/FocusBMLib/Migemo/CompactDictionary.swift` |
| `CharacterConverter.ts` | 4.8K | `Sources/FocusBMLib/Migemo/CharacterConverter.swift` |
| `RomajiProcessor.ts` + `RomajiProcessor2.ts` | 14K | `Sources/FocusBMLib/Migemo/RomajiProcessor.swift` |
| `TernaryRegexGenerator.ts` | 6.1K | `Sources/FocusBMLib/Migemo/TernaryRegexGenerator.swift` |
| `Migemo.ts` | 3.1K | `Sources/FocusBMLib/Migemo/Migemo.swift` |

ファサード（新規）:

| ファイル | 役割 |
|---|---|
| `Sources/FocusBMLib/Migemo/MigemoEngine.swift` | 辞書ロード、`regex(for:)`、8 件キャッシュ、失敗時 nil |
| `Sources/FocusBMLib/Resources/migemo-compact-dict` | バイナリ辞書 |
| `Sources/FocusBMLib/Resources/THIRD_PARTY_NOTICES.md` | MIT 表記 |

移植しない: `CompactDictionaryBuilder` / `LOUDSTrieBuilder` / `DoubleArray` / `RomajiProcessor1` / jsmigemo CLI。

アルゴリズムは jsmigemo を直訳する。独自圧縮や演算子変更はしない。golden は `migemo.query("kensaku")` が次を含むこと:

```
kensaku | けんさく | ケンサク | 検索
```

（完全一致文字列は jsmigemo の生成結果を実装時に 1 回取得してテストへ固定する。）

---

## 既存コードへの差し込み

### 1. `BookmarkSearcher`（`Models.swift` 294–329）

```swift
public static func matches(text: String, query: String) -> Bool {
    if fuzzyScore(text: text, query: query) != nil { return true }
    return MigemoEngine.shared.matches(text, query: query)
}

public static func score(text: String, query: String) -> Int? {
    if let s = fuzzyScore(text: text, query: query) { return s }
    return MigemoEngine.shared.matches(text, query: query) ? MIGEMO_ONLY_HIT_SCORE : nil
}

public static func filter(bookmarks: [Bookmark], query: String) -> [Bookmark] {
    // texts = bookmark.searchableTexts
    // score = texts.compactMap { score(text:$0, query:query) }.max()
}
```

`filter` の対象を `id, appName, context` から `Bookmark.searchableTexts` に替える。

### 2. `Bookmark.searchableTexts` / `SearchItem.searchableTexts`

bookmark:
- `id`, `appName`, `context`
- `.browser`: `title`, `urlPattern`
- `.app`: `windowTitle`
- `.floatingWindows`: なし（エントリ側で見る）

SearchItem:
- `.bookmark`: 上記
- `.floatingWindow`: `[displayName]`
- `.tmuxPane`: `[displayName]`
- `.aiProcess`: `[command, workingDirectory, terminalAppName ?? ""]`

空文字は配列に入れない。

### 3. `SearchViewModel.updateItems`（252–297 行）

クエリあり分岐の 4 本の `fuzzyScore` / `filter` を次に統一する。

```swift
func itemMatches(_ item: SearchItem) -> Bool {
    item.searchableTexts.contains { BookmarkSearcher.matches(text: $0, query: query) }
}
```

- floating / tmux / aiProcess: `itemMatches`
- 通常 bookmark: `BookmarkSearcher.filter`（スコア順維持）

autoExecute 条件を追加:

```
allowAutoExecute
&& searchItems.count == 1
&& !query.isEmpty
&& autoExecuteOnSingleResult
&& その 1 件が fuzzy でも当たっている
```

`fuzzy` 判定: `item.searchableTexts.contains { fuzzyScore($0, query) != nil }`。

### 4. `Package.swift`

`FocusBMLib` に:

```swift
resources: [
    .copy("Resources/migemo-compact-dict"),
    .copy("Resources/THIRD_PARTY_NOTICES.md"),
]
```

テストターゲットは `FocusBMLib` 依存のまま（`Bundle.module` で辞書に届く）。

### 5. `FocusBMApp.applicationDidFinishLaunching`

`setupStatusItem()` の前後で:

```swift
DispatchQueue.global(qos: .utility).async {
    MigemoEngine.shared.warmup()
}
```

`query.didSet` ではロードしない。

---

## 振る舞い仕様

### 変換（query → 候補）

| 入力 query | 対象テキスト | 結果 |
|---|---|---|
| `""` | 任意 | 全件（現行どおり。Migemo 不使用） |
| `safari` | `Safari` | hit（fuzzy） |
| `SAFARI` | `Safari` | hit（fuzzy、現行テスト維持） |
| `kensaku` | `検索` | hit（migemo） |
| `kensaku` | `けんさく` | hit（migemo） |
| `kensaku` | `ケンサク` | hit（migemo） |
| `nihongo` | bookmark title `日本語ドキュメント` | hit（フィールド拡張 + migemo） |
| `doc` | id `docs` | hit（fuzzy、現行テスト維持） |
| `xyzzy` | どのテキストにも部分もサブシーケンスも無い | miss |
| `ka` | `検索` と `Safari` | 両方 hit し得る。1 件にならなければ autoExecute しない |

### autoExecute

| 候補 | fuzzy ヒット | migemo ヒット | autoExecute |
|---|---|---|---|
| 0 件 | - | - | しない |
| 2 件以上 | 任意 | 任意 | しない |
| 1 件 | yes | 任意 | する（設定 ON 時） |
| 1 件 | no | yes | **しない** |

### 失敗時

| 状態 | 挙動 |
|---|---|
| 辞書ファイル欠落 | `MigemoEngine.shared` は利用不可。fuzzy のみ。ログ 1 行。パネルは開く |
| 辞書バイト列が壊れている | 同上 |
| 生成パターンが `NSRegularExpression` でコンパイル失敗 | そのクエリは fuzzy のみ。キャッシュしない |
| warmup 完了前の最初のキー | fuzzy のみ。完了後の次キーから migemo 有効（レースは許容。完了後は cache 済み engine を読む） |

`MigemoEngine` はメインスレッドから読んでもよいよう、ロード完了を `os_unfair_lock` または `NSLock` で保護する。ロード中の `matches` は false（fuzzy 側がカバー）。

---

## Process DAG

```
P1 エンジン移植 + golden テスト
  → P2 BookmarkSearcher / searchableTexts
    → P3 SearchViewModel 統一 + autoExecute
      → P4 リソース同梱・起動 warmup・NOTICE
        → P5 回帰確認
```

直列。同一モジュールの検索経路を共有するため並列化しない。

### P1 — Migemo runtime

**Red**: `Tests/focusbmTests/MigemoTests.swift`
- 辞書を `Bundle.module` から読める
- `query("kensaku")` の生成文字列が `けんさく` `ケンサク` `検索` `kensaku` を含む
- `regex(for: "kensaku")` が `"日本語の検索エンジン"` にマッチし `"English only"` にマッチしない
- 空文字 query はパターン空 / match false
- キャッシュ 8 件: 9 件目投入後も直近はヒット（内部テストで可。公開 API を増やしすぎない）

**Green**: jsmigemo runtime 直訳 + `MigemoEngine`
- `Data` を big-endian で読む
- `RomajiProcessor2.build()` 相当を起動時 1 回
- デフォルト regex 演算子 `| ( ) [ ]` 、escape `\.[]{}()*+-?^$|`

**完了条件**: 上記テスト green。`swift test --filter MigemoTests`

### P2 — Searcher

**Red**: `Tests/focusbmTests/BookmarkRestorerTests.swift` に追加（または `BookmarkSearcherTests.swift` 新設）
- 現行 5 本（empty / id / appName / context / caseInsensitive）は残す
- `title: "日本語ドキュメント"` の browser bookmark に `nihongo` で当たる
- `windowTitle: "設定"` の app bookmark に `settei` で当たる
- `urlPattern: "example.jp/検索"` に `kensaku` で当たる
- `id: "docs"` に `doc` は従来どおり（fuzzy スコア順）

**Green**: `searchableTexts` + `matches` / `score` / `filter` 更新

**完了条件**: 新旧テスト green。`SearchItem.searchableTexts` のユニットも 4 case 分。

### P3 — ViewModel

**Red**: `Tests/FocusBMAppTests/SearchViewModelOrderingTests.swift` または新ファイル
- tmux `displayName` に日本語が含まれるケースで `kensaku` が残る
- 候補が migemo だけの 1 件のとき `autoExecute` ワークアイテムが組まれない
- 候補が fuzzy の 1 件のとき従来どおり組まれる
- 既存 `query = "g"` / `"claude"` / `"chrome"` の順序テストは壊さない

**Green**: `updateItems` を `searchableTexts` + `matches` に置換。autoExecute に fuzzy ガード。

**完了条件**: FocusBMAppTests + focusbmTests green。

### P4 — バンドルと起動

- `Package.swift` resources
- `curl` で jsmigemo の `migemo-compact-dict` を `Sources/FocusBMLib/Resources/` へ配置（git 管理する）
- `THIRD_PARTY_NOTICES.md`
- `applicationDidFinishLaunching` で warmup
- README_ja.md に「ローマ字で日本語を絞り込める」を 2–3 行。マニュアル長文は書かない

**完了条件**: `swift build` がリソースを埋め込む。`Bundle.module.url(forResource:withExtension:)` が非 nil。

### P5 — 回帰

```
swift test
```

既存 BookmarkSearcher / SearchViewModel / ShortcutBar が全部 green。手動: パネルを開き `kensaku` および `safari` を打つ。

---

## 実装メモ（落とし穴）

1. **JS `charCodeAt` = UTF-16 code unit**。Swift では `String.utf16` で辿る。`Character` で回すとサロゲートでずれる。
2. **`DataView` の 64bit word 並び**。`CompactDictionary` は `words[i*2+1]` に先に読んだ u32、`words[i*2]` に次の u32 を入れる。この入れ替えを落とすと trie が壊れる。
3. **`predictiveSearch` の `keyIndex > 1`**。jsmigemo の条件をそのまま残す（`>=` にしない）。
4. **`parseQuery`** の正規表現 `/[^A-Z\s]+|[A-Z]{2,}|([A-Z][^A-Z\s]+)|([A-Z]\s*$)/g` も直訳。CamelCase 分割はこれに任せる。
5. **SPM `Bundle.module`** は `FocusBMLib` をライブラリにしたときだけ有効。テストも同モジュール経由。
6. **辞書 1.4MB** を毎回コピーしない。`Data(contentsOf:options:.mappedIfSafe)`。
7. **メインスレッド**で辞書パースしない。warmup は utility キュー。
8. **autoExecute の誤発火**が最大の UX リスク。P3 のテストを省略しない。

---

## ファイル一覧（予定）

追加:
- `Sources/FocusBMLib/Migemo/*.swift`（約 11 ファイル）
- `Sources/FocusBMLib/Resources/migemo-compact-dict`
- `Sources/FocusBMLib/Resources/THIRD_PARTY_NOTICES.md`
- `Tests/focusbmTests/MigemoTests.swift`
- `Tests/focusbmTests/BookmarkSearcherTests.swift`（既存テストを移すかは任意。退行しなければ追加で可）
- `Tests/FocusBMAppTests/SearchViewModelMigemoTests.swift`

変更:
- `Package.swift`（resources）
- `Sources/FocusBMLib/Models.swift`（searchableTexts, BookmarkSearcher）
- `Sources/FocusBMApp/SearchViewModel.swift`（updateItems, autoExecute）
- `Sources/FocusBMApp/FocusBMApp.swift`（warmup）
- `README_ja.md`（短い追記）

触らない:
- `SearchPanel` の ASCII IME 切替
- ショートカットバー
- Raycast / Alfred
- YAML スキーマ

---

## Verification

| Gate | コマンド / 確認 |
|---|---|
| G1 | `swift test --filter MigemoTests` exit 0 |
| G2 | `swift test --filter BookmarkSearcher` および既存 `test_searchFilter_*` exit 0 |
| G3 | `swift test --filter SearchViewModel` exit 0 |
| G4 | `swift test` 全件 exit 0 |
| G5 | 手動: パネルで `kensaku` が日本語タイトルに当たる / `safari` が従来どおり / migemo 1 件だけでは自動実行しない |

---

## Left to Implementation（外部挙動に影響しないもの）

- `MigemoEngine` のロックを `NSLock` にするか `os_unfair_lock` にするか
- `BookmarkSearcher` を `Models.swift` から別ファイルへ分けるか（分けるなら移動のみ、API 不変）
- golden パターン全文をテストに貼るか、部分包含アサーションにするか（部分包含でよい。必須部分は `けんさく` `ケンサク` `検索` `kensaku`）
- 既存 `test_searchFilter_*` を新ファイルへ移すか

---

## 実装プロンプト

```
案Bで実装する。jsmigemo runtime を Sources/FocusBMLib/Migemo/ に直訳し、
migemo-compact-dict を Bundle.module に入れる。gomigemo / SKK は使わない。
BookmarkSearcher は fuzzy OR migemo。スコアは fuzzy ?? 1。
SearchItem.searchableTexts を導入し bookmark の title/windowTitle/url も見る。
autoExecute は fuzzy 単独1件のときだけ。辞書は起動時 warmup、失敗時は fuzzy のみ。
NSRegularExpression + caseInsensitive。辞書読みは big-endian（JS DataView 互換）。
テスト: kensaku→検索/けんさく、safari 退行なし、title「日本語」に nihongo、
migemo-only 1件では autoExecute しない。swift test 全 green。
```
