/*
 * Study Tab View
 * Shows the 7 study action buttons for a project
 */

import SwiftUI
import AVFoundation

struct StudyTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel

    @State private var showInteract = false
    @State private var showExplainPersonaSelector = false
    @State private var showExplain = false
    @State private var selectedPersona: MemorizeExplainPersona = .highSchoolStudent
    @State private var showVoiceSummary = false
    @State private var showInfographics = false

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
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                if !hasContent {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(Color.white.opacity(0.3))
                        Text("memorize.no_content_for_study".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    Text("memorize.study_prompt".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.lg)

                    // Interact
                    studyActionButton(
                        title: "memorize.interact".localized,
                        subtitle: "memorize.interact_subtitle".localized,
                        icon: "bubble.left.and.bubble.right.fill",
                        gradient: [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.1, green: 0.5, blue: 0.3)]
                    ) {
                        showInteract = true
                    }

                    // Explain
                    studyActionButton(
                        title: "memorize.explain".localized,
                        subtitle: "memorize.explain_subtitle".localized,
                        icon: "lightbulb.fill",
                        gradient: [Color.orange, Color.orange.opacity(0.7)]
                    ) {
                        showExplainPersonaSelector = true
                    }

                    // Podcast
                    studyActionButton(
                        title: "memorize.podcast".localized,
                        subtitle: "memorize.podcast_subtitle".localized,
                        icon: "waveform",
                        gradient: [Color(red: 0.64, green: 0.21, blue: 0.83), Color(red: 0.5, green: 0.15, blue: 0.7)]
                    ) {
                        viewModel.startPodcast()
                    }

                    // Infographics
                    studyActionButton(
                        title: "memorize.infographics".localized,
                        subtitle: "memorize.infographics_subtitle".localized,
                        icon: "chart.bar.doc.horizontal.fill",
                        gradient: [Color(red: 0.93, green: 0.35, blue: 0.47), Color(red: 0.80, green: 0.22, blue: 0.35)]
                    ) {
                        showInfographics = true
                    }

                    Text("memorize.test_mode_prompt".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    // Pop Quiz
                    studyActionButton(
                        title: "memorize.pop_quiz".localized,
                        subtitle: "memorize.pop_quiz_subtitle".localized,
                        icon: "questionmark.circle.fill",
                        gradient: [Color.blue, Color.cyan]
                    ) {
                        viewModel.generateQuiz()
                    }


                    if let error = viewModel.podcastErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
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
        .fullScreenCover(isPresented: $viewModel.showPodcastPlayer) {
            MemorizePodcastPlayerView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle,
                mode: viewModel.podcastMode,
                usesPDFLengthHeuristic: usesPDFLengthHeuristic
            ) {
                viewModel.showPodcastPlayer = false
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
        .fullScreenCover(isPresented: $showExplain) {
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
                """
            )
        }
        // Interact
        .fullScreenCover(isPresented: $showInteract) {
            MemorizeInteractView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
        }
        // Voice Summary
        .fullScreenCover(isPresented: $showVoiceSummary) {
            MemorizeVoiceSummaryView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
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
