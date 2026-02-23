/*
 * JSCache — Persistent disk cache for YouTube player JavaScript.
 *
 * YouTube's player JS (~1-2 MB) changes every few weeks. Caching it on disk
 * avoids a re-download on every app launch, saving ~3-5 seconds on first
 * stream extraction per session.
 */

import Foundation

enum JSCache {

    private static let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YouTubeKit", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let metadataFile: URL = cacheDir.appendingPathComponent("js_metadata.json")

    // MARK: - Public

    /// Load cached player JS if the URL matches (same player version).
    static func load(forURL url: URL) -> String? {
        guard let meta = loadMetadata(), meta == url.absoluteString else { return nil }
        let jsFile = cacheDir.appendingPathComponent("player.js")
        guard let js = try? String(contentsOf: jsFile, encoding: .utf8), !js.isEmpty else { return nil }
        print("🎬 [JSCache] Disk cache hit for \(url.lastPathComponent)")
        return js
    }

    /// Persist player JS to disk alongside its URL for version matching.
    static func save(_ js: String, forURL url: URL) {
        let jsFile = cacheDir.appendingPathComponent("player.js")
        try? js.write(to: jsFile, atomically: true, encoding: .utf8)
        saveMetadata(url.absoluteString)
        print("🎬 [JSCache] Saved player JS to disk (\(js.count) bytes, \(url.lastPathComponent))")
    }

    /// Clear disk cache (called when signature decryption fails to force re-download).
    static func clear() {
        let jsFile = cacheDir.appendingPathComponent("player.js")
        try? FileManager.default.removeItem(at: jsFile)
        try? FileManager.default.removeItem(at: metadataFile)
        print("🎬 [JSCache] Disk cache cleared")
    }

    // MARK: - Private

    private static func loadMetadata() -> String? {
        guard let data = try? Data(contentsOf: metadataFile),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return dict["jsURL"]
    }

    private static func saveMetadata(_ urlString: String) {
        let dict = ["jsURL": urlString]
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: metadataFile, options: .atomic)
    }
}
