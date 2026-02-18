import Foundation
import Yams

extension BookmarkStore {
    public static var legacyJsonPath: URL {
        return storePath.deletingLastPathComponent().appendingPathComponent("bookmarks.json")
    }

    /// V1 YAML文字列をV2形式に変換する
    public static func migrateV1YAML(_ yaml: String) throws -> String {
        var result = yaml
        // bundleId → bundleIdPattern (bundleIdPattern already present is safe: no double replace)
        result = result.replacingOccurrences(of: "bundleId:", with: "bundleIdPattern:")
        // type: iterm2 + session → type: app + windowTitle
        result = result.replacingOccurrences(of: "type: iterm2", with: "type: app")
        result = result.replacingOccurrences(of: "session:", with: "windowTitle:")
        // type: generic → type: app (windowTitle stays as-is)
        result = result.replacingOccurrences(of: "type: generic", with: "type: app")
        // url: → urlPattern: (indented, inside state block)
        result = result.replacingOccurrences(of: "  url:", with: "  urlPattern:")
        return result
    }

    public static func loadYAML() -> BookmarkStore {
        // 1. YAMLファイルが存在すればそれを読む (V1→V2マイグレーション付き)
        // 2. YAMLがなくJSONがあれば移行
        // 3. どちらもなければ空のストアを返す

        if FileManager.default.fileExists(atPath: storePath.path) {
            let decoder = YAMLDecoder()
            if let text = try? String(contentsOf: storePath, encoding: .utf8) {
                let migrated = (try? migrateV1YAML(text)) ?? text
                if let store = try? decoder.decode(BookmarkStore.self, from: migrated) {
                    // マイグレーションで変更があれば .bak を作成して保存し直す
                    if migrated != text {
                        let bakPath = storePath.appendingPathExtension("bak")
                        try? text.write(to: bakPath, atomically: true, encoding: .utf8)
                        try? store.saveYAML()
                    }
                    return store
                }
            }
        }

        // JSON移行
        if FileManager.default.fileExists(atPath: legacyJsonPath.path) {
            return migrateFromJSON() ?? BookmarkStore()
        }

        return BookmarkStore()
    }

    private static func migrateFromJSON() -> BookmarkStore? {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: legacyJsonPath),
              let store = try? decoder.decode(BookmarkStore.self, from: data) else {
            return nil
        }
        try? store.saveYAML()
        return store
    }

    public func saveYAML() throws {
        let encoder = YAMLEncoder()
        let text = try encoder.encode(self)
        try text.write(to: BookmarkStore.storePath, atomically: true, encoding: .utf8)
    }
}
