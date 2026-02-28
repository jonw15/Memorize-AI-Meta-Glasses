/*
 * Memorize Service
 * AI-powered OCR and book info extraction using Gemini Vision API
 */

import Foundation
import UIKit
import Vision

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
