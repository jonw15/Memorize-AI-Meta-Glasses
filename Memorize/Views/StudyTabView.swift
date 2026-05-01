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
            id: "find_mistake",
            title: "Find the Mistake",
            detail: "Spot · Correct",
            icon: "exclamationmark.magnifyingglass",
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

private struct StudyScopeOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let pages: [PageCapture]
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
    @State private var showPopQuizConfig = false
    @State private var presentedTutorMiniApp: TutorMiniAppKind?
    @State private var modeStartedAt: [GeneratedNoteKind: Date] = [:]
    @State private var selectedStudyScopeID = "whole"
    private let minimumNoteGenerationDuration: TimeInterval = 10

    private var completedPages: [PageCapture] {
        viewModel.allCompletedPages
    }

    private var studyScopeOptions: [StudyScopeOption] {
        var options = [
            StudyScopeOption(
                id: "whole",
                title: "Whole project",
                subtitle: "\(completedPages.count) page\(completedPages.count == 1 ? "" : "s")",
                pages: completedPages
            )
        ]

        let pageByID = Dictionary(uniqueKeysWithValues: completedPages.map { ($0.id, $0) })
        for topic in viewModel.book.aiTopics {
            let topicPages = topic.pageIDs.compactMap { pageByID[$0] }
            guard !topicPages.isEmpty else { continue }
            options.append(
                StudyScopeOption(
                    id: "topic-\(topic.id.uuidString)",
                    title: topic.title,
                    subtitle: "\(topicPages.count) page\(topicPages.count == 1 ? "" : "s")",
                    pages: topicPages
                )
            )
        }

        return options
    }

    private var selectedStudyScope: StudyScopeOption {
        studyScopeOptions.first { $0.id == selectedStudyScopeID } ?? studyScopeOptions[0]
    }

    private var scopedCompletedPages: [PageCapture] {
        selectedStudyScope.pages
    }

    private var bookTitle: String {
        viewModel.book.title
    }

    private var sectionTitle: String {
        selectedStudyScope.id == "whole" ? viewModel.book.chapter : selectedStudyScope.title
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

                    studyScopeSection

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
        // Pop quiz config
        .sheet(isPresented: $showPopQuizConfig) {
            PopQuizConfigSheet(scopeTitle: selectedStudyScope.title) { count, difficulty in
                viewModel.generateQuiz(
                    questionCount: count,
                    difficulty: difficulty,
                    from: scopedCompletedPages
                )
            }
            .presentationDetents([.height(440)])
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
                pages: scopedCompletedPages,
                bookTitle: bookTitle,
                sectionTitle: "\(selectedPersona.displayKey.localized) Summary · \(selectedStudyScope.title)",
                customSystemPrompt: """
                You are a friendly tutor. The student wants a summary of "\(selectedStudyScope.title)" from "\(bookTitle)":

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
                onClose: { presentedTutorMiniApp = nil },
                onSessionComplete: { title, body in
                    viewModel.saveTutorSessionSummary(title: title, body: body)
                }
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

    private var studyScopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Study scope")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(Color(hex: "535B54"))
                    .textCase(.uppercase)

                Spacer()

                if !viewModel.book.aiTopics.isEmpty {
                    regenerateTopicsButton
                }
            }

            if viewModel.isGeneratingStudyTopics {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(hex: "276B32"))
                    Text("Mastery is grouping your sources into topics…")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "535B54"))
                }
                .padding(.vertical, 6)
            } else if viewModel.book.aiTopics.isEmpty {
                Text("Topics will appear here once Mastery groups your sources.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(studyScopeOptions) { scope in
                            studyScopeChip(scope)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let error = viewModel.studyTopicsError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "B0444C"))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
        )
    }

    private var generateTopicsButton: some View {
        Button {
            viewModel.generateStudyTopics()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("Generate")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color(hex: "276B32"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingStudyTopics)
        .opacity(viewModel.isGeneratingStudyTopics ? 0.5 : 1)
    }

    private var regenerateTopicsButton: some View {
        Button {
            viewModel.generateStudyTopics()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                Text("Regenerate")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(hex: "276B32"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "D8F7D8"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingStudyTopics)
        .opacity(viewModel.isGeneratingStudyTopics ? 0.5 : 1)
    }

    private func studyScopeChip(_ scope: StudyScopeOption) -> some View {
        let selected = selectedStudyScope.id == scope.id
        return Button {
            selectedStudyScopeID = scope.id
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(scope.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? Color(hex: "1F2420") : Color(hex: "535B54"))
                    .lineLimit(1)

                Text(scope.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? Color(hex: "276B32") : Color(hex: "8D958E"))
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(minWidth: 128, alignment: .leading)
            .background(selected ? Color(hex: "D8F7D8") : Color(hex: "F6F0E7"))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? Color(hex: "6FC985") : Color(hex: "E8E1D8"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                tone: Color(hex: "AED9B1"),
                illustration: AnyView(SummaryIllustration()),
                action: { showExplainPersonaSelector = true }
            )

            learnCard(
                title: "Live",
                detail: "Camera · real-time",
                tone: Color(hex: "3F4FB8"),
                illustration: AnyView(LiveIllustration()),
                action: onShowLive
            )

            learnCard(
                title: "Pop quiz",
                detail: "6 cards · 4 min",
                tone: Color(hex: "EBA13A"),
                illustration: AnyView(PopQuizIllustration()),
                action: { showPopQuizConfig = true }
            )

            learnCard(
                title: "Podcast",
                detail: "Audio · 12 min",
                tone: Color(hex: "4E8FD0"),
                illustration: AnyView(PodcastIllustration()),
                action: { viewModel.startPodcast() }
            )
        }
    }

    private func learnCard(
        title: String,
        detail: String,
        tone: Color,
        illustration: AnyView,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    tone
                    illustration
                }
                .frame(height: 148)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))

                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "8D958E"))
                        Text(detail)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
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
                    tutorIllustration(for: method.id)
                }
                .frame(height: 130)

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

    @ViewBuilder
    fileprivate func tutorIllustration(for id: String) -> some View {
        switch id {
        case "feynman":
            FeynmanIllustration()
        case "mnemonics":
            MnemonicsIllustration()
        case "find_mistake":
            FindMistakeIllustration()
        case "cornell":
            CornellIllustration()
        default:
            Image(systemName: "sparkles")
                .font(.system(size: 38))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Card illustrations

private struct SummaryIllustration: View {
    var body: some View {
        ZStack {
            // Big speech bubble
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 86, weight: .regular))
                .foregroundColor(.white)
                .offset(x: -2, y: -6)

            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(Color(hex: "76A87B"))
                .offset(x: -6, y: -10)

            // Smaller dot bubble accessory
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(hex: "76A87B"))
            }
            .offset(x: 36, y: 26)
        }
    }
}

private struct LiveIllustration: View {
    var body: some View {
        ZStack {
            // Corner brackets framing
            CornerBrackets()
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 110, height: 80)

            // Two glasses lenses
            HStack(spacing: 8) {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 28, height: 28)
            }
            .offset(y: -2)

            // Red record dot
            Circle()
                .fill(Color(hex: "FF6C6C"))
                .frame(width: 9, height: 9)
                .offset(x: 50, y: -28)
        }
    }
}

private struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len: CGFloat = 14
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        return p
    }
}

private struct PopQuizIllustration: View {
    var body: some View {
        ZStack {
            // Paper card
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .frame(width: 76, height: 92)
                .rotationEffect(.degrees(-6))
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)

            // Lightning bolt on the card
            Image(systemName: "bolt.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color(hex: "EBA13A"))
                .rotationEffect(.degrees(-6))
        }
    }
}

private struct PodcastIllustration: View {
    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: 64, weight: .regular))
            .foregroundColor(.white)
    }
}

private struct FeynmanIllustration: View {
    var body: some View {
        ZStack {
            // Background ellipse glow
            Ellipse()
                .fill(Color.white.opacity(0.16))
                .frame(width: 110, height: 70)
                .offset(y: 18)

            // Big bubble
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 70, weight: .regular))
                .foregroundColor(.white)
                .offset(x: -2, y: -4)

            // Squiggle inside
            Image(systemName: "scribble.variable")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "9B3949"))
                .offset(x: -6, y: -10)

            // Small bubble accessory
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(hex: "9B3949"))
            }
            .offset(x: 32, y: 22)
        }
    }
}

private struct MnemonicsIllustration: View {
    var body: some View {
        ZStack {
            // Roof triangle
            Triangle()
                .fill(Color.white)
                .frame(width: 88, height: 36)
                .offset(y: -22)

            // House body
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 72, height: 50)
                .offset(y: 10)

            // Little colored landmarks inside (like memory palace items)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "EBA13A"))
                    .frame(width: 9, height: 9)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "4E8FD0"))
                    .frame(width: 10, height: 12)
                Circle()
                    .fill(Color(hex: "9B3949"))
                    .frame(width: 9, height: 9)
            }
            .offset(y: 10)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct FindMistakeIllustration: View {
    var body: some View {
        ZStack {
            // Brain
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundColor(.white)

            // Lightning bolt accent
            Image(systemName: "bolt.fill")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(Color(hex: "F2C84B"))
                .offset(x: 28, y: -22)
        }
    }
}

private struct CornellIllustration: View {
    var body: some View {
        ZStack {
            // Notebook page
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 70, height: 86)

            // Lines on the page
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(Color(hex: "C9BD7C"))
                        .frame(width: i % 2 == 0 ? 44 : 36, height: 3)
                }
            }
            .frame(width: 56, alignment: .leading)
        }
    }
}

private struct PopQuizConfigSheet: View {
    let scopeTitle: String
    let onGenerate: (Int, MemorizeService.QuizDifficulty) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var questionCount: Int = 6
    @State private var difficulty: MemorizeService.QuizDifficulty = .medium

    private let lengthOptions: [Int] = [3, 6, 10, 15]

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color(hex: "DED8CF"))
                .frame(width: 54, height: 5)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pop quiz")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "1F2420"))
                Text("Set the length and difficulty before generating.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
                Text("Scope: \(scopeTitle)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "276B32"))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)

            VStack(alignment: .leading, spacing: 10) {
                Text("LENGTH")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "8D958E"))
                HStack(spacing: 8) {
                    ForEach(lengthOptions, id: \.self) { count in
                        Button { questionCount = count } label: {
                            Text("\(count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(questionCount == count ? .white : Color(hex: "1F2420"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(questionCount == count ? Color(hex: "C99526") : Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(lengthHint)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
            }
            .padding(.horizontal, 22)

            VStack(alignment: .leading, spacing: 10) {
                Text("DIFFICULTY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "8D958E"))
                HStack(spacing: 8) {
                    difficultyChip(.easy, label: "Easy", color: Color(hex: "276B32"))
                    difficultyChip(.medium, label: "Medium", color: Color(hex: "C99526"))
                    difficultyChip(.hard, label: "Hard", color: Color(hex: "B0444C"))
                }
            }
            .padding(.horizontal, 22)

            Spacer()

            Button {
                onGenerate(questionCount, difficulty)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Generate quiz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "1F2420"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .background(Color(hex: "FCF7EF").ignoresSafeArea())
    }

    private var lengthHint: String {
        switch questionCount {
        case 3: return "Quick check — 3 questions, ~2 min."
        case 6: return "Standard pop quiz — 6 questions, ~4 min."
        case 10: return "Full review — 10 questions, ~7 min."
        case 15: return "Deep review — 15 questions, ~10 min."
        default: return "\(questionCount) questions"
        }
    }

    private func difficultyChip(_ value: MemorizeService.QuizDifficulty, label: String, color: Color) -> some View {
        let isOn = difficulty == value
        return Button { difficulty = value } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isOn ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isOn ? color : color.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
