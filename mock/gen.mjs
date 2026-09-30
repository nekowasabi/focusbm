// Generates 5 preview-overlay design mocks as HTML, then renders PNGs with headless Chrome.
// Usage: CHROME=<chrome-headless-shell> node mock/gen.mjs
// Why: google-chrome --headless=new reserves ~88px of browser UI, clipping the bottom; chrome-headless-shell does not.
import { writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const root = join(dir, "..");

// Shared pane content. Tokens: [cls, text]; cls maps to per-design palette.
const panes = [
  {
    idx: 1, title: "focusbm", agent: "Claude Code", host: "mac · ~/repos/focusbm", state: "running",
    lines: [
      [["dim", "> プレビューのフォントサイズを YAML で指定できるようにして"]],
      [],
      [["acc", "● "], ["fg", "Read(Sources/FocusBMApp/AgentScreenPreview.swift)"]],
      [["dim", "  ⎿  Read 191 lines"]],
      [["acc", "● "], ["fg", "Update(Sources/FocusBMLib/Models.swift)"]],
      [["dim", "  ⎿  Updated with 3 additions"]],
      [["dim", "     42 "], ["add", "+    public var previewFontSize: Double?"]],
      [["dim", "     43 "], ["add", "+    public var previewFontName: String?"]],
      [["dim", "     51 "], ["del", "-    let size = 14"]],
      [["acc", "● "], ["fg", "Bash(swift test --filter Preview)"]],
      [["dim", "  ⎿  "], ["ok", "Test Suite passed"], ["dim", " (12 tests, 0.42s)"]],
      [],
      [["warn", "✻ "], ["warn", "Compiling… "], ["dim", "(18s · ↑ 2.1k tokens · esc to interrupt)"]],
    ],
  },
  {
    idx: 2, title: "api-server", agent: "Codex", host: "wsl · ~/work/api", state: "waiting",
    lines: [
      [["dim", "› テストが落ちている原因を調べて"]],
      [],
      [["acc", "• "], ["fg", "Ran "], ["cyan", "go test ./internal/..."]],
      [["dim", "  └ "], ["del", "FAIL internal/auth  TestTokenRefresh"]],
      [["dim", "      expected 200, got 401"]],
      [["acc", "• "], ["fg", "Explored"]],
      [["dim", "  └ Read auth/refresh.go, auth/clock.go"]],
      [],
      [["fg", "原因は clock.Now() をテストで固定していないことです。"]],
      [["fg", "修正方針を 2 つ提示します:"]],
      [["fg", "  1. clock を注入する  "], ["dim", "(推奨)"]],
      [["fg", "  2. 期限判定に許容幅を持たせる"]],
      [],
      [["warn", "▌ 承認待ち: "], ["fg", "どちらで進めますか?"]],
    ],
  },
  {
    idx: 3, title: "dotfiles", agent: "Claude Code", host: "mac · ~/repos/private_dotfiles", state: "idle",
    lines: [
      [["acc", "● "], ["fg", "Done. 3 files changed."]],
      [],
      [["dim", "  zsh/.zshrc           "], ["add", "+4"], ["dim", " "], ["del", "-1"]],
      [["dim", "  tmux/tmux.conf       "], ["add", "+2"]],
      [["dim", "  espanso/match/base.yml "], ["add", "+8"]],
      [],
      [["fg", "コミット計画:"]],
      [["cyan", "  feat(tmux): "], ["fg", "ステータスバーにブランチを表示する"]],
      [["cyan", "  chore(zsh): "], ["fg", "未使用の alias を削除する"]],
      [],
      [["dim", "─────────────────────────────────────"]],
      [["acc", "> "], ["dim", "▍"]],
    ],
  },
  {
    idx: 4, title: "blog", agent: "Codex", host: "wsl · ~/blog", state: "error",
    lines: [
      [["acc", "• "], ["fg", "Ran "], ["cyan", "npm run build"]],
      [["dim", "  └ "], ["del", "Error: Cannot find module 'remark-gfm'"]],
      [["dim", "      at Module._resolveFilename (node:internal)"]],
      [["dim", "      at require (node:internal/modules/cjs)"]],
      [],
      [["fg", "依存が lockfile と一致していません。"]],
      [["acc", "• "], ["fg", "Ran "], ["cyan", "npm ci"]],
      [["dim", "  └ "], ["del", "npm ERR! network ETIMEDOUT"]],
      [],
      [["del", "■ "], ["fg", "ネットワークに接続できないため中断しました"]],
    ],
  },
];

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
const body = (p) =>
  p.lines.map((l) => `<div class="ln">${l.map(([c, t]) => `<span class="${c}">${esc(t)}</span>`).join("") || "&nbsp;"}</div>`).join("");

const FONTS = `<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Noto+Sans+JP:wght@400;500;700&family=Inter:wght@400;500;600;700&display=block" rel="stylesheet">`;
const MONO = `"JetBrains Mono", "IPAGothic", monospace`;
const SANS = `"Inter", "Noto Sans JP", "IPAPGothic", sans-serif`;

const stateLabel = { running: "実行中", waiting: "承認待ち", idle: "待機", error: "エラー" };
const target = 2; // prompt target pane

// Caption strip baked into every image so the user can pick by number.
const caption = (n, name, intent) => `
<div class="cap"><b>案${n}</b><span class="capn">${name}</span><span class="capi">${intent}</span></div>`;
const capCss = `
.cap{position:fixed;left:0;right:0;top:0;height:44px;display:flex;align-items:center;gap:14px;padding:0 24px;
 background:#fff;color:#111;font:500 15px ${SANS};z-index:99;border-bottom:1px solid #ddd}
.cap b{background:#111;color:#fff;padding:3px 10px;border-radius:4px;font-weight:700}
.capn{font-weight:700}.capi{color:#555}
.stage{position:absolute;top:44px;left:0;right:0;bottom:0}`;

const designs = [];

// ---------- 1. Terminal Windows ----------
designs.push({
  slug: "1-terminal-windows",
  name: "ターミナルウィンドウ",
  intent: "各ペインを角丸＋影＋タイトルバーの独立ウィンドウにし、ペイン境界と行間で読みやすさを出す",
  html: () => `
<style>
.stage{background:radial-gradient(ellipse at 50% 30%,#1b1e24,#0b0c0f 70%)}
.card{position:absolute;inset:36px 64px 28px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:22px;height:calc(100% - 118px)}
.win{background:#16181d;border-radius:12px;box-shadow:0 18px 50px rgba(0,0,0,.55),0 0 0 1px rgba(255,255,255,.07);display:flex;flex-direction:column;overflow:hidden}
.win.t{box-shadow:0 18px 50px rgba(0,0,0,.55),0 0 0 2px #5aa9ff,0 0 32px rgba(90,169,255,.35)}
.tb{height:36px;display:flex;align-items:center;gap:8px;padding:0 14px;background:#1f2229;border-bottom:1px solid rgba(255,255,255,.06)}
.dot{width:12px;height:12px;border-radius:50%}
.tb .ttl{flex:1;text-align:center;font:500 13px ${SANS};color:#aab1bd;margin-right:52px}
.kbd{font:600 12px ${MONO};color:#cfd6e2;background:#2c313b;border:1px solid #3a404b;border-bottom-width:2px;border-radius:5px;padding:1px 7px}
.bd{flex:1;padding:14px 18px;font:14px/1.55 ${MONO};color:#d7dae0;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end}
.dim{color:#6b7280}.acc{color:#c792ea}.add{color:#8bd49c}.del{color:#ff7a85}.ok{color:#8bd49c}.warn{color:#f5c26b}.cyan{color:#7fd1e8}.fg{color:#d7dae0}
.dock{margin-top:22px;background:#16181d;border-radius:12px;box-shadow:0 0 0 1px rgba(255,255,255,.1);display:flex;align-items:center;gap:12px;padding:0 16px;height:56px}
.to{font:700 14px ${MONO};color:#5aa9ff}
.ph{flex:1;font:15px ${SANS};color:#6b7280}
.hint{text-align:center;margin-top:12px;font:13px ${SANS};color:#6b7280}
</style>
<div class="stage"><div class="card">
<div class="grid">${panes.map((p) => `
 <div class="win${p.idx === target ? " t" : ""}">
  <div class="tb"><span class="dot" style="background:#ff5f57"></span><span class="dot" style="background:#febc2e"></span><span class="dot" style="background:#28c840"></span>
   <span class="ttl">${p.title} — ${p.agent}</span><span class="kbd">⌃${p.idx}</span></div>
  <div class="bd">${body(p)}</div></div>`).join("")}
</div>
<div class="dock"><span class="to">→ ${target}</span><span class="ph">エージェントへの指示（Enter で送信）</span><span class="kbd">⏎</span></div>
<div class="hint"><span class="kbd">Esc</span> で閉じる　·　<span class="kbd">⌃1</span>–<span class="kbd">⌃4</span> で送信先を選択</div>
</div></div>`,
});

// ---------- 2. Layered surfaces (Tokyo Night) ----------
designs.push({
  slug: "2-layered-surfaces",
  name: "階層サーフェス",
  intent: "純黒をやめ3段階の面色（背景/ペイン/ヘッダー）で奥行きを作り、プロンプトを独立したドックに",
  html: () => `
<style>
.stage{background:#11121a}
.card{position:absolute;inset:32px 56px 24px;background:#16161e;border-radius:16px;padding:18px;display:flex;flex-direction:column}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;flex:1;min-height:0}
.pane{background:#1a1b26;border-radius:10px;display:flex;flex-direction:column;overflow:hidden;border:1px solid #232433}
.pane.t{border-color:#7aa2f7;background:#1c1e2c}
.hd{display:flex;align-items:center;gap:10px;padding:10px 14px;background:#24283b}
.pane.t .hd{background:#2a3150}
.num{width:24px;height:24px;border-radius:6px;background:#414868;color:#c0caf5;font:700 13px/24px ${MONO};text-align:center}
.pane.t .num{background:#7aa2f7;color:#1a1b26}
.nm{font:600 14px ${SANS};color:#c0caf5}.sub{font:12px ${SANS};color:#565f89;margin-left:auto}
.bd{flex:1;padding:12px 16px;font:14px/1.6 ${MONO};color:#a9b1d6;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end}
.dim{color:#565f89}.acc{color:#bb9af7}.add{color:#9ece6a}.del{color:#f7768e}.ok{color:#9ece6a}.warn{color:#e0af68}.cyan{color:#7dcfff}.fg{color:#c0caf5}
.dock{margin-top:14px;background:#24283b;border-radius:12px;padding:12px 14px;display:flex;align-items:center;gap:12px;box-shadow:0 -8px 24px rgba(0,0,0,.25)}
.chip{font:600 13px ${SANS};color:#1a1b26;background:#7aa2f7;border-radius:999px;padding:4px 12px}
.in{flex:1;background:#1a1b26;border-radius:8px;padding:10px 14px;font:15px ${SANS};color:#565f89;border:1px solid #3b4261}
.send{font:600 13px ${SANS};color:#c0caf5;background:#3b4261;border-radius:8px;padding:9px 16px}
.hint{text-align:center;margin-top:10px;font:12px ${SANS};color:#565f89}
</style>
<div class="stage"><div class="card">
<div class="grid">${panes.map((p) => `
 <div class="pane${p.idx === target ? " t" : ""}">
  <div class="hd"><span class="num">${p.idx}</span><span class="nm">${p.title}</span><span class="sub">${p.agent} · ${p.host}</span></div>
  <div class="bd">${body(p)}</div></div>`).join("")}
</div>
<div class="dock"><span class="chip">送信先 ${target} · api-server</span><div class="in">エージェントへの指示（Enter で送信）</div><span class="send">送信 ⏎</span></div>
<div class="hint">Esc で閉じる</div>
</div></div>`,
});

// ---------- 3. Status-driven headers ----------
const stColor = { running: "#4ade80", waiting: "#fbbf24", idle: "#94a3b8", error: "#f87171" };
designs.push({
  slug: "3-status-headers",
  name: "ステータス駆動",
  intent: "巨大な赤番号をやめ、状態ピル（実行中/承認待ち/エラー）で「どれを見るべきか」を一目で分かるように",
  html: () => `
<style>
.stage{background:#0d1117}
.card{position:absolute;inset:30px 56px 24px;display:flex;flex-direction:column}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;flex:1;min-height:0}
.pane{background:#161b22;border:1px solid #30363d;border-radius:10px;display:flex;flex-direction:column;overflow:hidden;position:relative}
.pane::before{content:"";position:absolute;left:0;right:0;top:0;height:3px;background:var(--st)}
.pane.t{border-color:#58a6ff;box-shadow:0 0 0 3px rgba(88,166,255,.25)}
.hd{display:flex;align-items:center;gap:10px;padding:14px 16px 10px}
.num{font:700 12px ${MONO};color:#8b949e;border:1px solid #30363d;border-radius:5px;padding:2px 7px}
.nm{font:600 15px ${SANS};color:#e6edf3}
.ag{font:12px ${SANS};color:#8b949e}
.pill{margin-left:auto;display:flex;align-items:center;gap:6px;font:600 12px ${SANS};color:var(--st);background:color-mix(in srgb,var(--st) 14%,transparent);border-radius:999px;padding:4px 10px}
.pill i{width:7px;height:7px;border-radius:50%;background:var(--st)}
.pane.running .pill i{box-shadow:0 0 0 3px color-mix(in srgb,var(--st) 30%,transparent)}
.bd{flex:1;margin:0 10px 10px;padding:10px 12px;background:#0d1117;border-radius:6px;font:14px/1.55 ${MONO};color:#c9d1d9;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end}
.dim{color:#6e7681}.acc{color:#d2a8ff}.add{color:#7ee787}.del{color:#ffa198}.ok{color:#7ee787}.warn{color:#e3b341}.cyan{color:#79c0ff}.fg{color:#c9d1d9}
.dock{margin-top:16px;display:flex;align-items:center;gap:10px;background:#161b22;border:1px solid #58a6ff;border-radius:10px;padding:0 14px;height:54px}
.to{font:600 13px ${SANS};color:#58a6ff;display:flex;align-items:center;gap:6px}
.to i{width:7px;height:7px;border-radius:50%;background:${stColor.waiting}}
.ph{flex:1;font:15px ${SANS};color:#6e7681}
.err{font:12px ${SANS};color:#ffa198;margin-top:6px}
.hint{display:flex;justify-content:space-between;margin-top:8px;font:12px ${SANS};color:#6e7681}
</style>
<div class="stage"><div class="card">
<div class="grid">${panes.map((p) => `
 <div class="pane ${p.state}${p.idx === target ? " t" : ""}" style="--st:${stColor[p.state]}">
  <div class="hd"><span class="num">${p.idx}</span><span class="nm">${p.title}</span><span class="ag">${p.agent}</span>
   <span class="pill"><i></i>${stateLabel[p.state]}</span></div>
  <div class="bd">${body(p)}</div></div>`).join("")}
</div>
<div class="dock"><span class="to"><i></i>→ 2 api-server</span><span class="ph">エージェントへの指示（Enter で送信）</span></div>
<div class="hint"><span>⌃1–⌃4 送信先を切替</span><span>Esc で閉じる</span></div>
</div></div>`,
});

// ---------- 4. Editorial focus ----------
designs.push({
  slug: "4-focus-editorial",
  name: "フォーカス＋可読性重視",
  intent: "送信先ペインを大きく、他を縮小サムネイル化。大きめの文字・広い行間・左レールで長文を読みやすく",
  html: () => {
    const main = panes.find((p) => p.idx === target);
    const rest = panes.filter((p) => p.idx !== target);
    return `
<style>
.stage{background:#0f0f10}
.card{position:absolute;inset:30px 56px 24px;display:grid;grid-template-columns:1fr 380px;gap:20px}
.main{background:#18181b;border-radius:14px;display:flex;flex-direction:column;overflow:hidden;border-left:4px solid #f59e0b}
.mh{padding:20px 28px 8px;display:flex;align-items:baseline;gap:14px}
.mn{font:700 26px ${SANS};color:#fafafa}.ms{font:14px ${SANS};color:#71717a}
.mb{flex:1;padding:10px 28px 20px;font:17px/1.75 ${MONO};color:#e4e4e7;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end}
.mb .ln:not(:nth-last-child(-n+6)){opacity:.55}
.dim{color:#71717a}.acc{color:#fbbf24}.add{color:#86efac}.del{color:#fca5a5}.ok{color:#86efac}.warn{color:#fbbf24}.cyan{color:#93c5fd}.fg{color:#e4e4e7}
.dock{margin:0 20px 20px;display:flex;align-items:center;gap:12px;background:#f59e0b;border-radius:10px;padding:14px 18px}
.dock .ph{flex:1;font:500 16px ${SANS};color:#422006}.dock .k{font:700 13px ${MONO};color:#422006;background:rgba(0,0,0,.12);border-radius:5px;padding:3px 8px}
.side{display:flex;flex-direction:column;gap:14px;min-height:0}
.th{flex:1;background:#18181b;border-radius:12px;overflow:hidden;display:flex;flex-direction:column;border:1px solid #27272a}
.th .h{display:flex;align-items:center;gap:10px;padding:10px 14px}
.th .k{font:700 12px ${MONO};color:#a1a1aa;background:#27272a;border-radius:5px;padding:2px 7px}
.th .n{font:600 14px ${SANS};color:#e4e4e7}.th .s{margin-left:auto;font:12px ${SANS};color:#71717a}
.th .b{flex:1;padding:0 14px 10px;font:11px/1.45 ${MONO};color:#a1a1aa;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end;
 -webkit-mask-image:linear-gradient(to bottom,transparent,#000 40%)}
.hint{font:12px ${SANS};color:#52525b;text-align:right}
</style>
<div class="stage"><div class="card">
 <div class="main">
  <div class="mh"><span class="mn">${main.title}</span><span class="ms">${main.agent} · ${main.host} · ⌃${main.idx}</span></div>
  <div class="mb">${body(main)}</div>
  <div class="dock"><span class="ph">エージェントへの指示（Enter で送信）</span><span class="k">⏎</span></div>
 </div>
 <div class="side">${rest.map((p) => `
  <div class="th"><div class="h"><span class="k">⌃${p.idx}</span><span class="n">${p.title}</span><span class="s">${stateLabel[p.state]}</span></div><div class="b">${body(p)}</div></div>`).join("")}
  <div class="hint">⌃数字 で切替　·　Esc で閉じる</div>
 </div>
</div></div>`;
  },
});

// ---------- 5. Glass / vibrancy ----------
designs.push({
  slug: "5-glass",
  name: "グラス（半透明）",
  intent: "背後のデスクトップをぼかして透過。浮遊感と軽さを出し、黒一色の圧迫感をなくす（Winは実装コスト高）",
  html: () => `
<style>
.stage{overflow:hidden}
.wall{position:absolute;inset:-40px;background:
 radial-gradient(circle at 20% 25%,#6d5dfc 0,transparent 40%),
 radial-gradient(circle at 80% 20%,#ff6b9a 0,transparent 38%),
 radial-gradient(circle at 60% 85%,#1fc8db 0,transparent 42%),#1c1f3a;filter:blur(30px)}
.fakewin{position:absolute;background:rgba(255,255,255,.75);border-radius:10px}
.veil{position:absolute;inset:0;background:rgba(10,12,24,.35);backdrop-filter:blur(40px)}
.card{position:absolute;inset:34px 60px 26px;display:flex;flex-direction:column}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;flex:1;min-height:0}
.pane{background:rgba(20,22,36,.62);backdrop-filter:blur(24px) saturate(160%);border-radius:16px;border:1px solid rgba(255,255,255,.12);
 box-shadow:inset 0 1px 0 rgba(255,255,255,.12),0 20px 40px rgba(0,0,0,.3);display:flex;flex-direction:column;overflow:hidden}
.pane.t{border-color:rgba(255,255,255,.55);box-shadow:inset 0 1px 0 rgba(255,255,255,.2),0 0 0 1px rgba(255,255,255,.35),0 20px 50px rgba(109,93,252,.45)}
.hd{display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid rgba(255,255,255,.08)}
.num{width:26px;height:26px;border-radius:50%;background:rgba(255,255,255,.14);color:#fff;font:600 13px/26px ${SANS};text-align:center}
.pane.t .num{background:#fff;color:#1c1f3a}
.nm{font:600 15px ${SANS};color:#fff}.sub{margin-left:auto;font:12px ${SANS};color:rgba(255,255,255,.55)}
.bd{flex:1;padding:12px 18px;font:14px/1.6 ${MONO};color:#eef0ff;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end;text-shadow:0 1px 1px rgba(0,0,0,.3)}
.dim{color:rgba(230,232,255,.5)}.acc{color:#c4b5fd}.add{color:#86efac}.del{color:#fda4af}.ok{color:#86efac}.warn{color:#fde68a}.cyan{color:#a5f3fc}.fg{color:#eef0ff}
.dock{margin:18px auto 0;width:62%;display:flex;align-items:center;gap:12px;padding:12px 18px;border-radius:999px;background:rgba(255,255,255,.14);
 backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,.25)}
.to{font:600 13px ${SANS};color:#1c1f3a;background:#fff;border-radius:999px;padding:4px 12px}
.ph{flex:1;font:15px ${SANS};color:rgba(255,255,255,.7)}
.hint{text-align:center;margin-top:10px;font:12px ${SANS};color:rgba(255,255,255,.55)}
</style>
<div class="stage"><div class="wall"></div>
<div class="fakewin" style="left:8%;top:12%;width:34%;height:40%"></div><div class="fakewin" style="left:52%;top:40%;width:40%;height:45%;background:rgba(40,44,60,.9)"></div>
<div class="veil"></div>
<div class="card">
<div class="grid">${panes.map((p) => `
 <div class="pane${p.idx === target ? " t" : ""}">
  <div class="hd"><span class="num">${p.idx}</span><span class="nm">${p.title}</span><span class="sub">${p.agent} · ${stateLabel[p.state]}</span></div>
  <div class="bd">${body(p)}</div></div>`).join("")}
</div>
<div class="dock"><span class="to">→ ${target}</span><span class="ph">エージェントへの指示（Enter で送信）</span></div>
<div class="hint">Esc で閉じる</div>
</div></div>`,
});

// ---------- 3x. Status-driven + big index number (round 2) ----------
// Why: pane count is variable, so the index must sit next to the content (not top-left) to avoid an eye jump.
const extraPanes = [
  { idx: 5, title: "infra", agent: "Claude Code", state: "running", lines: [
    [["acc", "● "], ["fg", "Bash(terraform plan)"]],
    [["dim", "  ⎿  Plan: "], ["add", "2 to add"], ["dim", ", "], ["warn", "1 to change"], ["dim", ", 0 to destroy"]],
    [["warn", "✻ "], ["warn", "Reviewing… "], ["dim", "(6s)"]],
  ] },
  { idx: 6, title: "docs", agent: "Codex", state: "idle", lines: [
    [["acc", "• "], ["fg", "README_ja.md を更新しました"]],
    [["dim", "  └ 2 sections, +38 -12"]],
    [["acc", "› "], ["dim", "▍"]],
  ] },
];
const allPanes = [...panes, ...extraPanes];

const bigCss = {
  // A: low-opacity watermark in the state color, bottom-right (next to the newest line).
  a: `.big{position:absolute;right:18px;bottom:2px;font:800 min(150px,46cqh)/1 ${SANS};letter-spacing:-.04em;color:var(--st);opacity:.22;pointer-events:none}
      .pane.t .big{opacity:.4}`,
  // B: dedicated right rail; the number never overlaps text.
  b: `.big{flex:0 0 min(120px,30cqh);display:flex;align-items:flex-end;justify-content:center;padding-bottom:8px;border-left:1px solid #21262d;
      font:800 min(96px,40cqh)/1 ${SANS};letter-spacing:-.04em;color:#e6edf3;opacity:.9}
      .pane.t .big{color:#58a6ff;opacity:1}`,
  // C: solid tile in the bottom-right corner.
  c: `.big{position:absolute;right:12px;bottom:12px;width:min(104px,40cqh);height:min(104px,40cqh);border-radius:16px;display:grid;place-items:center;
      background:#21262d;border:1px solid #30363d;font:800 min(68px,27cqh)/1 ${SANS};color:#e6edf3;box-shadow:0 8px 24px rgba(0,0,0,.4)}
      .pane.t .big{background:#58a6ff;border-color:#58a6ff;color:#0d1117}`,
};
const design3 = (v, list) => {
  const rows = Math.ceil(list.length / 2);
  return `
<style>
.stage{background:#0d1117}
.card{position:absolute;inset:30px 56px 24px;display:flex;flex-direction:column}
.grid{display:grid;grid-template-columns:1fr 1fr;grid-template-rows:repeat(${rows},minmax(0,1fr));gap:16px;flex:1;min-height:0}
.pane{background:#161b22;border:1px solid #30363d;border-radius:10px;display:flex;flex-direction:column;overflow:hidden;position:relative;min-height:0}
.pane::before{content:"";position:absolute;left:0;right:0;top:0;height:3px;background:var(--st)}
.pane.t{border-color:#58a6ff;box-shadow:0 0 0 3px rgba(88,166,255,.25)}
.hd{display:flex;align-items:center;gap:10px;padding:12px 16px 8px}
.nm{font:600 15px ${SANS};color:#e6edf3}
.ag{font:12px ${SANS};color:#8b949e}
.pill{margin-left:auto;display:flex;align-items:center;gap:6px;font:600 12px ${SANS};color:var(--st);background:color-mix(in srgb,var(--st) 14%,transparent);border-radius:999px;padding:4px 10px}
.pill i{width:7px;height:7px;border-radius:50%;background:var(--st)}
.bw{flex:1;min-height:0;margin:0 10px 10px;background:#0d1117;border-radius:6px;display:flex;position:relative;container-type:size;overflow:hidden}
.bd{flex:1;min-width:0;padding:10px 12px;font:14px/1.55 ${MONO};color:#c9d1d9;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end}
.dim{color:#6e7681}.acc{color:#d2a8ff}.add{color:#7ee787}.del{color:#ffa198}.ok{color:#7ee787}.warn{color:#e3b341}.cyan{color:#79c0ff}.fg{color:#c9d1d9}
${bigCss[v]}
.dock{margin-top:16px;display:flex;align-items:center;gap:10px;background:#161b22;border:1px solid #58a6ff;border-radius:10px;padding:0 14px;height:54px}
.to{font:600 13px ${SANS};color:#58a6ff;display:flex;align-items:center;gap:6px}
.to i{width:7px;height:7px;border-radius:50%;background:${stColor.waiting}}
.ph{flex:1;font:15px ${SANS};color:#6e7681}
.hint{display:flex;justify-content:space-between;margin-top:8px;font:12px ${SANS};color:#6e7681}
</style>
<div class="stage"><div class="card">
<div class="grid">${list.map((p) => `
 <div class="pane ${p.state}${p.idx === target ? " t" : ""}" style="--st:${stColor[p.state]}">
  <div class="hd"><span class="nm">${p.title}</span><span class="ag">${p.agent}</span>
   <span class="pill"><i></i>${stateLabel[p.state]}</span></div>
  <div class="bw"><div class="bd">${body(p)}</div><div class="big">${p.idx}</div></div></div>`).join("")}
</div>
<div class="dock"><span class="to"><i></i>→ 2 api-server</span><span class="ph">エージェントへの指示（Enter で送信）</span></div>
<div class="hint"><span>⌃1–⌃${list.length} 送信先を切替</span><span>Esc で閉じる</span></div>
</div></div>`;
};
designs.push(
  { slug: "3a-watermark", name: "3A 透かし番号", intent: "状態色の大きな番号を右下に薄く重ねる。最新行のすぐ横に番号があり、目線移動が最小", html: () => design3("a", panes) },
  { slug: "3b-rail", name: "3B 番号レール", intent: "右端に番号専用の列を設け、本文と重ならない。送信先だけ青で強調", html: () => design3("b", panes) },
  { slug: "3c-tile", name: "3C 番号タイル", intent: "右下に角丸タイルで番号を置く。送信先はタイルを塗りつぶして一目で分かる", html: () => design3("c", panes) },
  { slug: "3a-watermark-2panes", name: "3A × 2ペイン", intent: "ペインが少ないとき：番号は上限サイズで止まる", html: () => design3("a", allPanes.slice(0, 2)) },
  { slug: "3a-watermark-6panes", name: "3A × 6ペイン", intent: "ペインが多いとき：番号はペインの高さに合わせて縮む", html: () => design3("a", allPanes) },
);

const chrome = process.env.CHROME ?? "/usr/bin/google-chrome";
for (const d of designs.filter((d) => !process.env.ONLY || d.slug.startsWith(process.env.ONLY))) {
  const n = d.slug.split("-")[0];
  const html = `<!doctype html><html lang="ja"><head><meta charset="utf-8">${FONTS}
<style>*{box-sizing:border-box;margin:0}html,body{width:1920px;height:1124px;overflow:hidden;background:#000}body{position:relative}.cap{position:absolute!important}.ln{flex-shrink:0;white-space:pre;overflow:hidden;text-overflow:ellipsis}${capCss}</style>
</head><body>${caption(n, d.name, d.intent)}${d.html()}</body></html>`;
  const htmlPath = join(dir, `preview-${d.slug}.html`);
  writeFileSync(htmlPath, html);
  const png = join(root, "assets", `mock-preview-${d.slug}.png`);
  execFileSync(chrome, ["--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--window-size=1920,1124",
    "--virtual-time-budget=6000", `--screenshot=${png}`, `file://${htmlPath}`], { stdio: "ignore" });
  console.log(png);
}
