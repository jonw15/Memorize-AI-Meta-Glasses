/*
 * Memorize Quiz View
 * Interactive multiple-choice quiz generated from captured book pages
 */

import SwiftUI

struct MemorizeQuizView: View {
    @Binding var questions: [QuizQuestion]
    @Environment(\.dismiss) private var dismiss

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

            // Question card
            Text(question.question)
                .font(AppTypography.title)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(AppColors.memorizeCard)
                .cornerRadius(AppCornerRadius.md)
                .padding(.horizontal, AppSpacing.md)

            // Answer options
            VStack(spacing: AppSpacing.sm) {
                ForEach(0..<question.options.count, id: \.self) { index in
                    optionRow(index: index, question: question)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            Spacer()

            // Next / See Results button
            if question.selectedIndex != nil {
                Button {
                    if currentIndex < questions.count - 1 {
                        withAnimation {
                            currentIndex += 1
                        }
                    } else {
                        withAnimation {
                            showResults = true
                        }
                    }
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
            guard question.selectedIndex == nil else { return }
            questions[currentIndex].selectedIndex = index
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

                Spacer()

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
}
