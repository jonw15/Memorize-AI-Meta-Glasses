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
                        gradient: [Color.pink, Color.pink.opacity(0.7)]
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

                    // Voice Summary
                    studyActionButton(
                        title: "memorize.voice_summary".localized,
                        subtitle: "memorize.voice_summary_subtitle".localized,
                        icon: "mic.fill",
                        gradient: [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.5, blue: 0.8)]
                    ) {
                        showVoiceSummary = true
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
        // Explain persona selector → opens Interact with persona prompt
        .sheet(isPresented: $showExplainPersonaSelector) {
            ExplainPersonaPickerView { persona in
                showExplainPersonaSelector = false
                showInteract = true
            }
            .presentationDetents([.medium])
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
                sectionTitle: sectionTitle
            )
        }
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
