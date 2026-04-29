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

    struct FeynmanFeedback: Codable {
        struct LandingItem: Codable {
            let title: String
            let detail: String
        }
        let landingItems: [LandingItem]
        let focusChips: [String]
        let refinedSummary: String
    }

    private let visionService: VisionAPIService
    private let fastVisionService: VisionAPIService

    init() {
        self.visionService = VisionAPIService()
        let fastModel: String = {
            switch VisionAPIConfig.provider {
            case .google: return "gemini-2.5-flash-lite"
            case .openrouter: return "google/gemini-2.5-flash-lite"
            }
        }()
        self.fastVisionService = VisionAPIService(
            apiKey: VisionAPIConfig.apiKey,
            baseURL: VisionAPIConfig.baseURL,
            model: fastModel
        )
    }

    // MARK: - Feynman Feedback

    func generateFeynmanFeedback(
        topic: String,
        sourceContext: String,
        userExplanation: String
    ) async throws -> FeynmanFeedback {
        let trimmedExplanation = userExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExplanation.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Empty explanation"]
            )
        }

        let prompt = """
        You are a learning coach using the Feynman Technique. The student tried to teach a concept in their own words. Compare their explanation against the source material and give honest, specific feedback.

        Topic: \(topic)

        Source material:
        \(sourceContext)

        Student's explanation:
        \(trimmedExplanation)

        Return ONLY valid JSON in this exact shape:
        {
          "landingItems": [
            { "title": "short label", "detail": "one or two sentences quoting or referencing the student's actual wording" }
          ],
          "focusChips": ["short focus question", "short focus question", "short focus question"],
          "refinedSummary": "one or two sentences summarizing what improved if the student takes the focus questions seriously"
        }

        Requirements:
        - Provide exactly 4 landingItems. Mix what the student got right with what's missing or fuzzy. Quote or paraphrase the student's actual phrasing where useful.
        - Each "title" must be 4-7 words. Each "detail" 1-2 short sentences.
        - Provide exactly 3 focusChips. Each chip is a short question (under 8 words) targeting a gap or weak spot.
        - "refinedSummary" describes what a tightened second-pass explanation would sound like — 1 short sentence.
        - Stay grounded in the source. Do not invent facts not present.
        - No markdown fences and no extra JSON keys.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseFeynmanFeedback(from: result)
    }

    struct FeynmanRefinementVerdict: Codable {
        struct Improvement: Codable {
            let title: String
            let detail: String
        }
        let headline: String
        let improvements: [Improvement]
        let remainingGaps: [String]
        let clarityScore: Int
    }

    func evaluateFeynmanRefinement(
        topic: String,
        sourceContext: String,
        initialExplanation: String,
        refinedExplanation: String
    ) async throws -> FeynmanRefinementVerdict {
        let trimmedRefined = refinedExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRefined.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Empty refined explanation"]
            )
        }

        let prompt = """
        You are a learning coach using the Feynman Technique. The student already received feedback on a first explanation, then rewrote it. Compare the two attempts against the source material and judge how much sharper the refinement is.

        Topic: \(topic)

        Source material:
        \(sourceContext)

        First attempt:
        \(initialExplanation.trimmingCharacters(in: .whitespacesAndNewlines))

        Refined attempt:
        \(trimmedRefined)

        Return ONLY valid JSON in this exact shape:
        {
          "headline": "short verdict — 4-6 words",
          "clarityScore": 7,
          "improvements": [
            { "title": "short label", "detail": "one short sentence quoting or referencing what the student added or fixed" }
          ],
          "remainingGaps": ["short phrase", "short phrase"]
        }

        Requirements:
        - "headline" is 4-6 words, encouraging if the refinement landed (e.g. "Much sharper now", "Mechanism reads cleanly"), or honest if it didn't (e.g. "Still fuzzy in places").
        - "clarityScore" is an integer 1-10 reflecting overall clarity of the refined attempt against the source.
        - Provide 2-4 improvements. Each should reference something the student actually changed or added between attempts.
        - Provide 0-3 remainingGaps — short phrases naming gaps that are still present in the refined attempt.
        - Stay grounded in what the student wrote and what the source says. Do not invent details.
        - No markdown fences and no extra JSON keys.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseFeynmanRefinementVerdict(from: result)
    }

    private func parseFeynmanRefinementVerdict(from response: String) -> FeynmanRefinementVerdict {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        if let data = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(FeynmanRefinementVerdict.self, from: data) {
            return parsed
        }

        return FeynmanRefinementVerdict(
            headline: "Couldn't read the refinement",
            improvements: [],
            remainingGaps: [],
            clarityScore: 0
        )
    }

    // MARK: - Feynman Concept Intro

    func generateFeynmanConcept(topic: String, sourceContext: String) async throws -> String {
        let prompt = """
        You are a tutor introducing the topic "\(topic)" using ONLY the source material below. Write a short, plain-language explanation a curious 12-year-old could grasp before they try to teach it back.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        { "concept": "3-5 sentences in plain English. Define the term, name the key parts, and end with a single sentence about why it matters." }

        Requirements:
        - Strictly grounded in the source. No invented facts.
        - 3-5 sentences total. Plain words. No markdown.
        - No fences, no extra keys.
        """
        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        struct Wrap: Decodable { let concept: String }
        return parseJSON(result, fallback: Wrap(concept: "")).concept
    }

    // MARK: - Mnemonics

    enum MnemonicType: String, Codable {
        case acronym, sentence, visualImagery = "visual_imagery", storyChain = "story_chain"
    }

    struct MnemonicTrigger: Codable {
        let item: String
        let trigger: String
        let triggerType: String   // first_letter | keyword | visual_image
    }

    struct MnemonicResult: Codable {
        let items: [String]
        let triggers: [MnemonicTrigger]
        let mnemonicType: String
        let mnemonic: String
        let orderMatters: Bool
    }

    struct MnemonicRecallEvaluation: Codable {
        let correctItems: [String]
        let missedItems: [String]
        let outOfOrderItems: [String]
        let score: Int          // 0–100
        let weakItems: [String]
        let comment: String
    }

    func extractMnemonicItems(topic: String, sourceContext: String) async throws -> (items: [String], orderMatters: Bool) {
        let prompt = """
        You are a memory coach. Pull a SHORT list of the most important items to memorize about "\(topic)" from the source below.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        { "items": ["item1", "item2"], "orderMatters": true }

        Requirements:
        - Return 5–7 items. Each is 1–4 words.
        - Set orderMatters = true if the items have a natural sequence (steps, planets, layers); false if order is incidental.
        - Stay grounded in the source. No invented items.
        - No markdown fences and no extra keys.
        """
        let result = try await fastVisionService.generateText(prompt: prompt)
        struct Wrap: Decodable { let items: [String]; let orderMatters: Bool }
        let wrapped = parseJSON(result, fallback: Wrap(items: [], orderMatters: false))
        return (wrapped.items, wrapped.orderMatters)
    }

    func generateMnemonic(
        topic: String,
        items: [String],
        mnemonicType: MnemonicType
    ) async throws -> MnemonicResult {
        let typeStr = mnemonicType.rawValue
        let prompt = """
        You are a memory coach. Build a vivid, easy-to-recall \(typeStr) mnemonic for these items about "\(topic)":
        \(items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Return ONLY valid JSON in this exact shape:
        {
          "mnemonic": "the mnemonic text — short, vivid, unusual, easy to recall",
          "triggers": [
            { "item": "item1", "trigger": "M (or keyword/image)", "triggerType": "first_letter" }
          ]
        }

        Mnemonic-type rules:
        - acronym: build a pronounceable acronym from first letters; mnemonic = "ACRONYM — expanded gloss".
        - sentence: a short sentence whose word initials match the item initials in order.
        - visual_imagery: one or two sentences painting a single concrete scene that links the items.
        - story_chain: a 2–3 sentence mini-story linking each item to the next in order.

        Trigger rules:
        - For acronym/sentence → triggerType = "first_letter".
        - For visual_imagery/story_chain → triggerType = "visual_image" or "keyword".
        - One trigger per item.

        Quality rules:
        - Keep it short and vivid. Avoid generic phrasing.
        - Triggers must map back to the original items.
        - No markdown fences and no extra keys.
        """
        let result = try await fastVisionService.generateText(prompt: prompt)
        struct Wrap: Decodable { let mnemonic: String; let triggers: [MnemonicTrigger] }
        let wrapped = parseJSON(result, fallback: Wrap(mnemonic: "", triggers: []))
        return MnemonicResult(
            items: items,
            triggers: wrapped.triggers,
            mnemonicType: typeStr,
            mnemonic: wrapped.mnemonic,
            orderMatters: false
        )
    }

    func evaluateMnemonicRecall(
        originalItems: [String],
        userRecall: [String],
        orderMatters: Bool
    ) async throws -> MnemonicRecallEvaluation {
        let originalList = originalItems.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let userList = userRecall.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        Compare a student's recall against the original list.

        Original items (orderMatters=\(orderMatters ? "true" : "false")):
        \(originalList)

        Student's recall:
        \(userList)

        Return ONLY valid JSON in this exact shape:
        {
          "correctItems": ["..."],
          "missedItems": ["..."],
          "outOfOrderItems": ["..."],
          "score": 80,
          "weakItems": ["..."],
          "comment": "one short encouraging line"
        }

        Rules:
        - "correctItems" — items present in the student's recall (case/spelling-tolerant).
        - "missedItems" — items in original list but not in student's recall.
        - "outOfOrderItems" — only populated if orderMatters=true; items the student listed but in the wrong position.
        - "score" 0–100. Penalize missed items and (if orderMatters) order errors.
        - "weakItems" — union of missedItems and outOfOrderItems, deduped.
        - "comment" — 1 short sentence, encouraging, specific.
        - No markdown fences and no extra keys.
        """
        let result = try await fastVisionService.generateText(prompt: prompt)
        return parseJSON(result, fallback: MnemonicRecallEvaluation(
            correctItems: [],
            missedItems: originalItems,
            outOfOrderItems: [],
            score: 0,
            weakItems: originalItems,
            comment: "We couldn't read your recall — try again."
        ))
    }

    func refineMnemonic(
        topic: String,
        items: [String],
        mnemonicType: MnemonicType,
        previousMnemonic: String,
        weakItems: [String]
    ) async throws -> String {
        let prompt = """
        Improve a \(mnemonicType.rawValue) mnemonic for "\(topic)" so the student stops missing the weak items.

        Items:
        \(items.joined(separator: ", "))

        Previous mnemonic:
        \(previousMnemonic)

        Weak items the student missed or scrambled:
        \(weakItems.joined(separator: ", "))

        Return ONLY valid JSON in this exact shape:
        { "mnemonic": "the improved mnemonic, short and vivid" }

        Rules:
        - Make weak items MORE vivid or concrete in the new mnemonic.
        - Simplify confusing parts.
        - Keep the same mnemonic type structure.
        - No markdown fences and no extra keys.
        """
        let result = try await fastVisionService.generateText(prompt: prompt)
        struct Wrap: Decodable { let mnemonic: String }
        return parseJSON(result, fallback: Wrap(mnemonic: previousMnemonic)).mnemonic
    }

    // MARK: - Mnemonics (legacy 3-angle generator, kept for reference)

    struct MnemonicAngles: Codable {
        let acronymTitle: String
        let acronymBody: String
        let storyTitle: String
        let storyBody: String
        let palaceTitle: String
        let palaceBody: String
    }

    func generateMnemonics(topic: String, sourceContext: String) async throws -> MnemonicAngles {
        let prompt = """
        You are a memory coach. Build three concrete mnemonic angles for the topic "\(topic)" using ONLY the source material below. Each angle must be specific to this source.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        {
          "acronymTitle": "the acronym in quotes, e.g. \\\"PQCPN\\\"",
          "acronymBody": "what each letter stands for + a short pronounceable mnemonic phrase, all in 1-2 sentences",
          "storyTitle": "a short story hook, 4-7 words",
          "storyBody": "a 2-3 sentence vivid mini-story that walks through the concept end-to-end with concrete imagery",
          "palaceTitle": "memory-palace location prompt, 3-6 words (e.g. \\\"Walk through your kitchen\\\")",
          "palaceBody": "map 4-6 key terms from \(topic) onto landmarks in that location, format as 'Landmark = Term' pairs separated by '. '"
        }

        Requirements:
        - All content must be grounded in the source material above. Do not invent terms.
        - Keep each body 1-3 sentences max.
        - No markdown, no extra keys, no fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseJSON(result, fallback: MnemonicAngles(
            acronymTitle: "—",
            acronymBody: "Couldn't generate this angle.",
            storyTitle: "—",
            storyBody: "Couldn't generate this angle.",
            palaceTitle: "—",
            palaceBody: "Couldn't generate this angle."
        ))
    }

    // MARK: - Active Recall

    struct ActiveRecallQuestion: Codable {
        let prompt: String
        let answer: String
    }

    struct ActiveRecallSet: Codable {
        let questions: [ActiveRecallQuestion]
        let pep: String
    }

    func generateActiveRecallSet(topic: String, sourceContext: String) async throws -> ActiveRecallSet {
        let prompt = """
        You are a retrieval-practice coach. Build a 5-question active recall round for the topic "\(topic)" using ONLY the source material below.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        {
          "questions": [
            { "prompt": "short question grounded in the source", "answer": "1-2 sentence ideal answer pulled from the source" }
          ],
          "pep": "one short encouraging sentence about why retrieval beats re-reading"
        }

        Requirements:
        - Exactly 5 questions. Mix recall, application, and tricky-but-fair.
        - Each prompt under 12 words. Each answer under 30 words.
        - Stay grounded in the source. No invented facts.
        - No markdown, no extra keys, no fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseJSON(result, fallback: ActiveRecallSet(questions: [], pep: "Try again — pulling from memory is what makes it stick."))
    }

    // MARK: - Cornell

    struct CornellRow: Codable {
        let cue: String
        let body: String
    }

    struct CornellSet: Codable {
        let rows: [CornellRow]
        let summaryStarter: String
    }

    func generateCornellSet(topic: String, sourceContext: String) async throws -> CornellSet {
        let prompt = """
        You are a Cornell-method note coach. Split the source material on "\(topic)" into Cornell-style cue / body rows.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        {
          "rows": [
            { "cue": "short cue question or phrase", "body": "1-3 sentence answer pulled from the source" }
          ],
          "summaryStarter": "one-sentence opener the student can use to begin their own summary"
        }

        Requirements:
        - 4-6 rows. Each cue under 8 words. Each body under 40 words.
        - Cues should be questions or sharp phrases that probe the body.
        - Stay grounded. No invented terms.
        - No markdown, no extra keys, no fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseJSON(result, fallback: CornellSet(rows: [], summaryStarter: "In short, this material covers…"))
    }

    // MARK: - Leitner

    struct LeitnerCard: Codable, Identifiable {
        let id: String
        let front: String
        let back: String
        let cardType: String       // definition | explanation | fill_blank | why | process
        let difficulty: String     // easy | medium | hard
        let box: Int               // default = 1
        let sourceId: String
    }

    struct LeitnerDeck: Codable {
        let cards: [LeitnerCard]
        let intro: String
    }

    func generateLeitnerDeck(topic: String, sourceContext: String, sourceId: String) async throws -> LeitnerDeck {
        let wordCount = sourceContext
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
        let targetCount = max(6, min(20, wordCount / 100))

        let prompt = """
        You are an expert flashcard author. Build Leitner-style flashcards for "\(topic)" using ONLY the source material below.

        Source material:
        \(sourceContext)

        Generate a MIX of card types — every deck should include several of each:
        - "definition"   — define a key term in your own words
        - "explanation"  — explain what something does or means
        - "fill_blank"   — a sentence with one blank "____" the student must fill in
        - "why"          — ask why something happens or matters
        - "process"      — ask the steps or sequence of a process

        Difficulty rules:
        - "easy"   → direct recall, basic definitions
        - "medium" → applied understanding or explanation
        - "hard"   → multi-step reasoning, "why", synthesis

        Quality rules:
        - Each card targets ONE meaningful concept. No vague "What is mentioned…" prompts.
        - Rephrase into simple, clear language. Do NOT copy long sentences from the source.
        - Front under 12 words. Back must be 1-2 short lines (under 30 words). Recall, not recognition.
        - Generate roughly \(targetCount) cards (~1 per 80-120 words). Prioritize the most important concepts.
        - Deduplicate near-identical cards; keep variety across cardType and difficulty.

        All cards start in box = 1.

        Return ONLY valid JSON in this exact shape:
        {
          "intro": "one-sentence framing for this deck",
          "cards": [
            {
              "id": "stable short id, e.g. 'card-1'",
              "front": "short prompt",
              "back": "1-2 line answer in plain language",
              "cardType": "definition",
              "difficulty": "easy",
              "box": 1,
              "sourceId": "\(sourceId)"
            }
          ]
        }

        - cardType MUST be one of: definition, explanation, fill_blank, why, process
        - difficulty MUST be one of: easy, medium, hard
        - box must be the integer 1
        - sourceId must equal "\(sourceId)" exactly
        - No markdown fences and no extra keys.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        let deck = parseJSON(result, fallback: LeitnerDeck(cards: [], intro: "Boxed-cards review."))
        return LeitnerDeck(
            cards: filterFlashcards(deck.cards, sourceId: sourceId),
            intro: deck.intro
        )
    }

    private func filterFlashcards(_ cards: [LeitnerCard], sourceId: String) -> [LeitnerCard] {
        let validTypes: Set<String> = ["definition", "explanation", "fill_blank", "why", "process"]
        let validDifficulties: Set<String> = ["easy", "medium", "hard"]
        var seenFronts = Set<String>()
        var result: [LeitnerCard] = []
        var counter = 0
        for card in cards {
            let trimmedFront = card.front.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmedFront.isEmpty else { continue }
            guard !card.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard seenFronts.insert(trimmedFront).inserted else { continue }
            counter += 1
            let normalizedType = validTypes.contains(card.cardType) ? card.cardType : "explanation"
            let normalizedDifficulty = validDifficulties.contains(card.difficulty) ? card.difficulty : "medium"
            let normalizedId = card.id.isEmpty ? "card-\(counter)" : card.id
            result.append(LeitnerCard(
                id: normalizedId,
                front: card.front,
                back: card.back,
                cardType: normalizedType,
                difficulty: normalizedDifficulty,
                box: 1,
                sourceId: sourceId
            ))
        }
        return result
    }

    // MARK: - Spaced Repetition

    struct SpacedReview: Codable {
        let card: String
        let answer: String
        let intervalDays: Int
    }

    struct SpacedSchedule: Codable {
        let dueNow: [SpacedReview]
        let upcoming: [SpacedReview]
        let intro: String
    }

    func generateSpacedSchedule(topic: String, sourceContext: String) async throws -> SpacedSchedule {
        let prompt = """
        You are a spaced-repetition planner. Build today's review queue + an upcoming preview for "\(topic)" using the source material below.

        Source material:
        \(sourceContext)

        Return ONLY valid JSON in this exact shape:
        {
          "intro": "one short sentence about what's due today and why",
          "dueNow": [
            { "card": "short prompt", "answer": "1-2 sentence answer", "intervalDays": 1 }
          ],
          "upcoming": [
            { "card": "short prompt", "answer": "1-2 sentence answer", "intervalDays": 4 }
          ]
        }

        Requirements:
        - 5-8 cards in dueNow with intervalDays = 1.
        - 3-6 cards in upcoming with intervalDays in {2, 4, 7, 14}.
        - Each card prompt under 8 words. Each answer under 30 words.
        - Stay grounded. No invented facts.
        - No markdown, no extra keys, no fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseJSON(result, fallback: SpacedSchedule(dueNow: [], upcoming: [], intro: "Today's review."))
    }

    // MARK: - Generic JSON parser

    private func parseJSON<T: Decodable>(_ response: String, fallback: T) -> T {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned
        if let data = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(T.self, from: data) {
            return parsed
        }
        return fallback
    }

    private func parseFeynmanFeedback(from response: String) -> FeynmanFeedback {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        if let data = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(FeynmanFeedback.self, from: data) {
            return parsed
        }

        return FeynmanFeedback(
            landingItems: [
                FeynmanFeedback.LandingItem(
                    title: "Couldn't read your draft",
                    detail: "We couldn't analyze the explanation this time. Try sending it again."
                )
            ],
            focusChips: ["Try again"],
            refinedSummary: "Tap back to retry the feedback."
        )
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

    func generateQuiz(from pages: [PageCapture], questionCount: Int? = nil) async throws -> [QuizQuestion] {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else { return [] }

        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let recommendedQuestionCap = min(max(questionCount ?? 10, 5), 10)

        let prompt = """
        You are an expert learning designer focused on maximizing retention through active recall.

        Your task is to generate a concise, high-quality quiz from the source material below.

        GOALS:
        - Reinforce key concepts (not test everything)
        - Minimize cognitive overload
        - Prioritize clarity and usefulness over quantity

        SOURCE MATERIAL:
        \(combinedText)

        ---

        STEP 1: EXTRACT KEY CONCEPTS
        - Identify the most important concepts in the source material
        - A key concept is:
          - A main idea, framework, definition, or important example
          - Mentioned multiple times OR central to understanding the topic
        - Return a list of key concepts (max 12, min 5)

        ---

        STEP 2: DETERMINE QUESTION COUNT
        - Let N = number of key concepts
        - question_count = min(max(N, 5), 10)
        - Keep the final question count at or below \(recommendedQuestionCap) if the source is short

        ---

        STEP 3: SELECT CONCEPTS TO TEST
        - Prioritize:
          1. Concepts repeated multiple times
          2. Concepts with definitions or explanations
          3. Concepts critical to understanding the topic
        - Do NOT create multiple questions for the same concept unless absolutely necessary

        ---

        STEP 4: GENERATE QUESTIONS
        Structure:
        - 60% Core Understanding (main ideas)
        - 30% Key Details (important supporting info)
        - 10% Application (real-world or reasoning)

        Rules:
        - One question per concept (avoid redundancy)
        - Keep questions short and clear
        - Avoid trivial or overly specific details
        - Prefer conceptual understanding over memorization
        - Each question must have exactly 4 answer options
        - Ensure questions can be answered using only the source material

        ---

        STEP 5: FORMAT OUTPUT
        Return ONLY valid JSON in this exact structure:
        {
          "total_questions": number,
          "concepts": [
            "concept 1",
            "concept 2"
          ],
          "questions": [
            {
              "type": "core | detail | application",
              "concept": "the concept being tested",
              "question": "...",
              "options": ["A", "B", "C", "D"],
              "answer": "correct option",
              "explanation": "short explanation of why it's correct"
            }
          ]
        }

        CONSTRAINTS:
        - Total questions must NOT exceed 10
        - Avoid repeating the same idea in multiple questions
        - Keep explanations concise (1-2 sentences)
        - Use only plain JSON with no markdown fences or extra commentary
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

        Provide a concise but useful summary that helps the learner understand the key ideas.
        Write it in the requested persona's voice as natural spoken prose.
        Requirements:
        1. Start directly with the summary content, not a greeting or question.
        2. Use 2-4 short paragraphs.
        3. Focus on the most important ideas, connections, and takeaways from the source.
        4. Do not use bullet points or numbered lists.
        5. Do not end with a question or invitation to discuss more.

        Use plain text only. Do not include markdown code fences.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Generate Study Notes

    func generateStudyNote(
        from pages: [PageCapture],
        bookTitle: String,
        mode: GeneratedNoteKind,
        sessionTranscript: String? = nil,
        customInstructions: String? = nil
    ) async throws -> GeneratedNote {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "No completed pages available for notes"]
            )
        }

        let sourceText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let titleText = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let interactionText = sessionTranscript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let interactionSection = interactionText.isEmpty
            ? "No session transcript was captured. Focus only on source-grounded notes."
            : """
            Session transcript and learner performance:
            \(interactionText)
            """
        let customInstructionText = customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let customInstructionSection = customInstructionText.isEmpty
            ? "No extra creation preferences were provided."
            : """
            Creation preferences:
            \(customInstructionText)
            """

        let prompt: String
        if mode == .studyGuide {
            prompt = """
            You are an expert study guide writer. Create a thorough, well-structured study guide from the selected study material.

            Project title:
            \(titleText.isEmpty ? "Untitled project" : titleText)

            Source material:
            \(sourceText)

            \(interactionSection)

            \(customInstructionSection)

            Return ONLY valid JSON in this exact shape:
            {
              "title": "short study guide title",
              "body": "study guide text"
            }

            Requirements:
            - This must be a real study guide, not brief study notes.
            - The title should be specific to the source and under 8 words.
            - The body must follow this exact plain-text structure and order:

              Overview
              2-3 sentences framing the topic, scope, and why it matters.

              Learning objectives
              - 3-5 bulleted objectives written as "Understand/Explain/Apply ..." statements.

              Key terms
              - Term — short definition.
              (5-8 entries; only terms supported by the source.)

              Sections
              <Section heading>
              2-4 sentences explaining the section's main ideas.
              - Bulleted key points, formulas, or examples grounded in the source.
              (Repeat for 3-5 sections that cover the source.)

              Review questions
              1. Question text.
              2. Question text.
              (5-8 numbered questions ranging from recall to application.)

              Practice & next steps
              - 2-4 concrete actions the learner should do to master the material.

            - Section headings should be short, specific, and written as plain heading lines, not markdown.
            - Stay strictly grounded in the source material. Do not invent facts, citations, or examples not present in the source.
            - Prefer plain language; keep sentences tight.
            - No markdown fences and no extra JSON keys.
            """
        } else {
            prompt = """
            You are an expert study note writer. Create short, simple AI-generated notes after the learner finishes a \(mode.promptName).

            Project title:
            \(titleText.isEmpty ? "Untitled project" : titleText)

            Source material:
            \(sourceText)

            \(interactionSection)

            \(customInstructionSection)

            Return ONLY valid JSON in this exact shape:
            {
              "title": "short note title",
              "body": "study notes text"
            }

            Requirements:
            - The title should be specific to the source and under 8 words.
            - The body must follow this exact plain-text structure and order:

              Summary
              1-2 short sentences summarizing the source topic and main takeaway.

              <Specific Topic Heading>
              1-2 short sentences about the most important concept or discussion point.

              Next steps
              [User] Action title: One simple thing to review or practice next.
              [AI Tutor] Action title: One short correction, reminder, or follow-up if relevant.

              Details
              2-4 short bullets. Include what the user said/answered/asked and the AI feedback if a session transcript exists.

            - Include only 1-2 specific topic headings between Summary and Next steps.
            - Topic headings should be short, specific, and written as plain heading lines, not markdown.
            - The Next steps section must use bracketed owners like [User] or [AI Tutor].
            - If a session transcript was provided, Details should briefly include what the user said/answered/asked and the AI's feedback, corrections, or coaching.
            - If no session transcript was provided, Details should focus on source-grounded study details.
            - Do not invent user speech, answers, or AI feedback that is not in the transcript.
            - Keep the body under 250 words.
            - Prefer plain language over exhaustive detail.
            - No markdown fences and no extra JSON keys.
            """
        }

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseGeneratedNote(from: result, mode: mode)
    }

    func generateSlideDeck(
        from pages: [PageCapture],
        bookTitle: String,
        customInstructions: String? = nil
    ) async throws -> GeneratedSlideDeck {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "No completed pages available for a slide deck"]
            )
        }

        let sourceText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let titleText = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let customInstructionText = customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let customInstructionSection = customInstructionText.isEmpty
            ? "Use a concise presentation-ready structure."
            : customInstructionText

        let prompt = """
        You are an expert presentation designer. Generate a real slide deck from the selected study material.

        Project title:
        \(titleText.isEmpty ? "Untitled project" : titleText)

        Creation preferences:
        \(customInstructionSection)

        Source material:
        \(sourceText)

        Return ONLY valid JSON in this exact shape:
        {
          "title": "deck title",
          "slides": [
            {
              "title": "slide title",
              "bullets": ["short bullet", "short bullet"],
              "speakerNotes": "1-3 sentences the presenter can say"
            }
          ]
        }

        Requirements:
        - This must be a slide deck, not study notes.
        - Match the requested target length when provided.
        - Include a title slide and a closing/review slide when useful.
        - Each slide should have 2-4 concise bullets.
        - Speaker notes should explain the slide in plain language.
        - Keep every bullet source-grounded.
        - No markdown fences and no extra JSON keys.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseGeneratedSlideDeck(from: result)
    }

    func generatePaper(
        from pages: [PageCapture],
        bookTitle: String,
        customInstructions: String? = nil
    ) async throws -> GeneratedPaper {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            throw NSError(
                domain: "MemorizeService",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "No completed pages available for a paper"]
            )
        }

        let sourceText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let titleText = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let customInstructionText = customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let customInstructionSection = customInstructionText.isEmpty
            ? "Write a clear, source-grounded paper with a thesis, evidence, and conclusion."
            : customInstructionText

        let prompt = """
        You are an expert academic writing assistant. Generate a paper from the selected study material.

        Project title:
        \(titleText.isEmpty ? "Untitled project" : titleText)

        Creation preferences:
        \(customInstructionSection)

        Source material:
        \(sourceText)

        Return ONLY valid JSON in this exact shape:
        {
          "title": "paper title",
          "body": "full paper text"
        }

        Requirements:
        - This must be a paper, not study notes.
        - Match the requested target length when provided.
        - Use a paper structure: title, introduction, thesis, body paragraphs with evidence, and conclusion.
        - Write in polished paragraphs, not bullet-heavy notes.
        - Stay grounded in the selected sources.
        - Do not invent citations, page numbers, quotes, authors, or facts not present in the sources.
        - Use plain text only. No markdown fences and no extra JSON keys.
        """

        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)
        return parseGeneratedPaper(from: result)
    }

    private func parseQuizQuestions(from response: String) -> [QuizQuestion] {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonObjectString = extractJSONObject(from: cleaned)

        struct RawQuestionEnvelope: Decodable {
            let total_questions: Int?
            let concepts: [String]?
            let questions: [RawQuestion]
        }

        struct RawQuestion: Decodable {
            let type: String?
            let concept: String?
            let question: String
            let options: [String]
            let answer: String
            let explanation: String?
        }

        struct LegacyRawQuestion: Decodable {
            let question: String
            let options: [String]
            let correctIndex: Int
        }

        if let jsonObjectString,
           let data = jsonObjectString.data(using: .utf8),
           let rawEnvelope = try? JSONDecoder().decode(RawQuestionEnvelope.self, from: data) {
            let knownConcepts = rawEnvelope.concepts ?? []
            let parsedQuestions = rawEnvelope.questions.compactMap { q -> QuizQuestion? in
                guard q.options.count == 4 else { return nil }

                let normalizedAnswer = q.answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let correctIndex = q.options.firstIndex {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedAnswer
                } ?? answerIndex(from: normalizedAnswer)

                guard let correctIndex, correctIndex >= 0, correctIndex < q.options.count else { return nil }

                let fallbackConcept = knownConcepts.first { concept in
                    q.question.localizedCaseInsensitiveContains(concept)
                }

                return QuizQuestion(
                    type: q.type,
                    concept: q.concept ?? fallbackConcept,
                    question: q.question,
                    options: q.options,
                    correctIndex: correctIndex,
                    explanation: q.explanation
                )
            }

            if !parsedQuestions.isEmpty {
                return parsedQuestions
            }
        }

        let jsonArrayString = extractJSONArray(from: cleaned) ?? cleaned
        guard let legacyData = jsonArrayString.data(using: .utf8) else { return [] }

        do {
            let raw = try JSONDecoder().decode([LegacyRawQuestion].self, from: legacyData)
            return raw.compactMap { q in
                guard q.options.count == 4, q.correctIndex >= 0, q.correctIndex < 4 else { return nil }
                return QuizQuestion(question: q.question, options: q.options, correctIndex: q.correctIndex)
            }
        } catch {
            print("❌ [Memorize] Quiz JSON parse error: \(error)")
            return []
        }
    }

    private func answerIndex(from normalizedAnswer: String) -> Int? {
        switch normalizedAnswer {
        case "a", "option a":
            return 0
        case "b", "option b":
            return 1
        case "c", "option c":
            return 2
        case "d", "option d":
            return 3
        default:
            return nil
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

    private func parseGeneratedNote(from response: String, mode: GeneratedNoteKind) -> GeneratedNote {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        struct RawGeneratedNote: Decodable {
            let title: String?
            let body: String?
        }

        if let data = jsonString.data(using: .utf8),
           let raw = try? JSONDecoder().decode(RawGeneratedNote.self, from: data) {
            let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = raw.body?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let body, !body.isEmpty {
                return GeneratedNote(
                    title: title?.isEmpty == false ? title! : "memorize.notes_generated_title".localized,
                    body: body,
                    mode: mode
                )
            }
        }

        let fallbackBody = cleaned.isEmpty
            ? "memorize.notes_empty_generated".localized
            : cleaned
        return GeneratedNote(
            title: "memorize.notes_generated_title".localized,
            body: fallbackBody,
            mode: mode
        )
    }

    private func parseGeneratedSlideDeck(from response: String) -> GeneratedSlideDeck {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        struct RawDeck: Decodable {
            let title: String?
            let slides: [RawSlide]?
        }

        struct RawSlide: Decodable {
            let title: String?
            let bullets: [String]?
            let speakerNotes: String?
        }

        if let data = jsonString.data(using: .utf8),
           let raw = try? JSONDecoder().decode(RawDeck.self, from: data) {
            let slides = (raw.slides ?? []).compactMap { rawSlide -> GeneratedSlide? in
                let title = rawSlide.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let bullets = (rawSlide.bullets ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let speakerNotes = rawSlide.speakerNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !title.isEmpty || !bullets.isEmpty || !speakerNotes.isEmpty else { return nil }
                return GeneratedSlide(
                    title: title.isEmpty ? "Slide" : title,
                    bullets: bullets,
                    speakerNotes: speakerNotes
                )
            }

            if !slides.isEmpty {
                let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return GeneratedSlideDeck(
                    title: title.isEmpty ? "Generated slide deck" : title,
                    slides: slides
                )
            }
        }

        let fallbackBullets = Array(
            cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-*•# \t")) }
                .filter { !$0.isEmpty }
                .prefix(4)
        )

        let fallbackSlide = GeneratedSlide(
            title: "Generated slide deck",
            bullets: fallbackBullets,
            speakerNotes: cleaned.isEmpty ? "Unable to parse the slide deck response. Please try again." : cleaned
        )

        return GeneratedSlideDeck(title: "Generated slide deck", slides: [fallbackSlide])
    }

    private func parseGeneratedPaper(from response: String) -> GeneratedPaper {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned) ?? cleaned

        struct RawPaper: Decodable {
            let title: String?
            let body: String?
        }

        if let data = jsonString.data(using: .utf8),
           let raw = try? JSONDecoder().decode(RawPaper.self, from: data) {
            let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let body = raw.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !body.isEmpty {
                return GeneratedPaper(
                    title: title.isEmpty ? "Generated paper" : title,
                    body: body
                )
            }
        }

        return GeneratedPaper(
            title: "Generated paper",
            body: cleaned.isEmpty ? "Unable to parse the paper response. Please try again." : cleaned
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

        let joinedTranscript = dedupedSegments.reduce(into: "") { partialResult, segment in
            if partialResult.isEmpty {
                partialResult = segment
            } else if partialResult.hasSuffix("-") {
                partialResult += segment
            } else {
                partialResult += " " + segment
            }
        }

        return paragraphizeTranscript(joinedTranscript)
    }

    private func paragraphizeTranscript(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return "" }

        let sentencePattern = #"[^.!?]+(?:[.!?]+|$)"#
        let regex = try? NSRegularExpression(pattern: sentencePattern)
        let nsRange = NSRange(normalized.startIndex..., in: normalized)
        let sentenceMatches = regex?.matches(in: normalized, range: nsRange) ?? []

        let sentences = sentenceMatches.compactMap { match -> String? in
            guard let range = Range(match.range, in: normalized) else { return nil }
            let sentence = normalized[range]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }

        // If no sentence boundaries found (unpunctuated transcript),
        // break into paragraphs by word count instead.
        if sentences.count <= 1 {
            return paragraphizeByWordCount(normalized, wordsPerParagraph: 50)
        }

        var paragraphs: [String] = []
        var currentSentences: [String] = []
        var currentWordCount = 0

        for sentence in sentences {
            let wordCount = sentence.split(separator: " ").count
            let projectedWords = currentWordCount + wordCount

            // Break every ~50 words or 2-3 sentences for readable paragraphs
            let shouldBreak =
                !currentSentences.isEmpty &&
                (projectedWords >= 50 || currentSentences.count >= 3)

            if shouldBreak {
                paragraphs.append(currentSentences.joined(separator: " "))
                currentSentences = [sentence]
                currentWordCount = wordCount
            } else {
                currentSentences.append(sentence)
                currentWordCount = projectedWords
            }
        }

        if !currentSentences.isEmpty {
            paragraphs.append(currentSentences.joined(separator: " "))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private func paragraphizeByWordCount(_ text: String, wordsPerParagraph: Int) -> String {
        let words = text.split(separator: " ")
        guard words.count > wordsPerParagraph else { return text }

        var paragraphs: [String] = []
        var currentWords: [Substring] = []

        for word in words {
            currentWords.append(word)
            if currentWords.count >= wordsPerParagraph {
                paragraphs.append(currentWords.joined(separator: " "))
                currentWords = []
            }
        }

        if !currentWords.isEmpty {
            paragraphs.append(currentWords.joined(separator: " "))
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
