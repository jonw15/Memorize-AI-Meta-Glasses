/*
 * Memorize Quiz View
 * Interactive multiple-choice quiz generated from captured book pages
 */

import SwiftUI
import Speech
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
            await voiceAssistant.requestPermissionsIfNeeded()
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
            selectAnswer(index)
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

    private func selectAnswer(_ index: Int) {
        guard !showResults, currentIndex < questions.count else { return }
        guard questions[currentIndex].selectedIndex == nil else { return }
        guard index >= 0, index < questions[currentIndex].options.count else { return }

        questions[currentIndex].selectedIndex = index

        let isCorrect = index == questions[currentIndex].correctIndex
        if isCorrect {
            voiceAssistant.speakFeedback("Correct.")
        } else {
            let correctIndex = questions[currentIndex].correctIndex
            let correctLetter = ["A", "B", "C", "D"][correctIndex]
            let correctText = questions[currentIndex].options[correctIndex]
            voiceAssistant.speakFeedback("Wrong. The correct answer is \(correctLetter): \(correctText).")
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
private final class QuizVoiceAssistant: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum VoiceAction {
        case answer(Int)
        case next
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onAction: ((VoiceAction) -> Void)?
    private var speechPermissionDenied = false
    private var micPermissionDenied = false
    private var isSpeaking = false
    private var lastHeardAt: Date = .distantPast
    private var shouldListen = false
    private var restartTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func requestPermissionsIfNeeded() async {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .authorized {
                continuation.resume(returning: true)
            } else {
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        }
        speechPermissionDenied = !speechAuthorized

        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        micPermissionDenied = !micAuthorized
    }

    func speakQuestion(question: QuizQuestion, index: Int, total: Int) {
        let letters = ["A", "B", "C", "D"]
        let optionText = question.options.enumerated().map { "\(letters[$0.offset]). \($0.element)" }.joined(separator: " ")
        speak("Question \(index) of \(total). \(question.question). \(optionText)")
    }

    func speakFeedback(_ text: String) {
        speak(text)
    }

    func enableVoiceAnswering(onAction: @escaping (VoiceAction) -> Void) {
        self.onAction = onAction
        shouldListen = true
    }

    func disableVoiceAnswering() {
        shouldListen = false
        stopListeningInternal(deactivateSession: true)
    }

    private func beginListeningIfNeeded() {
        guard shouldListen else { return }
        guard !speechPermissionDenied, !micPermissionDenied else { return }
        guard recognitionTask == nil else { return }
        guard !isSpeaking else { return }

        restartTask?.cancel()
        restartTask = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            scheduleRestart()
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let transcript = result?.bestTranscription.formattedString.lowercased(),
                   let action = parseAction(from: transcript),
                   !isSpeaking {
                    let now = Date()
                    if now.timeIntervalSince(lastHeardAt) > 1.2 {
                        lastHeardAt = now
                        self.onAction?(action)
                    }
                }

                if error != nil || (result?.isFinal ?? false) {
                    stopListeningInternal(deactivateSession: false)
                    scheduleRestart()
                }
            }
        }
    }

    private func stopListeningInternal(deactivateSession: Bool = false) {
        restartTask?.cancel()
        restartTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func speak(_ text: String) {
        // Keep audio session active for faster TTS -> mic handoff after speaking.
        stopListeningInternal(deactivateSession: false)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {}
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = preferredNaturalVoice() ?? AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    private func parseAnswer(from text: String) -> Int? {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty { return nil }

        let rawTokens = normalized.split(whereSeparator: { !$0.isLetter }).map(String.init)
        let tokens = rawTokens.map { canonicalToken($0) }

        // Natural speech pattern: "A, Macbook" / "B Macbook" / "C the answer is ..."
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

        // Fallback: single utterance like "a", "bee", "dee", etc.
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

    private func parseAction(from text: String) -> VoiceAction? {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("next question") ||
            normalized == "next" ||
            normalized.contains("go next") ||
            normalized.contains("continue") {
            return .next
        }

        if let answer = parseAnswer(from: normalized) {
            return .answer(answer)
        }
        return nil
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

        // Direct token fallback anywhere in transcript.
        if tokens.contains("a") { return 0 }
        if tokens.contains("b") { return 1 }
        if tokens.contains("c") { return 2 }
        if tokens.contains("d") { return 3 }
        return nil
    }

    private func canonicalToken(_ token: String) -> String {
        switch token {
        case "a", "ay", "eh", "hey":
            return "a"
        case "b", "bee", "be":
            return "b"
        case "c", "see", "cee", "sea":
            return "c"
        case "d", "dee", "de":
            return "d"
        default:
            return token
        }
    }

    private func preferredNaturalVoice() -> AVSpeechSynthesisVoice? {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"
        let languagePrefix = String(preferredLanguage.prefix(2))
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(languagePrefix.lowercased()) }
            .filter { !$0.identifier.lowercased().contains("siri") }

        if let premiumLike = candidates.first(where: { $0.identifier.lowercased().contains("premium") || $0.identifier.lowercased().contains("enhanced") }) {
            return premiumLike
        }
        return candidates.first
    }

    private func scheduleRestart() {
        guard shouldListen else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            self?.beginListeningIfNeeded()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.scheduleRestart()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.scheduleRestart()
        }
    }
}
