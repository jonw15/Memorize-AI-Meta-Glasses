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
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            voiceAssistant.enableVoiceAnswering { action in
                switch action {
                case .answer(let answerIndex):
                    selectAnswer(answerIndex)
                case .next:
                    goToNextQuestion()
                }
            }
            print("🧪 [Quiz] Voice answering enabled, speaking first question...")
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

            if let typeLabel = questionTypeLabel(for: question.type) {
                Text(typeLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.memorizeAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.memorizeCard)
                    .cornerRadius(AppCornerRadius.sm)
            }

            // Question + Answer options in one scroll
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: AppSpacing.md) {
                    // Question card
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if let concept = question.concept?.trimmingCharacters(in: .whitespacesAndNewlines), !concept.isEmpty {
                            Text(concept)
                                .font(AppTypography.caption)
                                .foregroundColor(Color.white.opacity(0.55))
                                .textCase(.uppercase)
                        }

                        Text(question.question)
                            .font(AppTypography.title)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.memorizeCard)
                    .cornerRadius(AppCornerRadius.md)

                    // Answer options
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(0..<question.options.count, id: \.self) { index in
                            optionRow(index: index, question: question)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }

            // Voice hint
            if question.selectedIndex == nil {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12))
                    Text("Say A, B, C, or D to answer")
                        .font(AppTypography.caption)
                }
                .foregroundColor(Color.white.opacity(0.35))
                .padding(.top, AppSpacing.xs)
            }

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

        let explanation = questions[currentIndex].explanation?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isCorrect = index == questions[currentIndex].correctIndex
        if isCorrect {
            let feedback = explanation.isEmpty ? "Correct." : "Correct. \(explanation)"
            voiceAssistant.speakFeedback(feedback, immediate: fromTap)
        } else {
            let correctIndex = questions[currentIndex].correctIndex
            let correctLetter = ["A", "B", "C", "D"][correctIndex]
            let correctText = questions[currentIndex].options[correctIndex]
            let feedbackBase = "Wrong. The correct answer is \(correctLetter): \(correctText)."
            let feedback = explanation.isEmpty ? feedbackBase : "\(feedbackBase) \(explanation)"
            voiceAssistant.speakFeedback(feedback, immediate: fromTap)
        }
    }

    private func questionTypeLabel(for rawType: String?) -> String? {
        guard let rawType = rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawType.isEmpty else { return nil }

        switch rawType {
        case "core":
            return "Core Understanding"
        case "detail":
            return "Key Detail"
        case "application":
            return "Application"
        default:
            return rawType.capitalized
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
    // True while we've stopped mic but are still collecting buffered fragments
    private var isProcessingTranscript = false
    private var transcriptDebounceTask: Task<Void, Never>?
    // Only start listening after OUR text finishes playing, not unsolicited Gemini responses
    private var awaitingOurSpeechDone = false
    private var sawAssistantAudioThisTurn = false

    func connect() {
        guard geminiService == nil else { return }

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let systemPrompt = """
        You are a text-to-speech engine. You receive text between [READ] and [/READ] tags.
        Read ONLY the text inside those tags aloud, word for word.
        After reading the text, STOP IMMEDIATELY. Do not continue speaking.
        NEVER add your own words, commentary, or follow-up.
        NEVER respond to audio from the microphone. Ignore all microphone input completely.
        NEVER say things like "Sure", "Of course", "Here we go", or any filler.
        NEVER generate quiz questions, answers, or any content on your own.
        Each message is independent — do NOT reference previous messages or anticipate future ones.
        You have NO memory of previous questions. Wait for the next [READ] tag.
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
                guard let self, self.shouldListen else { return }
                // Accept fragments even after mic is stopped (buffered audio still arrives)
                guard self.isListeningForAnswer || self.isProcessingTranscript else { return }

                // IMMEDIATELY stop recording on first fragment to prevent Gemini
                // from hearing the full utterance and responding on its own
                if self.isListeningForAnswer {
                    self.geminiService?.stopRecording()
                    self.isListeningForAnswer = false
                    self.isProcessingTranscript = true
                }

                // Accumulate fragments (Gemini sends "Ne" then "xt question." as separate callbacks)
                self.accumulatedTranscript += text

                // Debounce: wait for fragments to stop arriving before processing
                self.transcriptDebounceTask?.cancel()
                self.transcriptDebounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.processAccumulatedTranscript()
                }
            }
        }

        service.onAudioDelta = { [weak self] (_: Data) in
            Task { @MainActor [weak self] in
                self?.sawAssistantAudioThisTurn = true
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

        service.onTranscriptDone = { [weak self] (_: String) in
            Task { @MainActor [weak self] in
                guard let self, self.shouldListen, self.awaitingOurSpeechDone else { return }
                guard !self.sawAssistantAudioThisTurn else { return }
                self.awaitingOurSpeechDone = false
                self.fallbackTask?.cancel()
                self.fallbackTask = nil
                print("📝 [QuizVoice] Transcript-only turn finished, starting mic")
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
        transcriptDebounceTask?.cancel()
        transcriptDebounceTask = nil
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isListeningForAnswer = false
        isProcessingTranscript = false
        awaitingOurSpeechDone = false
    }

    func speakQuestion(question: QuizQuestion, index: Int, total: Int) {
        stopListeningForAnswer()
        speechTask?.cancel()
        fallbackTask?.cancel()
        fallbackTask = nil
        listenMode = .waitingForAnswer
        awaitingOurSpeechDone = false

        let letters = ["A", "B", "C", "D"]
        let optionText = question.options.enumerated().map { "\(letters[$0.offset]). \($0.element)" }.joined(separator: ". ")
        let typePrefix = questionTypeLabel(for: question.type).map { "\($0). " } ?? ""
        let text = "[READ] Question \(index) of \(total). \(typePrefix)\(question.question). \(optionText) [/READ]"
        sawAssistantAudioThisTurn = false

        speechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let connected = await self.prepareFreshSpeechConnection()
            guard connected, !Task.isCancelled else { return }
            guard !Task.isCancelled else { return }
            self.markSpeechSentAndStartFallback()
            self.geminiService?.sendTextInput(text)
            print("🔊 [QuizVoice] Sent question \(index)")
        }
    }

    func speakFeedback(_ text: String, immediate: Bool = false) {
        stopListeningForAnswer()
        speechTask?.cancel()
        fallbackTask?.cancel()
        fallbackTask = nil
        listenMode = .waitingForNext
        awaitingOurSpeechDone = false
        sawAssistantAudioThisTurn = false

        speechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let connected = await self.prepareFreshSpeechConnection()
            guard connected, !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: immediate ? 50_000_000 : 150_000_000)
            guard !Task.isCancelled else { return }
            self.markSpeechSentAndStartFallback()
            self.geminiService?.sendTextInput("[READ] \(text) [/READ]")
            print("🔊 [QuizVoice] Sent feedback\(immediate ? " (immediate)" : "")")
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
        print("🔊 [QuizVoice] Waiting for Gemini speech to finish")
        fallbackTask = Task { @MainActor [weak self] in
            // If finish callbacks don't arrive promptly, start listening anyway.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.awaitingOurSpeechDone && self.shouldListen {
                print("⏰ [QuizVoice] Fallback: onAudioDone didn't fire, starting mic")
                self.awaitingOurSpeechDone = false
                self.startListeningForAnswer()
            }
        }
    }

    private func prepareFreshSpeechConnection() async -> Bool {
        resetConnectionForFreshTurn()
        connect()

        for _ in 0..<30 {
            if isConnected { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return isConnected
    }

    private func resetConnectionForFreshTurn() {
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isListeningForAnswer = false
        isProcessingTranscript = false
        accumulatedTranscript = ""
        awaitingOurSpeechDone = false
        sawAssistantAudioThisTurn = false
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
        transcriptDebounceTask?.cancel()
        transcriptDebounceTask = nil
        isProcessingTranscript = false
        if isListeningForAnswer {
            isListeningForAnswer = false
            geminiService?.stopRecording()
            print("🔇 [QuizVoice] Stopped listening")
        }
    }

    /// Process accumulated transcript fragments after debounce timer fires
    private func processAccumulatedTranscript() {
        isProcessingTranscript = false
        let normalized = accumulatedTranscript.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else {
            resumeListening()
            return
        }
        print("🎤 [QuizVoice] Heard: \(normalized) (mode: \(listenMode))")

        let action: VoiceAction?
        switch listenMode {
        case .waitingForAnswer:
            if let answer = parseAnswer(from: normalized) {
                action = .answer(answer)
            } else if parseNext(from: normalized) {
                print("⚠️ [QuizVoice] Ignoring 'next' in waitingForAnswer mode")
                accumulatedTranscript = ""
                resumeListeningAfterDelay()
                return
            } else {
                action = nil
            }
        case .waitingForNext:
            if parseNext(from: normalized) {
                action = .next
            } else {
                action = nil
            }
        }

        if let action {
            let now = Date()
            if now.timeIntervalSince(lastHeardAt) > 1.2 {
                lastHeardAt = now
                // Interrupt any unsolicited Gemini speech before sending our response
                geminiService?.interruptPlayback()
                onAction?(action)
                return
            }
        }

        // No valid action — resume listening
        resumeListening()
    }

    private func resumeListening() {
        guard shouldListen, !isListeningForAnswer else { return }
        accumulatedTranscript = ""
        isListeningForAnswer = true
        geminiService?.startRecording()
        print("🎤 [QuizVoice] Resumed listening for \(listenMode)...")
    }

    private func resumeListeningAfterDelay() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, self.shouldListen else { return }
            self.resumeListening()
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

    private func questionTypeLabel(for rawType: String?) -> String? {
        guard let rawType = rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawType.isEmpty else { return nil }

        switch rawType {
        case "core":
            return "Core understanding"
        case "detail":
            return "Key detail"
        case "application":
            return "Application"
        default:
            return rawType.capitalized
        }
    }
}
