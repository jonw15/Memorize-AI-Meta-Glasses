/*
 * YouTube Stream Extractor
 * Thin wrapper around YouTubeKit for extracting direct video stream URLs
 */

import Foundation
import YouTubeKit

struct YouTubeStreamExtractor {
    /// Extracts a direct streaming URL for the given YouTube video ID.
    /// Returns nil on failure (caller should fall back to WKWebView).
    static func extractStreamURL(videoId: String) async -> URL? {
        do {
            let video = YouTube(videoID: videoId)
            let allStreams = try await video.streams
            let candidates = allStreams
                .filterVideoAndAudio()
                .filter { $0.isNativelyPlayable }

            print("🎬 [YouTubeStreamExtractor] \(videoId): \(allStreams.count) total streams, \(candidates.count) natively playable with audio+video")

            guard let best = candidates.highestResolutionStream() else {
                print("⚠️ [YouTubeStreamExtractor] No natively playable combined stream found for \(videoId)")
                return nil
            }

            print("🎬 [YouTubeStreamExtractor] Selected stream: \(best.url) (ext: \(best.fileExtension))")
            return best.url
        } catch {
            print("⚠️ [YouTubeStreamExtractor] Failed to extract stream for \(videoId): \(error)")
            return nil
        }
    }
}
