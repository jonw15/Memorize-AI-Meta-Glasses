/*
 * Memorize Service
 * AI-powered OCR and book info extraction using Gemini Vision API
 */

import Foundation
import UIKit
import Vision

enum MemorizeExplainPersona: String, CaseIterable, Codable, Identifiable {
    case likeIAm5 = "like_i_am_5"
    case highSchoolStudent = "high_school_student"
    case collegeStudent = "college_student"
    case artist = "artist"
    case researcher = "researcher"

    var id: String { rawValue }

    var displayKey: String {
        "memorize.explain.persona.\(rawValue)"
    }

    var iconSystemImage: String {
        switch self {
        case .likeIAm5:
            return "🧒"
        case .highSchoolStudent:
            return "📘"
        case .collegeStudent:
            return "🎓"
        case .artist:
            return "🎨"
        case .researcher:
            return "🔬"
        }
    }

    var promptInstruction: String {
        switch self {
        case .highSchoolStudent:
            return "a high school student. Use simple language, short sentences, plain words, and clear examples."
        case .collegeStudent:
            return "a college student. Use structured logic, practical synthesis, and clear connections between ideas."
        case .researcher:
            return "a researcher. Use precise terminology, causal reasoning, and nuanced interpretation of claims."
        case .artist:
            return "a visual artist. Use vivid analogies, sensory language, and a creative, story-like tone while staying accurate."
        case .likeIAm5:
            return "a 5-year-old child. Use very simple words, one idea at a time, concrete examples, and a calm encouraging tone."
        }
    }
}

struct MemorizeService {
    struct VoiceSummaryEvaluation: Codable {
        let score: Int
        let strengths: [String]
        let improvements: [String]
        let feedback: String
    }

    private let visionService: VisionAPIService

    init() {
        self.visionService = VisionAPIService()
    }

    // MARK: - Extract Text (OCR)

    func extractText(from image: UIImage) async throws -> String {
        let prompt = """
        You are an OCR assistant. Extract ALL text from this book page image accurately.

        Requirements:
        1. Preserve the original text layout and paragraph structure
        2. Include headings, body text, and any captions
        3. Do NOT add any commentary or description - only output the extracted text
        4. If text is unclear, make your best attempt and mark unclear parts with [unclear]
        5. Preserve the original language of the text
        """

        do {
            let remoteText = try await visionService.analyzeImage(image, prompt: prompt)
            let trimmedRemote = remoteText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedRemote.isEmpty {
                return trimmedRemote
            }
            print("⚠️ [Memorize] Remote OCR returned empty text, falling back to local OCR")
        } catch {
            print("⚠️ [Memorize] Remote OCR failed (\(error.localizedDescription)), falling back to local OCR")
        }

        let localText = try await extractTextLocally(from: image)
        let trimmedLocal = localText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLocal.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Both remote and local OCR returned empty text"]
            )
        }
        return trimmedLocal
    }

    // MARK: - Detect Book Info

    func detectBookInfo(from image: UIImage) async throws -> (title: String, author: String) {
        let prompt = """
        You are identifying a physical book cover photo.
        Detect the most likely book title and author from the image.

        Respond in EXACTLY this format (nothing else):
        TITLE: <book title>
        AUTHOR: <author name>

        Rules:
        - Use the main title text on the cover.
        - Use the primary author name shown on the cover.
        - If the title is not readable, use "Unknown Book".
        - If the author is not readable, use "Unknown Author".
        """

        let result = try await visionService.analyzeImage(image, prompt: prompt)
        return parseBookInfo(from: result)
    }

    func detectBookInfo(from text: String) async throws -> (title: String, author: String) {
        let prompt = """
        Based on this text extracted from a book page, detect the book title and author.

        Text:
        \(text)

        Respond in EXACTLY this format (nothing else):
        TITLE: <book title>
        AUTHOR: <author name>

        If you cannot detect the title, use "Unknown Book".
        If you cannot detect the author, use "Unknown Author".
        """

        // Use a text-only request by creating a small placeholder
        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)

        return parseBookInfo(from: result)
    }

    // MARK: - Generate Icon Emoji

    func generateIconEmoji(for title: String) async throws -> String {
        let prompt = """
        Pick exactly ONE emoji that best represents this book or document title.

        Title: \(title)

        Respond with ONLY the single emoji character, nothing else. No text, no spaces, no quotes.
        Choose something creative and specific to the subject matter, not generic book emojis.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        let emoji = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // Take only the first character cluster (emoji) in case the model returns more
        if let first = emoji.first {
            return String(first)
        }
        return "\u{1F4D6}" // fallback: open book
    }

    // MARK: - Generate Quiz

    func generateQuiz(from pages: [PageCapture]) async throws -> [QuizQuestion] {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else { return [] }

        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let questionsPerPage = 2
        let totalQuestions = completedPages.count * questionsPerPage

        let prompt = """
        Based on the following text extracted from book pages, generate exactly \(totalQuestions) multiple-choice quiz questions to test reading comprehension.

        Text:
        \(combinedText)

        Requirements:
        1. Generate exactly \(totalQuestions) questions
        2. Each question must have exactly 4 answer options
        3. Questions should test understanding of key concepts, facts, and details
        4. Make wrong answers plausible but clearly incorrect
        5. Vary question difficulty

        Respond with ONLY a JSON array in this exact format, no other text:
        [
          {
            "question": "What is...?",
            "options": ["Option A", "Option B", "Option C", "Option D"],
            "correctIndex": 0
          }
        ]
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseQuizQuestions(from: result)
    }

    // MARK: - Voice Summary Grading

    func gradeVoiceSummary(summary: String, from pages: [PageCapture]) async throws -> VoiceSummaryEvaluation {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Voice summary is empty"]
            )
        }

        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "No completed pages to compare against"]
            )
        }

        let sourceText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let prompt = """
        Compare the student's spoken summary against the source reading material and grade comprehension quality.

        Source material:
        \(sourceText)

        Student summary:
        \(trimmedSummary)

        Return ONLY valid JSON in this exact shape:
        {
          "score": 0,
          "strengths": ["..."],
          "improvements": ["..."],
          "feedback": "..."
        }

        Rules:
        - score must be an integer from 0 to 100
        - strengths: 2-4 concise bullet strings
        - improvements: 2-4 concise bullet strings
        - feedback: a short paragraph (2-4 sentences)
        - no markdown, no extra keys, no extra text
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseVoiceSummaryEvaluation(from: result)
    }

    // MARK: - Explain Section

    func explainSection(from pages: [PageCapture], as persona: MemorizeExplainPersona) async throws -> String {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "No completed pages available to explain"]
            )
        }

        let sourceText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let prompt = """
        You are a reading coach. Explain the section from the source material for \(persona.promptInstruction)

        Source material:
        \(sourceText)

        Provide a concise but useful explanation that helps the learner understand the key ideas.
        Format:
        1. A short 1-2 sentence overview.
        2. 3-5 clear bullet points (each no longer than 24 words) describing important ideas.
        3. End with 1 sentence that connects the ideas to learning outcomes.

        Use plain text only. Do not include markdown code fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseQuizQuestions(from response: String) -> [QuizQuestion] {
        // Extract JSON array from response (handle markdown code blocks)
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONArray(from: cleaned) ?? cleaned

        guard let data = jsonString.data(using: .utf8) else { return [] }

        struct RawQuestion: Decodable {
            let question: String
            let options: [String]
            let correctIndex: Int
        }

        do {
            let raw = try JSONDecoder().decode([RawQuestion].self, from: data)
            return raw.compactMap { q in
                guard q.options.count == 4, q.correctIndex >= 0, q.correctIndex < 4 else { return nil }
                return QuizQuestion(question: q.question, options: q.options, correctIndex: q.correctIndex)
            }
        } catch {
            print("❌ [Memorize] Quiz JSON parse error: \(error)")
            return []
        }
    }

    private func parseVoiceSummaryEvaluation(from response: String) -> VoiceSummaryEvaluation {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        struct RawEvaluation: Decodable {
            let score: Int?
            let strengths: [String]?
            let improvements: [String]?
            let feedback: String?
        }

        if let data = jsonString.data(using: .utf8),
           let raw = try? JSONDecoder().decode(RawEvaluation.self, from: data) {
            let clampedScore = min(max(raw.score ?? 0, 0), 100)
            let strengths = (raw.strengths ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let improvements = (raw.improvements ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let feedback = raw.feedback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? response.trimmingCharacters(in: .whitespacesAndNewlines)

            return VoiceSummaryEvaluation(
                score: clampedScore,
                strengths: strengths.isEmpty ? ["Good attempt at summarizing key ideas."] : strengths,
                improvements: improvements.isEmpty ? ["Include more concrete details from the text."] : improvements,
                feedback: feedback.isEmpty ? "Your summary was reviewed. Try to include more of the chapter's core points." : feedback
            )
        }

        let fallbackFeedback = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return VoiceSummaryEvaluation(
            score: 0,
            strengths: ["You completed a spoken summary."],
            improvements: ["Try to mention more specific points from the reading."],
            feedback: fallbackFeedback.isEmpty ? "Unable to parse grading response. Please try again." : fallbackFeedback
        )
    }

    private func extractJSONArray(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\[[\\s\\S]*\\]", options: []) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\{[\\s\\S]*\\}", options: []) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    // MARK: - Private Helpers

    private func parseBookInfo(from response: String) -> (title: String, author: String) {
        var title = "memorize.unknown_book".localized
        var author = "memorize.unknown_author".localized

        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("TITLE:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("AUTHOR:") {
                author = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
        }

        return (title, author)
    }

    private func createPlaceholderImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func extractTextLocally(from image: UIImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else {
                throw NSError(
                    domain: "MemorizeService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid image for local OCR"]
                )
            }

            var recognizedLines: [String] = []
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    print("❌ [Memorize] Local OCR error: \(error.localizedDescription)")
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        let line = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !line.isEmpty {
                            recognizedLines.append(line)
                        }
                    }
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            return recognizedLines.joined(separator: "\n")
        }.value
    }
}

struct YouTubeTranscriptImportService {
    struct ImportedTranscript {
        let videoTitle: String
        let transcript: String
        let videoID: String
    }

    private let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private let userAgent = "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
    private let fallbackUserAgent = "Mozilla/5.0"
    private let clientName = "IOS"
    private let clientVersion = "20.10.4"
    private let deviceModel = "iPhone16,2"

    func importTranscript(from rawInput: String) async throws -> ImportedTranscript {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw YouTubeImportError.invalidURL
        }

        guard let videoID = extractVideoID(from: trimmed) else {
            throw YouTubeImportError.invalidURL
        }

        async let transcript = fetchTranscript(videoID: videoID)
        async let title = fetchTitle(videoID: videoID)

        let finalTranscript = try await transcript
        let resolvedTitle = (try? await title)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (resolvedTitle?.isEmpty == false ? resolvedTitle! : "YouTube · \(videoID)")

        return ImportedTranscript(videoTitle: finalTitle, transcript: finalTranscript, videoID: videoID)
    }

    private func fetchTitle(videoID: String) async throws -> String {
        if let title = try await fetchTitleFromOEmbed(videoID: videoID) {
            return title
        }
        return "YouTube · \(videoID)"
    }

    private func fetchTitleFromOEmbed(videoID: String) async throws -> String? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(videoID)"),
            URLQueryItem(name: "format", value: "json")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(fallbackUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            return nil
        }

        let payload = try JSONDecoder().decode(OEmbedResponse.self, from: data)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func fetchTranscript(videoID: String) async throws -> String {
        let playerResponse = try await fetchPlayerResponse(videoID: videoID)

        if let transcript = try await fetchTranscriptFromCaptionTracks(playerResponse) {
            return transcript
        }

        let visitorData = try? await fetchVisitorData(videoID: videoID)
        let data = try await requestTranscript(videoID: videoID, visitorData: visitorData ?? "")
        let transcript = try parseTranscript(from: data)
        guard !transcript.isEmpty else {
            throw YouTubeImportError.transcriptUnavailable
        }
        return transcript
    }

    private func fetchPlayerResponse(videoID: String) async throws -> YouTubePlayerResponse {
        var components = URLComponents(string: "https://www.youtube.com/youtubei/v1/player")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "prettyPrint", value: "false")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "context": [
                    "client": [
                        "clientName": clientName,
                        "clientVersion": clientVersion,
                        "deviceModel": deviceModel
                    ]
                ],
                "videoId": videoID,
                "contentCheckOk": true,
                "racyCheckOk": true
            ]
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw YouTubeImportError.transcriptUnavailable
        }

        return try JSONDecoder().decode(YouTubePlayerResponse.self, from: data)
    }

    private func fetchTranscriptFromCaptionTracks(_ playerResponse: YouTubePlayerResponse) async throws -> String? {
        guard let tracks = playerResponse.captions?.playerCaptionsTracklistRenderer.captionTracks,
              !tracks.isEmpty else {
            return nil
        }

        guard let track = selectCaptionTrack(from: tracks) else {
            return nil
        }

        guard var components = URLComponents(string: track.baseURL) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "fmt" }
        queryItems.append(URLQueryItem(name: "fmt", value: "json3"))
        components.queryItems = queryItems

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(fallbackUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            return nil
        }

        let transcript = try parseCaptionJSON3Transcript(from: data)
        return transcript.isEmpty ? nil : transcript
    }

    private func selectCaptionTrack(from tracks: [YouTubePlayerResponse.Captions.TracklistRenderer.CaptionTrack]) -> YouTubePlayerResponse.Captions.TracklistRenderer.CaptionTrack? {
        if let preferred = tracks.first(where: { ($0.vssID ?? "").contains(".en") && $0.kind != "asr" }) {
            return preferred
        }
        if let preferred = tracks.first(where: { $0.languageCode.lowercased().hasPrefix("en") && $0.kind != "asr" }) {
            return preferred
        }
        if let preferred = tracks.first(where: { ($0.vssID ?? "").contains(".en") }) {
            return preferred
        }
        if let preferred = tracks.first(where: { $0.languageCode.lowercased().hasPrefix("en") }) {
            return preferred
        }
        if let preferred = tracks.first(where: { $0.kind != "asr" }) {
            return preferred
        }
        return tracks.first
    }

    private func requestTranscript(videoID: String, visitorData: String) async throws -> Data {
        var components = URLComponents(string: "https://www.youtube.com/youtubei/v1/get_transcript")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "contentCheckOk", value: "true"),
            URLQueryItem(name: "racyCheckOk", value: "true"),
            URLQueryItem(name: "videoID", value: videoID)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "context": [
                    "client": [
                        "clientName": clientName,
                        "clientVersion": clientVersion,
                        "deviceModel": deviceModel
                    ]
                ]
            ]
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        if !visitorData.isEmpty {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw YouTubeImportError.transcriptUnavailable
        }
        return data
    }

    private func fetchVisitorData(videoID: String) async throws -> String? {
        var request = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!)
        request.setValue(fallbackUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")
        request.httpShouldHandleCookies = false

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        let pattern = #""visitorData":"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return String(html[range])
    }

    private func parseTranscript(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        let rawSegments = collectTranscriptSegments(from: json)
        let transcript = readableTranscript(from: rawSegments)
        if transcript.isEmpty {
            throw YouTubeImportError.transcriptUnavailable
        }
        return transcript
    }

    private func parseCaptionJSON3Transcript(from data: Data) throws -> String {
        let payload = try JSONDecoder().decode(YouTubeCaptionResponse.self, from: data)
        let segments = payload.events
            .flatMap { $0.segs ?? [] }
            .compactMap { segment in
                segment.utf8?
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        return readableTranscript(from: segments)
    }

    private func readableTranscript(from rawSegments: [String]) -> String {
        let cleanedSegments = rawSegments
            .map {
                $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let dedupedSegments = cleanedSegments.reduce(into: [String]()) { partialResult, segment in
            if partialResult.last != segment {
                partialResult.append(segment)
            }
        }

        var paragraphs: [String] = []
        var currentParagraph = ""

        for segment in dedupedSegments {
            if currentParagraph.isEmpty {
                currentParagraph = segment
            } else if currentParagraph.hasSuffix("-") {
                currentParagraph += segment
            } else {
                currentParagraph += " " + segment
            }

            let endsSentence = segment.last.map { ".!?".contains($0) } ?? false
            if endsSentence && currentParagraph.count >= 260 {
                paragraphs.append(currentParagraph)
                currentParagraph = ""
            }
        }

        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private func collectTranscriptSegments(from node: Any) -> [String] {
        if let dict = node as? [String: Any] {
            var segments: [String] = []

            if let renderer = dict["transcriptSegmentRenderer"] as? [String: Any],
               let text = extractSegmentText(from: renderer) {
                segments.append(text)
            }

            for value in dict.values {
                segments.append(contentsOf: collectTranscriptSegments(from: value))
            }

            return segments
        }

        if let array = node as? [Any] {
            return array.flatMap { collectTranscriptSegments(from: $0) }
        }

        return []
    }

    private func extractSegmentText(from renderer: [String: Any]) -> String? {
        if let snippet = renderer["snippet"] {
            return extractText(from: snippet)
        }
        if let content = renderer["content"] {
            return extractText(from: content)
        }
        return nil
    }

    private func extractText(from node: Any) -> String? {
        if let string = node as? String {
            return string
        }

        if let dict = node as? [String: Any] {
            if let simpleText = dict["simpleText"] as? String {
                return simpleText
            }
            if let text = dict["text"] as? String {
                return text
            }
            if let runs = dict["runs"] as? [[String: Any]] {
                let joined = runs.compactMap { $0["text"] as? String }.joined()
                return joined.isEmpty ? nil : joined
            }
        }

        if let array = node as? [Any] {
            let joined = array.compactMap { extractText(from: $0) }.joined()
            return joined.isEmpty ? nil : joined
        }

        return nil
    }

    private func extractVideoID(from rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawIDPattern = #"^[A-Za-z0-9_-]{11}$"#
        if trimmed.range(of: rawIDPattern, options: .regularExpression) != nil {
            return trimmed
        }

        guard let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if let host = components.host?.lowercased() {
            if host.contains("youtu.be") {
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return path.isEmpty ? nil : String(path.prefix(11))
            }

            if host.contains("youtube.com") {
                if let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value,
                   !queryID.isEmpty {
                    return String(queryID.prefix(11))
                }

                let parts = components.path.split(separator: "/")
                if let markerIndex = parts.firstIndex(where: { $0 == "embed" || $0 == "shorts" || $0 == "live" }),
                   parts.indices.contains(parts.index(after: markerIndex)) {
                    return String(parts[parts.index(after: markerIndex)].prefix(11))
                }
            }
        }

        return nil
    }

    private enum YouTubeImportError: LocalizedError {
        case invalidURL
        case transcriptUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "That doesn’t look like a valid YouTube link."
            case .transcriptUnavailable:
                return "Couldn’t retrieve a transcript for this video."
            }
        }
    }

    private struct OEmbedResponse: Decodable {
        let title: String
    }

    private struct YouTubePlayerResponse: Decodable {
        let captions: Captions?

        struct Captions: Decodable {
            let playerCaptionsTracklistRenderer: TracklistRenderer

            struct TracklistRenderer: Decodable {
                let captionTracks: [CaptionTrack]?

                struct CaptionTrack: Decodable {
                    let baseURL: String
                    let languageCode: String
                    let kind: String?
                    let vssID: String?

                    enum CodingKeys: String, CodingKey {
                        case baseURL = "baseUrl"
                        case languageCode
                        case kind
                        case vssID = "vssId"
                    }
                }
            }
        }
    }

    private struct YouTubeCaptionResponse: Decodable {
        let events: [CaptionEvent]

        struct CaptionEvent: Decodable {
            let segs: [CaptionSegment]?
        }

        struct CaptionSegment: Decodable {
            let utf8: String?
        }
    }
}
