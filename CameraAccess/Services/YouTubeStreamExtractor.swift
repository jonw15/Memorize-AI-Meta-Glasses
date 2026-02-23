/*
 * YouTube Stream Extractor
 * Thin wrapper around YouTubeKit for extracting direct video stream URLs
 */

import Foundation
import YouTubeKit

actor YouTubeStreamExtractor {
    static let shared = YouTubeStreamExtractor()

    /// Cache of video ID → extracted stream URL.
    private var cache: [String: URL] = [:]
    /// In-flight extraction tasks to avoid duplicate work.
    private var pending: [String: Task<URL?, Never>] = [:]

    /// Returns a cached stream URL, or extracts one if not cached.
    func streamURL(videoId: String) async -> URL? {
        if let cached = cache[videoId] {
            print("🎬 [YouTubeStreamExtractor] Cache hit for \(videoId)")
            return cached
        }
        // Join an in-flight extraction if one is already running for this video.
        if let task = pending[videoId] {
            return await task.value
        }
        let task = Task<URL?, Never> { await Self.extract(videoId: videoId) }
        pending[videoId] = task
        let url = await task.value
        pending[videoId] = nil
        if let url { cache[videoId] = url }
        return url
    }

    /// Pre-extract stream URLs for a batch of video IDs sequentially.
    /// Sequential extraction lets the first video cache YouTubeKit's descrambler/
    /// player JS so subsequent extractions are much faster.
    /// Each video's pending task resolves as soon as its own extraction finishes.
    func preExtract(videoIds: [String]) {
        let ids = videoIds.filter { cache[$0] == nil && pending[$0] == nil }
        guard !ids.isEmpty else { return }
        print("🎬 [YouTubeStreamExtractor] Pre-extracting \(ids.count) videos sequentially")
        // Chain tasks: each waits for the previous one, but resolves individually.
        var previousTask: Task<Void, Never>?
        for id in ids {
            let prev = previousTask
            let task = Task<URL?, Never> {
                await prev?.value
                let url = await Self.extract(videoId: id)
                await self.cacheResult(videoId: id, url: url)
                return url
            }
            pending[id] = task
            previousTask = Task<Void, Never> { _ = await task.value }
        }
    }

    /// Store an extraction result and clear its pending state.
    private func cacheResult(videoId: String, url: URL?) {
        pending[videoId] = nil
        if let url { cache[videoId] = url }
    }

    /// Core extraction logic.
    private static func extract(videoId: String) async -> URL? {
        do {
            let video = YouTube(videoID: videoId)
            let allStreams = try await video.streams
            let candidates = allStreams
                .filterVideoAndAudio()
                .filter { $0.isNativelyPlayable }

            for (i, s) in candidates.enumerated() {
                print("🎬 [YouTubeStreamExtractor] candidate[\(i)]: \(s.subtype) \(s.fileExtension) nativelyPlayable=\(s.isNativelyPlayable)")
            }
            print("🎬 [YouTubeStreamExtractor] \(videoId): \(allStreams.count) total streams, \(candidates.count) natively playable with audio+video")

            guard let selected = candidates.lowestResolutionStream() else {
                print("⚠️ [YouTubeStreamExtractor] No natively playable combined stream found for \(videoId)")
                return nil
            }

            print("🎬 [YouTubeStreamExtractor] Selected: \(selected.subtype) \(selected.fileExtension) url=\(selected.url)")
            return selected.url
        } catch {
            print("⚠️ [YouTubeStreamExtractor] Failed to extract stream for \(videoId): \(error)")
            return nil
        }
    }
}
