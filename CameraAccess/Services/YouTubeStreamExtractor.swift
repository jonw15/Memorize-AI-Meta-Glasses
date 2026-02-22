/*
 * YouTube Stream Extractor
 * Thin wrapper around YouTubeKit for extracting direct video stream URLs
 */

import Foundation
import YouTubeKit

struct YouTubeStreamExtractor {
    /// Extracts a direct streaming URL for the given YouTube video ID.
    /// Returns nil on failure (caller should fall back to WKWebView).
    /// Prefers the lowest resolution natively-playable combined stream to minimize buffering.
    static func extractStreamURL(videoId: String) async -> URL? {
        do {
            let video = YouTube(videoID: videoId)
            let allStreams = try await video.streams
            let candidates = allStreams
                .filterVideoAndAudio()
                .filter { $0.isNativelyPlayable }

            // Log all candidates so we can see what's available
            for (i, s) in candidates.enumerated() {
                print("🎬 [YouTubeStreamExtractor] candidate[\(i)]: \(s.subtype) \(s.fileExtension) nativelyPlayable=\(s.isNativelyPlayable)")
            }
            print("🎬 [YouTubeStreamExtractor] \(videoId): \(allStreams.count) total streams, \(candidates.count) natively playable with audio+video")

            // Pick lowest resolution to reduce buffering/stalling over Bluetooth.
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
