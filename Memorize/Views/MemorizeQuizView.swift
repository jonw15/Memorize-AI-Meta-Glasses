/*
 * Memorize Quiz View
 * Interactive multiple-choice quiz generated from captured book pages
 */

import SwiftUI
import AVFoundation

struct MemorizeQuizView: View {
    @Binding var questions: [QuizQuestion]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceAssistant = QuizVoiceAssistant()

    @State private var currentIndex: Int = 0
    @State private var showResults: Bool = false

    private var score: Int {
        questions.filter { $0.selectedIndex == $0.correctIndex }.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.memorizeBackground.ignoresSafeArea()

                if showResults {
                    resultsView
                } else if questions.isEmpty {
                    emptyView
                } else {
                    questionView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("memorize.pop_quiz".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            // Let the audio session from the previous screen fully release
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            voiceAssistant.enableVoiceAnswering { action in
                switch action {
                case .answer(let answerIndex):
                    selectAnswer(answerIndex)
                case .next:
                    goToNextQuestion()
                }
            }
            voiceAssistant.connect()
            // Wait for connection before speaking the first question
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if voiceAssistant.isConnected { break }
            }
            speakCurrentQuestionIfNeeded()
        }
        .onChange(of: currentIndex) { _ in
            speakCurrentQuestionIfNeeded()
        }
        .onChange(of: showResults) { isShowingResults in
            if isShowingResults {
                voiceAssistant.disableVoiceAnswering()
            } else {
                voiceAssistant.enableVoiceAnswering { action in
                    switch action {
                    case .answer(let answerIndex):
                        selectAnswer(answerIndex)
                    case .next:
                        goToNextQuestion()
                    }
                }
                speakCurrentQuestionIfNeeded()
            }
        }
        .onDisappear {
            voiceAssistant.disableVoiceAnswering()
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        let question = questions[currentIndex]

        return VStack(spacing: AppSpacing.lg) {
            // Question counter
            Text(String(format: "memorize.quiz_question_count".localized, currentIndex + 1, questions.count))
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.5))
                .padding(.top, AppSpacing.lg)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.memorizeAccent)
                        .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(questions.count), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AppSpacing.md)

            // Question card (scrolls for long prompts)
            ScrollView(.vertical, showsIndicators: true) {
                Text(question.question)
                    .font(AppTypography.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.memorizeCard)
                    .cornerRadius(AppCornerRadius.md)
                    .padding(.horizontal, AppSpacing.md)
            }
            .frame(minHeight: 120, maxHeight: 220)

            // Answer options (scrolls when options are long)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(0..<question.options.count, id: \.self) { index in
                        optionRow(index: index, question: question)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .frame(maxHeight: 320)

            Spacer()

            // Next / See Results button
            if question.selectedIndex != nil {
                Button {
                    goToNextQuestion()
                } label: {
                    Text(currentIndex < questions.count - 1
                         ? "memorize.quiz_next".localized
                         : "memorize.quiz_results".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.memorizeAccent)
                        .cornerRadius(AppCornerRadius.md)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: question.selectedIndex)
    }

    private func optionRow(index: Int, question: QuizQuestion) -> some View {
        let isSelected = question.selectedIndex == index
        let isAnswered = question.selectedIndex != nil
        let isCorrect = index == question.correctIndex

        let backgroundColor: Color = {
            if !isAnswered { return AppColors.memorizeCard }
            if isCorrect { return Color.green.opacity(0.2) }
            if isSelected && !isCorrect { return Color.red.opacity(0.2) }
            return AppColors.memorizeCard
        }()

        let borderColor: Color = {
            if !isAnswered { return Color.white.opacity(0.1) }
            if isCorrect { return Color.green }
            if isSelected && !isCorrect { return Color.red }
            return Color.white.opacity(0.1)
        }()

        return Button {
            selectAnswer(index, fromTap: true)
        } label: {
            HStack(spacing: 12) {
                // Option letter
                Text(["A", "B", "C", "D"][index])
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.memorizeAccent : Color.white.opacity(0.1))
                    )

                Text(question.options[index])
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                // Result icon
                if isAnswered {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(backgroundColor)
            .cornerRadius(AppCornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .disabled(isAnswered)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Score circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: questions.isEmpty ? 0 : CGFloat(score) / CGFloat(questions.count))
                    .stroke(
                        score == questions.count ? Color.green :
                            score >= questions.count / 2 ? AppColors.memorizeAccent : Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(score)/\(questions.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            Text(String(format: "memorize.quiz_score".localized, score, questions.count))
                .font(AppTypography.title)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Spacer()

            // Done button
            Button {
                dismiss()
            } label: {
                Text("memorize.quiz_done".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.memorizeAccent)
                    .cornerRadius(AppCornerRadius.md)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(Color.white.opacity(0.3))
            Text("memorize.quiz_no_pages".localized)
                .font(AppTypography.body)
                .foregroundColor(Color.white.opacity(0.5))
        }
    }

    private func speakCurrentQuestionIfNeeded() {
        guard !showResults, !questions.isEmpty, currentIndex < questions.count else { return }
        let question = questions[currentIndex]
        guard question.selectedIndex == nil else { return }
        voiceAssistant.speakQuestion(question: question, index: currentIndex + 1, total: questions.count)
    }

    private func selectAnswer(_ index: Int, fromTap: Bool = false) {
        guard !showResults, currentIndex < questions.count else { return }
        guard questions[currentIndex].selectedIndex == nil else { return }
        guard index >= 0, index < questions[currentIndex].options.count else { return }

        questions[currentIndex].selectedIndex = index

        let isCorrect = index == questions[currentIndex].correctIndex
        if isCorrect {
            voiceAssistant.speakFeedback("Correct.", immediate: fromTap)
        } else {
            let correctIndex = questions[currentIndex].correctIndex
            let correctLetter = ["A", "B", "C", "D"][correctIndex]
            let correctText = questions[currentIndex].options[correctIndex]
            voiceAssistant.speakFeedback("Wrong. The correct answer is \(correctLetter): \(correctText).", immediate: fromTap)
        }
    }

    private func goToNextQuestion() {
        guard !showResults, currentIndex < questions.count else { return }
        guard questions[currentIndex].selectedIndex != nil else { return }
        if currentIndex < questions.count - 1 {
            withAnimation {
                currentIndex += 1
            }
        } else {
            withAnimation {
                showResults = true
            }
        }
    }
}

@MainActor
private final class QuizVoiceAssistant: ObservableObject {
    enum VoiceAction {
        case answer(Int)
        case next
    }

    enum ListenMode {
        case waitingForAnswer   // only accept A/B/C/D
        case waitingForNext     // only accept "next"
    }

    @Published var isConnected = false

    private var geminiService: GeminiLiveService?
    private var onAction: ((VoiceAction) -> Void)?
    private var lastHeardAt: Date = .distantPast
    private var shouldListen = false
    private var isListeningForAnswer = false
    private var listenMode: ListenMode = .waitingForAnswer
    private var listenTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    // Accumulate transcript fragments from Gemini
    private var accumulatedTranscript = ""
    // Only start listening after OUR text finishes playing, not unsolicited Gemini responses
    private var awaitingOurSpeechDone = false

    func connect() {
        guard geminiService == nil else { return }

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let systemPrompt = """
        You are a text-to-speech engine. You receive text between [READ] and [/READ] tags.
        Read ONLY the text inside those tags aloud, word for word.
        After reading the text, STOP IMMEDIATELY. Do not continue speaking.
        NEVER add your own words, commentary, or follow-up.
        NEVER respond to audio from the microphone.
        NEVER say things like "Sure", "Of course", "Here we go", or any filler.
        Each message is independent — do NOT reference previous messages.
        """

        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )

        // Do NOT auto-start recording — we control mic on/off precisely
        service.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isConnected = true
            }
        }

        service.onUserTranscript = { [weak self] (text: String) in
            Task { @MainActor [weak self] in
                guard let self, self.shouldListen, self.isListeningForAnswer else { return }
                // Accumulate fragments (Gemini sends "Ne" then "xt question." as separate callbacks)
                self.accumulatedTranscript += text
                let normalized = self.accumulatedTranscript.lowercased()
                    .replacingOccurrences(of: "-", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                guard !normalized.isEmpty else { return }
                print("🎤 [QuizVoice] Heard: \(normalized) (mode: \(self.listenMode))")

                let action: VoiceAction?
                switch self.listenMode {
                case .waitingForAnswer:
                    if let answer = self.parseAnswer(from: normalized) {
                        action = .answer(answer)
                    } else {
                        action = nil
                    }
                case .waitingForNext:
                    if self.parseNext(from: normalized) {
                        action = .next
                    } else {
                        action = nil
                    }
                }

                guard let action else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastHeardAt) > 1.2 {
                    self.lastHeardAt = now
                    self.stopListeningForAnswer()
                    self.onAction?(action)
                }
            }
        }

        // Only start listening when OUR speech finishes (not unsolicited Gemini responses)
        service.onAudioDone = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.shouldListen, self.awaitingOurSpeechDone else { return }
                self.awaitingOurSpeechDone = false
                self.fallbackTask?.cancel()
                self.fallbackTask = nil
                print("🔊 [QuizVoice] Our speech finished, starting mic")
                self.startListeningForAnswer()
            }
        }

        service.onError = { (errorText: String) in
            print("❌ [QuizVoice] Gemini error: \(errorText)")
        }

        geminiService = service
        service.connect()
    }

    func disconnect() {
        listenTask?.cancel()
        listenTask = nil
        speechTask?.cancel()
        speechTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isListeningForAnswer = false
        awaitingOurSpeechDone = false
    }

    func speakQuestion(question: QuizQuestion, index: Int, total: Int) {
        stopListeningForAnswer()
        speechTask?.cancel()
        listenMode = .waitingForAnswer

        let letters = ["A", "B", "C", "D"]
        let optionText = question.options.enumerated().map { "\(letters[$0.offset]). \($0.element)" }.joined(separator: ". ")
        let text = "[READ] Question \(index) of \(total). \(question.question). \(optionText) [/READ]"

        speechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Wait for Gemini to finish processing any audio it already received
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self.geminiService?.interruptPlayback()
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            self.markSpeechSentAndStartFallback()
            self.geminiService?.sendTextInput(text)
            print("🔊 [QuizVoice] Sent question \(index)")
        }
    }

    func speakFeedback(_ text: String, immediate: Bool = false) {
        stopListeningForAnswer()
        speechTask?.cancel()
        listenMode = .waitingForNext

        if immediate {
            // Tap: interrupt immediately and send feedback without delay
            geminiService?.interruptPlayback()
            speechTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                self.markSpeechSentAndStartFallback()
                self.geminiService?.sendTextInput("[READ] \(text) [/READ]")
                print("🔊 [QuizVoice] Sent feedback (immediate)")
            }
        } else {
            // Voice: wait for Gemini to finish processing the user's audio
            speechTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                self.geminiService?.interruptPlayback()
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                self.markSpeechSentAndStartFallback()
                self.geminiService?.sendTextInput("[READ] \(text) [/READ]")
                print("🔊 [QuizVoice] Sent feedback")
            }
        }
    }

    func enableVoiceAnswering(onAction: @escaping (VoiceAction) -> Void) {
        self.onAction = onAction
        shouldListen = true
    }

    func disableVoiceAnswering() {
        shouldListen = false
        onAction = nil
        stopListeningForAnswer()
        disconnect()
    }

    /// Mark that we sent text and expect onAudioDone. Start a fallback timer
    /// in case onAudioDone never fires (e.g. playback engine was stopped).
    private func markSpeechSentAndStartFallback() {
        awaitingOurSpeechDone = true
        fallbackTask?.cancel()
        fallbackTask = Task { @MainActor [weak self] in
            // If onAudioDone doesn't fire within 6 seconds, start listening anyway
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.awaitingOurSpeechDone && self.shouldListen {
                print("⏰ [QuizVoice] Fallback: onAudioDone didn't fire, starting mic")
                self.awaitingOurSpeechDone = false
                self.startListeningForAnswer()
            }
        }
    }

    private func startListeningForAnswer() {
        guard shouldListen, !isListeningForAnswer else { return }
        listenTask?.cancel()
        listenTask = Task { @MainActor [weak self] in
            // Brief delay for audio session to settle after playback
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, let self else { return }
            self.accumulatedTranscript = ""
            self.isListeningForAnswer = true
            self.geminiService?.startRecording()
            print("🎤 [QuizVoice] Listening for \(self.listenMode)...")
        }
    }

    private func stopListeningForAnswer() {
        listenTask?.cancel()
        listenTask = nil
        if isListeningForAnswer {
            isListeningForAnswer = false
            geminiService?.stopRecording()
            print("🔇 [QuizVoice] Stopped listening")
        }
    }

    private func parseAnswer(from text: String) -> Int? {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty { return nil }

        let rawTokens = normalized.split(whereSeparator: { !$0.isLetter }).map(String.init)
        let tokens = rawTokens.map { canonicalToken($0) }

        if let first = tokens.first {
            switch first {
            case "a": return 0
            case "b": return 1
            case "c": return 2
            case "d": return 3
            default: break
            }
        }

        if let explicit = extractExplicitChoice(from: normalized, tokens: tokens) {
            return explicit
        }

        if let last = tokens.last {
            switch last {
            case "a": return 0
            case "b": return 1
            case "c": return 2
            case "d": return 3
            default: return nil
            }
        }

        return nil
    }

    private func parseNext(from normalized: String) -> Bool {
        return normalized.contains("next question") ||
            normalized == "next" ||
            normalized.hasSuffix(" next") ||
            normalized.contains("go next")
    }

    private func extractExplicitChoice(from normalized: String, tokens: [String]) -> Int? {
        let phrasePrefixes = [
            "option ",
            "answer ",
            "choose ",
            "i choose ",
            "pick ",
            "i pick ",
            "my answer is ",
            "the answer is ",
            "i select ",
            "select "
        ]

        for prefix in phrasePrefixes {
            if let range = normalized.range(of: prefix) {
                let remainder = normalized[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                let token = canonicalToken(String(remainder.split(whereSeparator: { !$0.isLetter }).first ?? ""))
                switch token {
                case "a": return 0
                case "b": return 1
                case "c": return 2
                case "d": return 3
                default: break
                }
            }
        }

        if tokens.contains("a") { return 0 }
        if tokens.contains("b") { return 1 }
        if tokens.contains("c") { return 2 }
        if tokens.contains("d") { return 3 }
        return nil
    }

    private func canonicalToken(_ token: String) -> String {
        switch token {
        case "a", "ay", "eh", "hey", "ey", "age":
            return "a"
        case "b", "bee", "be", "bea", "bi", "bei":
            return "b"
        case "c", "see", "cee", "sea", "si", "ce", "she", "ski", "se":
            return "c"
        case "d", "dee", "de", "di", "the", "die", "dy":
            return "d"
        default:
            return token
        }
    }
}
