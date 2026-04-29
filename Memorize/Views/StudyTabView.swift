/*
 * Study Tab View
 * Shows the 7 study action buttons for a project
 */

import SwiftUI
import AVFoundation

struct TutorMethodCard: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tone: Color

    static let all: [TutorMethodCard] = [
        TutorMethodCard(
            id: "feynman",
            title: "Feynman Technique",
            detail: "5 min · Teach back",
            icon: "text.bubble.fill",
            tone: Color(hex: "9B3949")
        ),
        TutorMethodCard(
            id: "mnemonics",
            title: "Mnemonics",
            detail: "Visual · Story",
            icon: "house.fill",
            tone: Color(hex: "6A4F8E")
        ),
        TutorMethodCard(
            id: "active_recall",
            title: "Active Recall",
            detail: "8 prompts · Retrieve",
            icon: "brain.head.profile",
            tone: Color(hex: "2E5C3A")
        ),
        TutorMethodCard(
            id: "cornell",
            title: "Cornell Method",
            detail: "3 steps · Notes",
            icon: "note.text",
            tone: Color(hex: "8C7E3A")
        )
    ]
}

struct StudyTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    let onShowSources: () -> Void
    let onShowLive: () -> Void
    let onShowTutor: () -> Void
    let onModeFinished: (GeneratedNoteKind) -> Void

    init(
        viewModel: ProjectDetailViewModel,
        onShowSources: @escaping () -> Void = {},
        onShowLive: @escaping () -> Void = {},
        onShowTutor: @escaping () -> Void = {},
        onModeFinished: @escaping (GeneratedNoteKind) -> Void = { _ in }
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onShowSources = onShowSources
        self.onShowLive = onShowLive
        self.onShowTutor = onShowTutor
        self.onModeFinished = onModeFinished
    }

    @State private var showInteract = false
    @State private var showExplainPersonaSelector = false
    @State private var showExplain = false
    @State private var selectedPersona: MemorizeExplainPersona = .highSchoolStudent
    @State private var showVoiceSummary = false
    @State private var showInfographics = false
    @State private var presentedTutorMiniApp: TutorMiniAppKind?
    @State private var modeStartedAt: [GeneratedNoteKind: Date] = [:]
    private let minimumNoteGenerationDuration: TimeInterval = 10

    private var completedPages: [PageCapture] {
        viewModel.allCompletedPages
    }

    private var bookTitle: String {
        viewModel.book.title
    }

    private var sectionTitle: String {
        viewModel.book.chapter
    }

    private var hasContent: Bool {
        !completedPages.isEmpty
    }

    private var usesPDFLengthHeuristic: Bool {
        viewModel.book.sources.contains(where: { $0.sourceType == .pdf })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                learnHeader

                if !hasContent {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "8D958E"))
                        Text("memorize.no_content_for_study".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color(hex: "6E776F"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    Text("Study with Mastery")
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundColor(Color(hex: "1F2420"))

                    learnCardGrid

                    tutorSection

                    if let error = viewModel.podcastErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(Color(hex: "FCF7EF"))
        .overlay {
            if viewModel.isGeneratingQuiz {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("memorize.quiz_generating".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(AppColors.memorizeCard)
                    .cornerRadius(AppCornerRadius.lg)
                }
            }
        }
        // Quiz
        .fullScreenCover(isPresented: $viewModel.showQuiz) {
            MemorizeQuizView(questions: $viewModel.quizQuestions)
        }
        // Podcast mode picker
        .sheet(isPresented: $viewModel.showPodcastModePicker) {
            PodcastModePickerView { mode in
                viewModel.startPodcastWithMode(mode)
            }
            .presentationDetents([.height(280)])
        }
        // Podcast player
        .fullScreenCover(isPresented: $viewModel.showPodcastPlayer, onDismiss: {
            finishTrackedMode(.podcast)
        }) {
            MemorizePodcastPlayerView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle,
                mode: viewModel.podcastMode,
                usesPDFLengthHeuristic: usesPDFLengthHeuristic
            ) {
                viewModel.showPodcastPlayer = false
            }
            .onAppear {
                startTrackedMode(.podcast)
            }
        }
        // Explain persona selector
        .sheet(isPresented: $showExplainPersonaSelector) {
            ExplainPersonaPickerView { persona in
                selectedPersona = persona
                showExplainPersonaSelector = false
                showExplain = true
            }
            .presentationDetents([.medium])
        }
        // Summary view — AI immediately summarizes as selected persona
        .fullScreenCover(isPresented: $showExplain, onDismiss: {
            finishTrackedMode(.explain)
        }) {
            MemorizeInteractView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: "\(selectedPersona.displayKey.localized) Summary",
                customSystemPrompt: """
                You are a friendly tutor. The student wants a summary of the following material from "\(bookTitle)":

                ---
                {{SOURCE_CONTEXT}}
                ---

                Summarize this material as if you are explaining it to \(selectedPersona.promptInstruction).

                IMPORTANT: Start immediately with the summary. Do NOT ask any questions first. Do NOT greet the student. Just begin summarizing the key points right away in a clear, engaging way.

                After you finish the summary, you can answer any follow-up questions the student has.
                Keep your language conversational and easy to understand.
                """,
                onSessionCaptured: { messages in
                    viewModel.captureSessionMessages(messages, for: .explain)
                }
            )
            .onAppear {
                startTrackedMode(.explain)
            }
        }
        // Interact
        .fullScreenCover(isPresented: $showInteract, onDismiss: {
            finishTrackedMode(.interact)
        }) {
            MemorizeInteractView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle,
                onSessionCaptured: { messages in
                    viewModel.captureSessionMessages(messages, for: .interact)
                }
            )
            .onAppear {
                startTrackedMode(.interact)
            }
        }
        // Voice Summary
        .fullScreenCover(isPresented: $showVoiceSummary, onDismiss: {
            finishTrackedMode(.voiceSummary)
        }) {
            MemorizeVoiceSummaryView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
            .onAppear {
                startTrackedMode(.voiceSummary)
            }
        }
        // Infographics
        .fullScreenCover(isPresented: $showInfographics) {
            MemorizeInfographicsView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle,
                sourceBundles: infographicSourceBundles
            )
        }
        // Tutor mini apps
        .fullScreenCover(item: $presentedTutorMiniApp) { kind in
            TutorMiniAppView(
                kind: kind,
                book: viewModel.book,
                onClose: { presentedTutorMiniApp = nil }
            )
        }
    }

    private var learnHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(projectEyebrow)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(Color(hex: "8D958E"))
                    .lineLimit(2)

                Spacer()

                Button(action: onShowSources) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "2F6A83"))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "E8F3F1"))
                            .clipShape(Circle())

                        Text("memorize.sources".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "1F2420"))

                        Text("\(viewModel.book.sourceCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color(hex: "1F2420"))
                            .clipShape(Circle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "E8E0D7"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Learn")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: "1F2420"))
        }
    }

    private var projectEyebrow: String {
        let title = viewModel.book.title.isEmpty ? "memorize.untitled".localized : viewModel.book.title
        return title.uppercased()
    }

    private var learnCardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            learnCard(
                title: "Summary",
                detail: "Voice chat · grounded",
                icon: "message.fill",
                accessoryIcon: "ellipsis",
                tone: Color(hex: "AED9B1"),
                action: { showExplainPersonaSelector = true }
            )

            learnCard(
                title: "Live",
                detail: "Glasses · real-time",
                icon: "eyeglasses",
                accessoryIcon: "record.circle",
                tone: Color(hex: "4146C5"),
                action: onShowLive
            )

            learnCard(
                title: "Pop quiz",
                detail: "6 cards · 4 min",
                icon: "bolt.fill",
                accessoryIcon: nil,
                tone: Color(hex: "F5A92D"),
                action: { viewModel.generateQuiz() }
            )

            learnCard(
                title: "Podcast",
                detail: "Audio · 12 min",
                icon: "headphones",
                accessoryIcon: nil,
                tone: Color(hex: "4E8FD0"),
                action: { viewModel.startPodcast() }
            )
        }
    }

    private func learnCard(
        title: String,
        detail: String,
        icon: String,
        accessoryIcon: String?,
        tone: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    tone
                    Image(systemName: icon)
                        .font(.system(size: icon == "headphones" ? 60 : 54, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))

                    if let accessoryIcon {
                        Image(systemName: accessoryIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(accessoryIcon == "record.circle" ? Color(hex: "FF6C6C") : .white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(24)
                    }
                }
                .frame(height: 148)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))

                    Text(detail)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!hasContent || viewModel.isGeneratingQuiz || viewModel.isGeneratingExplanation)
        .opacity(hasContent ? 1 : 0.45)
    }

    private var tutorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Learn with a tutor")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "1F2420"))

                Text("Six proven techniques. Pick one and Mastery runs the session.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            tutorCardGrid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tutorCardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(TutorMethodCard.all) { method in
                tutorCard(method)
            }
        }
    }

    private func tutorCard(_ method: TutorMethodCard) -> some View {
        Button(action: {
            if let kind = TutorMiniAppKind.fromCardId(method.id) {
                presentedTutorMiniApp = kind
            } else {
                onShowTutor()
            }
        }) {
            VStack(spacing: 0) {
                ZStack {
                    method.tone
                    Image(systemName: method.icon)
                        .font(.system(size: 38, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))
                }
                .frame(height: 120)

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "8D958E"))
                        Text(method.detail)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!hasContent)
        .opacity(hasContent ? 1 : 0.45)
    }

    private func startTrackedMode(_ mode: GeneratedNoteKind) {
        modeStartedAt[mode] = Date()
    }

    private func finishTrackedMode(_ mode: GeneratedNoteKind) {
        defer { modeStartedAt[mode] = nil }

        guard let start = modeStartedAt[mode],
              Date().timeIntervalSince(start) >= minimumNoteGenerationDuration else {
            viewModel.clearSessionCapture(for: mode)
            return
        }

        onModeFinished(mode)
    }

    private var infographicSourceBundles: [InfographicSourceBundle] {
        var bundles: [InfographicSourceBundle] = []

        let legacyPages = viewModel.book.pages.filter { $0.status == .completed }
        if !legacyPages.isEmpty {
            bundles.append(
                InfographicSourceBundle(
                    title: "memorize.source_camera".localized,
                    pages: legacyPages
                )
            )
        }

        for source in viewModel.book.sources {
            let completed = source.pages.filter { $0.status == .completed }
            guard !completed.isEmpty else { continue }
            bundles.append(InfographicSourceBundle(title: source.name, pages: completed))
        }

        if bundles.isEmpty && !completedPages.isEmpty {
            bundles.append(
                InfographicSourceBundle(
                    title: "memorize.sources".localized,
                    pages: completedPages
                )
            )
        }

        return bundles
    }

    private func studyActionButton(title: String, subtitle: String, icon: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.lg)
        }
        .disabled(!hasContent || viewModel.isGeneratingQuiz || viewModel.isGeneratingExplanation)
        .opacity(hasContent ? 1.0 : 0.5)
    }
}
