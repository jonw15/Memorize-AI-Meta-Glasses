/*
 * Book Sections View
 * Shows chapters/sections within a parent book for selection
 */

import SwiftUI

struct BookSectionsView: View {
    let parentBook: Book
    @ObservedObject var streamViewModel: StreamSessionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Book?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(parentBook.title.isEmpty ? "memorize.untitled".localized : parentBook.title)
                        .font(AppTypography.largeTitle)
                        .foregroundColor(.white)

                    if !parentBook.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(parentBook.author)
                            .font(AppTypography.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text(String(format: "memorize.sections_count".localized, parentBook.sections.count))
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

                // Chapters list
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(parentBook.sections.enumerated()), id: \.element.id) { index, section in
                            sectionCard(section: section, index: index)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("memorize.back".localized)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedSection) { section in
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: section
            )
        }
    }

    private func sectionCard(section: Book, index: Int) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Chapter number
                Text("\(index + 1)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.memorizeAccent)
                    .frame(width: 40, height: 40)
                    .background(AppColors.memorizeAccent.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.chapter.isEmpty ? "memorize.untitled".localized : section.chapter)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(String(format: "memorize.section_pages".localized, section.completedPages))
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .stroke(AppColors.memorizeAccent.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
