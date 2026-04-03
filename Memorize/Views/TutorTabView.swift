/*
 * Tutor Tab View
 * Interactive AI-guided voice study session using a 7-step learning technique
 * Uses GeminiLiveService for real-time voice conversation
 */

import SwiftUI
import AVFoundation

// MARK: - Study Steps

enum TutorStep: Int, CaseIterable {
    case focus = 0
    case preview
    case learn
    case explain
    case recall
    case teach
    case review

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .preview: return "Preview"
        case .learn: return "Learn"
        case .explain: return "Explain"
        case .recall: return "Recall"
        case .teach: return "Teach"
        case .review: return "Review"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "target"
        case .preview: return "map"
        case .learn: return "book.fill"
        case .explain: return "text.bubble.fill"
        case .recall: return "brain.head.profile"
        case .teach: return "person.2.fill"
        case .review: return "checkmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .focus: return "Get into learning mode"
        case .preview: return "Build your mental map"
        case .learn: return "One concept at a time"
        case .explain: return "Say it in your own words"
        case .recall: return "Test your memory"
        case .teach: return "Teach it to someone else"
        case .review: return "Review and plan ahead"
        }
    }
}

// MARK: - Tutor Tab View

struct TutorTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel

    @State private var currentStep: TutorStep = .focus
    @State private var hasStartedSession = false
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var isRecording = false
    @State private var isMuted = false
    @State private var messages: [MemorizeInteractMessage] = []
    @State private var currentAIText = ""
    @State private var currentUserText = ""
    @State private var isAIThinking = false
    @State private var errorMessage: String?
    @State private var isTransitioning = false
    @State private var transitionIsFinishing = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var shouldRestoreMuteAfterTransition = false
    @State private var serviceSessionID = UUID()
    @State private var supportsHandsFreeMic = false
    @State private var isAISpeaking = false
    @AppStorage("geminiSelectedVoice") private var selectedVoice = "Aoede"
    @State private var showVoicePicker = false

    private let tutorAccent = Color(red: 0.55, green: 0.35, blue: 0.85)

    private var sourceContext: String {
        buildMemorizeLiveSourceContext(
            from: viewModel.allCompletedPages,
            maxPages: 8,
            maxCharsPerPage: 340,
            maxTotalChars: 4200
        )
    }

    private var hasContent: Bool {
        !viewModel.allCompletedPages.isEmpty
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !hasContent {
                    noContentView
                } else if !hasStartedSession {
                    sessionStartView
                } else {
                    activeSessionView
                }
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("AI Tutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        endSession()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                if hasStartedSession {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            endSession()
                            dismiss()
                        } label: {
                            Text("End")
                                .font(AppTypography.subheadline)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showVoicePicker) {
            GeminiVoicePickerView(selectedVoice: $selectedVoice, accent: tutorAccent)
                .presentationDetents([.medium])
        }
        .onChange(of: selectedVoice) { _ in
            guard geminiService != nil else { return }
            reconnectWithNewVoice()
        }
    }

    // MARK: - No Content

    private var noContentView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "graduationcap")
                .font(.system(size: 40))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Add sources first to start a tutoring session")
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Session Start

    private var sessionStartView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 48))
                    .foregroundColor(tutorAccent)

                Text("AI Tutor")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("A voice-guided study session using proven learning techniques")
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            // Steps overview
            VStack(spacing: AppSpacing.xs) {
                ForEach(TutorStep.allCases, id: \.self) { step in
                    HStack(spacing: 12) {
                        Image(systemName: step.icon)
                            .font(.system(size: 14))
                            .foregroundColor(tutorAccent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.title)
                                .font(AppTypography.subheadline)
                                .foregroundColor(.white)
                            Text(step.description)
                                .font(AppTypography.caption)
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.lg)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)

            Spacer()

            Button {
                hasStartedSession = true
                setupAndConnect()
            } label: {
                Text("Start Session")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(tutorAccent)
                    .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Active Session

    private var activeSessionView: some View {
        VStack(spacing: 0) {
            // Step progress bar
            stepProgressBar
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

            // Current step label
            HStack(spacing: 8) {
                Image(systemName: currentStep.icon)
                    .font(.system(size: 14))
                Text(currentStep.title)
                    .font(AppTypography.headline)
            }
            .foregroundColor(tutorAccent)
            .padding(.top, AppSpacing.sm)

            // Conversation
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty && currentAIText.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(tutorAccent)
                                .scaleEffect(1.1)
                            Text(isConnected ? "Your tutor is preparing..." : "Connecting to your AI tutor...")
                                .font(AppTypography.subheadline)
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                chatBubble(message)
                            }

                            // Streaming AI text (shows in real-time as AI speaks)
                            if !currentAIText.isEmpty {
                                chatBubble(MemorizeInteractMessage(isUser: false, text: currentAIText))
                                    .id("streaming")
                            }

                            // Loading indicator (before AI starts speaking)
                            if isAIThinking && currentAIText.isEmpty {
                                thinkingDots
                                    .id("thinking")
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        if isAIThinking && currentAIText.isEmpty {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        } else {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: currentAIText) { _ in
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
                .onChange(of: isAIThinking) { thinking in
                    if thinking {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.md)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            // Controls
            HStack(spacing: AppSpacing.md) {
                // Mic toggle
                Button {
                    toggleMic()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isMuted ? "Unmute" : "Mute")
                            .font(AppTypography.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(isMuted ? Color.white.opacity(0.15) : tutorAccent.opacity(0.5))
                    .cornerRadius(AppCornerRadius.md)
                }

                // Next step button
                Button {
                    isAIThinking = true
                    advanceToNextStep()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: currentStep == .review ? "checkmark" : "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text(currentStep == .review ? "Finish" : "Next")
                            .font(AppTypography.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.6))
                    .cornerRadius(AppCornerRadius.md)
                }
                .disabled(isTransitioning || !isConnected)
                .opacity((isTransitioning || !isConnected) ? 0.5 : 1.0)

                // Voice picker
                Button {
                    showVoicePicker = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(AppSpacing.md)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Step Progress Bar

    private var stepProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(TutorStep.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(stepColor(step))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func stepColor(_ step: TutorStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return Color.green
        } else if step == currentStep {
            return tutorAccent
        } else {
            return Color.white.opacity(0.15)
        }
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: MemorizeInteractMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            Text(message.text)
                .font(AppTypography.body)
                .foregroundColor(.white)
                .multilineTextAlignment(message.isUser ? .trailing : .leading)
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                        .fill(message.isUser ? tutorAccent.opacity(0.3) : Color.white.opacity(0.08))
                )
            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    private var thinkingDots: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(tutorAccent)
                .scaleEffect(0.8)
            Text("Tutor is thinking...")
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(AppCornerRadius.md)
    }

    // MARK: - Actions

    private func toggleMic() {
        guard let service = geminiService else { return }
        let routeSupportsHandsFreeMic = service.supportsHandsFreeMicRoute()
        supportsHandsFreeMic = routeSupportsHandsFreeMic

        if isMuted {
            isMuted = false
            service.isMicMuted = routeSupportsHandsFreeMic ? false : isAISpeaking
        } else {
            service.isMicMuted = true
            isMuted = true
        }
    }

    private func advanceToNextStep() {
        guard !isTransitioning else { return }

        let next = currentStep.rawValue + 1
        let isFinishing = TutorStep(rawValue: next) == nil

        if let nextStep = TutorStep(rawValue: next) {
            currentStep = nextStep
        }

        transitionTask?.cancel()
        isTransitioning = true
        transitionIsFinishing = isFinishing
        shouldRestoreMuteAfterTransition = isMuted
        currentAIText = ""
        currentUserText = ""
        isAIThinking = true
        isConnected = false
        isRecording = false
        supportsHandsFreeMic = false
        isAISpeaking = false
        serviceSessionID = UUID()
        geminiService?.disconnect()
        geminiService = nil

        transitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, isTransitioning else { return }
            setupAndConnect(initialPrompt: promptForCurrentStep(isFinishing: transitionIsFinishing))
        }
    }

    private func endSession() {
        transitionTask?.cancel()
        transitionTask = nil
        serviceSessionID = UUID()
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isRecording = false
        hasStartedSession = false
        messages = []
        currentAIText = ""
        currentUserText = ""
        currentStep = .focus
        isAIThinking = false
        isTransitioning = false
        transitionIsFinishing = false
        supportsHandsFreeMic = false
        isAISpeaking = false
    }

    private func reconnectWithNewVoice() {
        transitionTask?.cancel()
        transitionTask = nil
        serviceSessionID = UUID()
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isRecording = false
        messages = []
        currentAIText = ""
        currentUserText = ""
        isAIThinking = false
        isTransitioning = false
        transitionIsFinishing = false
        supportsHandsFreeMic = false
        isAISpeaking = false
        setupAndConnect()
    }

    // MARK: - Gemini Setup

    private func setupAndConnect(initialPrompt: String? = nil) {
        let bookTitle = viewModel.book.title
        let context = sourceContext
        let sessionID = UUID()
        serviceSessionID = sessionID

        let systemPrompt = """
        You are an expert AI tutor conducting a structured voice study session. You are warm, encouraging, and direct.

        The student is studying this material from "\(bookTitle)":

        ---
        \(context)
        ---

        You will guide them through 7 steps. You are currently on Step 1: Focus.

        STEP INSTRUCTIONS:
        1. FOCUS: Ask the student one question at a time: (a) What are you studying today? (b) Why does this matter to you? (c) How confident are you right now, 1 to 10? Get them mentally ready.
        2. PREVIEW: Give a quick overview — main topic, 3-5 key concepts, important vocabulary. Make it scannable.
        3. LEARN: Present ONE concept at a time. Short summary, concrete example or analogy. Make it feel easy. Ask if they understand before continuing.
        4. EXPLAIN: Ask the student to explain what they just learned in their own words. Give feedback on what was good and what they missed.
        5. RECALL: Hide the notes. Ask specific memory questions: "What were the main ideas?" "Define this term." Give feedback after each answer.
        6. TEACH: Challenge them: "Teach this like you're explaining to a friend" or "Explain to a 10-year-old." Evaluate clarity, accuracy, simplicity.
        7. REVIEW: Summarize key takeaways, what they did well, areas to review, and suggest spaced repetition (tomorrow, 3 days, 1 week).

        RULES:
        - Keep responses concise — 2-4 sentences for voice. This is a conversation, not a lecture.
        - Wait for the student to respond before moving on.
        - Be encouraging but honest about mistakes.
        - When the student says "next" or "continue", move to the next step.
        - Reference specific content from the source material.
        - Speak naturally as if you're sitting across from them.

        Start now with Step 1: Focus. Greet the student warmly and ask your first question.
        """

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )
        service.voiceName = selectedVoice

        service.onConnected = { [service] in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                isConnected = true
                service.startRecording()
                isRecording = true

                let routeSupportsHandsFreeMic = service.supportsHandsFreeMicRoute()
                supportsHandsFreeMic = routeSupportsHandsFreeMic
                isAISpeaking = false
                isMuted = false
                service.isMicMuted = !routeSupportsHandsFreeMic

                // Brief delay then send the initial prompt.
                try? await Task.sleep(nanoseconds: 300_000_000)
                service.sendTextInput(initialPrompt ?? promptForCurrentStep(isFinishing: false))
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                guard !isTransitioning else { return }
                guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                currentUserText += userText
                // Show user text immediately as a message
                let trimmed = currentUserText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                if !trimmed.isEmpty {
                    // Update or append the live user message
                    if let lastIndex = messages.indices.last, messages[lastIndex].isUser {
                        messages[lastIndex] = MemorizeInteractMessage(isUser: true, text: trimmed)
                    } else {
                        messages.append(MemorizeInteractMessage(isUser: true, text: trimmed))
                    }
                }

                // Detect voice commands to advance step
                let lower = userText.lowercased()
                if lower.contains("next section") || lower.contains("next step")
                    || lower.contains("move on") || lower.contains("let's continue")
                    || (lower.trimmingCharacters(in: .whitespacesAndNewlines) == "next")
                    || (lower.trimmingCharacters(in: .whitespacesAndNewlines) == "continue") {
                    advanceToNextStep()
                }
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                if isTransitioning {
                    isTransitioning = false
                    transitionIsFinishing = false
                    transitionTask?.cancel()
                    transitionTask = nil
                }
                // Clear accumulated user text (already shown in real-time)
                currentUserText = ""
                isAIThinking = false
                if cleaned.hasPrefix(currentAIText) && cleaned.count > currentAIText.count {
                    currentAIText = cleaned
                } else if currentAIText.isEmpty || !cleaned.hasPrefix(currentAIText) {
                    if currentAIText.isEmpty {
                        currentAIText = cleaned
                    } else {
                        let needsSpace = !currentAIText.hasSuffix(" ") && !cleaned.hasPrefix(" ")
                        currentAIText += (needsSpace ? " " : "") + cleaned
                    }
                }
            }
        }

        service.onTranscriptDone = { (fullText: String) in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                guard !isTransitioning else { return }
                let trimmed = (fullText.isEmpty ? currentAIText : fullText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    messages.append(MemorizeInteractMessage(isUser: false, text: trimmed))
                }
                currentAIText = ""
                isAIThinking = false
            }
        }

        service.onSpeechStarted = { [service] in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                isAISpeaking = true
                let routeSupportsHandsFreeMic = service.supportsHandsFreeMicRoute()
                supportsHandsFreeMic = routeSupportsHandsFreeMic
                service.isMicMuted = routeSupportsHandsFreeMic ? isMuted : true
            }
        }

        service.onSpeechStopped = { [service] in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                isAISpeaking = false
                let routeSupportsHandsFreeMic = service.supportsHandsFreeMicRoute()
                supportsHandsFreeMic = routeSupportsHandsFreeMic
                service.isMicMuted = isMuted
            }
        }

        service.onError = { (errorText: String) in
            Task { @MainActor in
                guard sessionID == serviceSessionID else { return }
                errorMessage = errorText
                isAIThinking = false
                isTransitioning = false
                transitionIsFinishing = false
                isAISpeaking = false
                transitionTask?.cancel()
                transitionTask = nil
            }
        }

        geminiService = service
        service.connect()
    }

    private func promptForCurrentStep(isFinishing: Bool) -> String {
        if isFinishing {
            return """
            IMPORTANT: The tutoring session is now complete. Ignore everything you were previously saying.
            Give a final encouraging summary: key takeaways, what the student did well, areas to review, and suggest spaced repetition timing (tomorrow, 3 days, 1 week). Say goodbye warmly.
            """
        }

        let step = currentStep
        if step == .focus {
            return "Begin the tutoring session now. Greet the student warmly and start Step 1: Focus by asking your first question."
        }

        return """
        IMPORTANT: We are now moving to Step \(step.rawValue + 1): \(step.title). Completely stop your previous topic.
        \(stepInstruction(step))
        Start this step now. Do not reference or continue the previous step.
        """
    }

    private func stepInstruction(_ step: TutorStep) -> String {
        switch step {
        case .focus: return "Ask the student what they're studying, why it matters, and how confident they feel."
        case .preview: return "Give a quick overview of the material — key concepts and vocabulary."
        case .learn: return "Present ONE concept from the material with a clear explanation and example."
        case .explain: return "Ask the student to explain what they just learned in their own words."
        case .recall: return "Test the student's memory — ask specific questions without letting them see notes."
        case .teach: return "Challenge the student to teach the concept as if explaining to a friend."
        case .review: return "Summarize takeaways, strengths, areas to review, and suggest spaced repetition timing."
        }
    }
}
