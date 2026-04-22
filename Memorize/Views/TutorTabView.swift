/*
 * Tutor Tab View
 * Interactive AI-guided voice study session with selectable learning methods
 * Uses GeminiLiveService for real-time voice conversation
 */

import SwiftUI
import AVFoundation

// MARK: - Learning Methods

struct TutorSessionStep: Identifiable, Equatable {
    let id: Int
    let titleKey: String
    let promptTitle: String
    let icon: String
    let descriptionKey: String
    let instruction: String

    var title: String { titleKey.localized }
    var description: String { descriptionKey.localized }
}

enum TutorLearningMethod: String, CaseIterable, Identifiable {
    case guidedStudy
    case explainIt
    case testMe
    case repeatReinforce

    var id: String { rawValue }

    var title: String { titleKey.localized }
    var subtitle: String { subtitleKey.localized }
    var goal: String { goalKey.localized }

    private var titleKey: String {
        switch self {
        case .guidedStudy: return "memorize.tutor.method.guided.title"
        case .explainIt: return "memorize.tutor.method.explain.title"
        case .testMe: return "memorize.tutor.method.test.title"
        case .repeatReinforce: return "memorize.tutor.method.repeat.title"
        }
    }

    private var subtitleKey: String {
        switch self {
        case .guidedStudy: return "memorize.tutor.method.guided.subtitle"
        case .explainIt: return "memorize.tutor.method.explain.subtitle"
        case .testMe: return "memorize.tutor.method.test.subtitle"
        case .repeatReinforce: return "memorize.tutor.method.repeat.subtitle"
        }
    }

    private var goalKey: String {
        switch self {
        case .guidedStudy: return "memorize.tutor.method.guided.goal"
        case .explainIt: return "memorize.tutor.method.explain.goal"
        case .testMe: return "memorize.tutor.method.test.goal"
        case .repeatReinforce: return "memorize.tutor.method.repeat.goal"
        }
    }

    var promptName: String {
        switch self {
        case .guidedStudy: return "Guided Study"
        case .explainIt: return "Feynman Technique, also called Explain It Mode"
        case .testMe: return "Active Recall, also called Test Me Mode"
        case .repeatReinforce: return "Single-session Spaced Repetition, also called Repeat & Reinforce Mode"
        }
    }

    var promptGoal: String {
        switch self {
        case .guidedStudy:
            return "Build understanding with a complete guided study flow."
        case .explainIt:
            return "Help the student understand by explaining clearly, finding gaps, reviewing them, and explaining again."
        case .testMe:
            return "Strengthen memory by making the student retrieve answers from memory before checking or correcting."
        case .repeatReinforce:
            return "Improve retention inside one session by alternating study, recall, correction, a different task, and delayed recall."
        }
    }

    var icon: String {
        switch self {
        case .guidedStudy: return "graduationcap.fill"
        case .explainIt: return "text.bubble.fill"
        case .testMe: return "brain.head.profile"
        case .repeatReinforce: return "repeat.circle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .guidedStudy: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .explainIt: return Color(hex: "36D1DC")
        case .testMe: return Color(hex: "4A7BF7")
        case .repeatReinforce: return Color(hex: "00C853")
        }
    }

    var steps: [TutorSessionStep] {
        switch self {
        case .guidedStudy:
            return [
                TutorSessionStep(
                    id: 0,
                    titleKey: "memorize.tutor.step.focus.title",
                    promptTitle: "Focus",
                    icon: "target",
                    descriptionKey: "memorize.tutor.step.focus.desc",
                    instruction: "Ask the student one question at a time: what they are studying today, why it matters to them, and how confident they feel from 1 to 10. Get them mentally ready."
                ),
                TutorSessionStep(
                    id: 1,
                    titleKey: "memorize.tutor.step.preview.title",
                    promptTitle: "Preview",
                    icon: "map",
                    descriptionKey: "memorize.tutor.step.preview.desc",
                    instruction: "Give a quick overview of the material: the main topic, 3-5 key concepts, and important vocabulary. Make it scannable."
                ),
                TutorSessionStep(
                    id: 2,
                    titleKey: "memorize.tutor.step.learn.title",
                    promptTitle: "Learn",
                    icon: "book.fill",
                    descriptionKey: "memorize.tutor.step.learn.desc",
                    instruction: "Present one concept from the material at a time with a short summary and a concrete example or analogy. Ask if they understand before continuing."
                ),
                TutorSessionStep(
                    id: 3,
                    titleKey: "memorize.tutor.step.explain.title",
                    promptTitle: "Explain",
                    icon: "text.bubble.fill",
                    descriptionKey: "memorize.tutor.step.explain.desc",
                    instruction: "Ask the student to explain what they just learned in their own words. Give feedback on what was good and what they missed."
                ),
                TutorSessionStep(
                    id: 4,
                    titleKey: "memorize.tutor.step.recall.title",
                    promptTitle: "Recall",
                    icon: "brain.head.profile",
                    descriptionKey: "memorize.tutor.step.recall.desc",
                    instruction: "Hide the notes. Ask specific memory questions such as main ideas or definitions. Give feedback after each answer."
                ),
                TutorSessionStep(
                    id: 5,
                    titleKey: "memorize.tutor.step.teach.title",
                    promptTitle: "Teach",
                    icon: "person.2.fill",
                    descriptionKey: "memorize.tutor.step.teach.desc",
                    instruction: "Challenge the student to teach the concept as if explaining to a friend or a 10-year-old. Evaluate clarity, accuracy, and simplicity."
                ),
                TutorSessionStep(
                    id: 6,
                    titleKey: "memorize.tutor.step.review.title",
                    promptTitle: "Review",
                    icon: "checkmark.circle.fill",
                    descriptionKey: "memorize.tutor.step.review.desc",
                    instruction: "Summarize key takeaways, what the student did well, areas to review, and suggest spaced repetition timing."
                )
            ]
        case .explainIt:
            return [
                TutorSessionStep(
                    id: 0,
                    titleKey: "memorize.tutor.step.choose_concept.title",
                    promptTitle: "Choose a Concept",
                    icon: "target",
                    descriptionKey: "memorize.tutor.step.choose_concept.desc",
                    instruction: "Help the student choose one concept from the source material to learn. If they are unsure, suggest 2-3 strong options from the source and ask them to pick one."
                ),
                TutorSessionStep(
                    id: 1,
                    titleKey: "memorize.tutor.step.simple_explain.title",
                    promptTitle: "Simple Explanation",
                    icon: "quote.bubble.fill",
                    descriptionKey: "memorize.tutor.step.simple_explain.desc",
                    instruction: "Ask the student to explain the chosen concept in simple terms, as if speaking to someone new to the topic. Do not lecture first unless they are stuck."
                ),
                TutorSessionStep(
                    id: 2,
                    titleKey: "memorize.tutor.step.find_gaps.title",
                    promptTitle: "Find Gaps",
                    icon: "questionmark.circle.fill",
                    descriptionKey: "memorize.tutor.step.find_gaps.desc",
                    instruction: "Identify the parts of the student's explanation that are unclear, missing, too vague, or hard for them to explain. Name the gaps kindly and specifically."
                ),
                TutorSessionStep(
                    id: 3,
                    titleKey: "memorize.tutor.step.review_gaps.title",
                    promptTitle: "Review Gaps",
                    icon: "magnifyingglass",
                    descriptionKey: "memorize.tutor.step.review_gaps.desc",
                    instruction: "Review the unclear parts using the source material. Give short explanations, examples, and checks for understanding."
                ),
                TutorSessionStep(
                    id: 4,
                    titleKey: "memorize.tutor.step.explain_again.title",
                    promptTitle: "Explain Again",
                    icon: "arrow.clockwise.circle.fill",
                    descriptionKey: "memorize.tutor.step.explain_again.desc",
                    instruction: "Ask the student to explain the same concept again more clearly. Compare it to their first attempt and reinforce the improvement."
                ),
                TutorSessionStep(
                    id: 5,
                    titleKey: "memorize.tutor.step.one_sentence.title",
                    promptTitle: "One-Sentence Summary",
                    icon: "textformat.size",
                    descriptionKey: "memorize.tutor.step.one_sentence.desc",
                    instruction: "Ask the student to summarize the concept in one sentence. Help them compress the idea without losing accuracy."
                ),
                TutorSessionStep(
                    id: 6,
                    titleKey: "memorize.tutor.step.real_example.title",
                    promptTitle: "Real-World Example",
                    icon: "lightbulb.fill",
                    descriptionKey: "memorize.tutor.step.real_example.desc",
                    instruction: "Ask for or provide a real-world example that shows the concept in action. Check that the example actually fits the concept."
                )
            ]
        case .testMe:
            return [
                TutorSessionStep(
                    id: 0,
                    titleKey: "memorize.tutor.step.read_once.title",
                    promptTitle: "Read Once",
                    icon: "doc.text.fill",
                    descriptionKey: "memorize.tutor.step.read_once.desc",
                    instruction: "Give the student a brief, focused reading pass over the most important source material. Tell them this is their only look before recall."
                ),
                TutorSessionStep(
                    id: 1,
                    titleKey: "memorize.tutor.step.hide_material.title",
                    promptTitle: "Hide the Material",
                    icon: "eye.slash.fill",
                    descriptionKey: "memorize.tutor.step.hide_material.desc",
                    instruction: "Tell the student to stop looking at the material. Set the rule that answers should come from memory, even if imperfect."
                ),
                TutorSessionStep(
                    id: 2,
                    titleKey: "memorize.tutor.step.memory_questions.title",
                    promptTitle: "Memory Questions",
                    icon: "questionmark.bubble.fill",
                    descriptionKey: "memorize.tutor.step.memory_questions.desc",
                    instruction: "Ask specific questions from the material one at a time. Require the student to answer from memory before you reveal anything."
                ),
                TutorSessionStep(
                    id: 3,
                    titleKey: "memorize.tutor.step.check_answers.title",
                    promptTitle: "Check Answers",
                    icon: "checkmark.seal.fill",
                    descriptionKey: "memorize.tutor.step.check_answers.desc",
                    instruction: "Check the student's answers against the source material. Mark what is correct, incomplete, or incorrect."
                ),
                TutorSessionStep(
                    id: 4,
                    titleKey: "memorize.tutor.step.correct_mistakes.title",
                    promptTitle: "Correct Mistakes",
                    icon: "pencil.and.outline",
                    descriptionKey: "memorize.tutor.step.correct_mistakes.desc",
                    instruction: "Correct mistakes clearly and briefly. Explain why the correction is right, then ask the student to restate the corrected answer."
                ),
                TutorSessionStep(
                    id: 5,
                    titleKey: "memorize.tutor.step.retry_memory.title",
                    promptTitle: "Retry From Memory",
                    icon: "arrow.uturn.backward.circle.fill",
                    descriptionKey: "memorize.tutor.step.retry_memory.desc",
                    instruction: "Ask the same missed or weak questions again from memory. Do not accept vague answers; coach toward accurate retrieval."
                ),
                TutorSessionStep(
                    id: 6,
                    titleKey: "memorize.tutor.step.mastery_loop.title",
                    promptTitle: "Mastery Loop",
                    icon: "flag.checkered",
                    descriptionKey: "memorize.tutor.step.mastery_loop.desc",
                    instruction: "Repeat the question, answer, check, and correction cycle until the student can answer everything correctly. End with a concise mastery summary."
                )
            ]
        case .repeatReinforce:
            return [
                TutorSessionStep(
                    id: 0,
                    titleKey: "memorize.tutor.step.brief_study.title",
                    promptTitle: "Brief Study",
                    icon: "timer",
                    descriptionKey: "memorize.tutor.step.brief_study.desc",
                    instruction: "Guide the student through a brief study pass on one concept. Keep it short and focused."
                ),
                TutorSessionStep(
                    id: 1,
                    titleKey: "memorize.tutor.step.first_recall.title",
                    promptTitle: "First Recall",
                    icon: "brain.head.profile",
                    descriptionKey: "memorize.tutor.step.first_recall.desc",
                    instruction: "Ask the student to recall the concept from memory immediately. Let them struggle productively before helping."
                ),
                TutorSessionStep(
                    id: 2,
                    titleKey: "memorize.tutor.step.first_correct.title",
                    promptTitle: "Check and Correct",
                    icon: "checkmark.circle.fill",
                    descriptionKey: "memorize.tutor.step.first_correct.desc",
                    instruction: "Check the recalled answer and correct it using the source material. Make the correction simple enough to remember."
                ),
                TutorSessionStep(
                    id: 3,
                    titleKey: "memorize.tutor.step.switch_topic.title",
                    promptTitle: "Switch Topics",
                    icon: "shuffle",
                    descriptionKey: "memorize.tutor.step.switch_topic.desc",
                    instruction: "Switch to a different topic, micro-task, or related concept for a short interval so the original concept leaves working memory."
                ),
                TutorSessionStep(
                    id: 4,
                    titleKey: "memorize.tutor.step.return_recall.title",
                    promptTitle: "Return and Recall",
                    icon: "arrowshape.turn.up.backward.fill",
                    descriptionKey: "memorize.tutor.step.return_recall.desc",
                    instruction: "Return to the original concept and ask the student to recall it again from memory. Compare this recall with the first attempt."
                ),
                TutorSessionStep(
                    id: 5,
                    titleKey: "memorize.tutor.step.second_correct.title",
                    promptTitle: "Correct Again",
                    icon: "wrench.adjustable.fill",
                    descriptionKey: "memorize.tutor.step.second_correct.desc",
                    instruction: "Check and correct the second recall. Emphasize what improved and what still needs reinforcement."
                ),
                TutorSessionStep(
                    id: 6,
                    titleKey: "memorize.tutor.step.repeat_cycle.title",
                    promptTitle: "Repeat Cycle",
                    icon: "repeat.circle.fill",
                    descriptionKey: "memorize.tutor.step.repeat_cycle.desc",
                    instruction: "Repeat the cycle multiple times: brief review, recall, correction, switch away, return, and recall again. End with a retention-focused summary."
                )
            ]
        }
    }

    var stepInstructionsForPrompt: String {
        steps
            .map { "\($0.id + 1). \($0.promptTitle.uppercased()): \($0.instruction)" }
            .joined(separator: "\n")
    }
}

// MARK: - Tutor Tab View

struct TutorTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel

    @State private var selectedMethod: TutorLearningMethod = .guidedStudy
    @State private var currentStepIndex = 0
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

    private var tutorAccent: Color { selectedMethod.accent }

    private var currentSteps: [TutorSessionStep] {
        selectedMethod.steps
    }

    private var currentStep: TutorSessionStep {
        currentSteps[min(currentStepIndex, max(currentSteps.count - 1, 0))]
    }

    private var isLastStep: Bool {
        currentStepIndex >= currentSteps.count - 1
    }

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
            .navigationTitle("memorize.tutor.title".localized)
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
                            Text("memorize.tutor.end".localized)
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
            Text("memorize.tutor.no_content".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Session Start

    private var sessionStartView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: selectedMethod.icon)
                            .font(.system(size: 48))
                            .foregroundColor(tutorAccent)

                        Text("memorize.tutor.title".localized)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("memorize.tutor.subtitle".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                    .padding(.top, AppSpacing.xl)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("memorize.tutor.choose_method".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.md)

                        VStack(spacing: AppSpacing.sm) {
                            ForEach(TutorLearningMethod.allCases) { method in
                                methodSelectionCard(method)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("memorize.tutor.session_steps".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.md)

                        VStack(spacing: AppSpacing.xs) {
                            ForEach(currentSteps) { step in
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
                        .cornerRadius(AppCornerRadius.sm)
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.bottom, AppSpacing.lg)
            }

            Button {
                currentStepIndex = 0
                hasStartedSession = true
                setupAndConnect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("memorize.tutor.start_session".localized)
                        .font(AppTypography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tutorAccent)
                .cornerRadius(AppCornerRadius.sm)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private func methodSelectionCard(_ method: TutorLearningMethod) -> some View {
        let isSelected = method == selectedMethod

        return Button {
            selectedMethod = method
            currentStepIndex = 0
        } label: {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(method.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                    Text(method.subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text(method.goal)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.38))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? method.accent : Color.white.opacity(0.25))
            }
            .padding(AppSpacing.md)
            .background(isSelected ? method.accent.opacity(0.16) : AppColors.memorizeCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .stroke(isSelected ? method.accent.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(AppCornerRadius.sm)
        }
        .buttonStyle(.plain)
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
                            Text(isConnected ? "memorize.tutor.preparing".localized : "memorize.tutor.connecting".localized)
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
                        Text(isMuted ? "memorize.tutor.unmute".localized : "memorize.tutor.mute".localized)
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
                        Image(systemName: isLastStep ? "checkmark" : "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text(isLastStep ? "memorize.tutor.finish".localized : "memorize.tutor.next".localized)
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
            ForEach(currentSteps) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(stepColor(step))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func stepColor(_ step: TutorSessionStep) -> Color {
        if step.id < currentStepIndex {
            return Color.green
        } else if step.id == currentStepIndex {
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
            Text("memorize.tutor.thinking".localized)
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

        let next = currentStepIndex + 1
        let isFinishing = next >= currentSteps.count

        if !isFinishing {
            currentStepIndex = next
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
        currentStepIndex = 0
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

        LEARNING METHOD:
        \(selectedMethod.promptName)

        METHOD GOAL:
        \(selectedMethod.promptGoal)

        You will guide them through \(currentSteps.count) steps. You are currently on Step 1: \(currentSteps[0].promptTitle).

        STEP INSTRUCTIONS:
        \(selectedMethod.stepInstructionsForPrompt)

        RULES:
        - Keep responses concise — 2-4 sentences for voice. This is a conversation, not a lecture.
        - Wait for the student to respond before moving on.
        - Be encouraging but honest about mistakes.
        - When the student says "next" or "continue", move to the next step in the selected method.
        - Reference specific content from the source material.
        - Do not mix in steps from other learning methods unless the student explicitly asks to change methods.
        - Speak naturally as if you're sitting across from them.

        Start now with Step 1: \(currentSteps[0].promptTitle). Greet the student warmly and ask your first question.
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
            Give a final encouraging summary for \(selectedMethod.promptName): key takeaways, what the student did well, areas to review, and one concrete next study action. Say goodbye warmly.
            """
        }

        let step = currentStep
        if currentStepIndex == 0 {
            return "Begin the tutoring session now. Greet the student warmly and start Step 1: \(step.promptTitle) by asking your first question. Follow this instruction: \(step.instruction)"
        }

        return """
        IMPORTANT: We are now moving to Step \(currentStepIndex + 1): \(step.promptTitle). Completely stop your previous topic.
        \(step.instruction)
        Start this step now. Do not reference or continue the previous step.
        """
    }
}
