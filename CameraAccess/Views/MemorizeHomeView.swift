/*
 * Memorize Home View
 * Homepage for the Memorize feature - shows library and current reading
 */

import SwiftUI

struct MemorizeHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @StateObject private var viewModel = MemorizeHomeViewModel()
    @State private var showCapture = false
    @State private var selectedBook: Book?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Currently Reading Section
                    if let book = viewModel.currentBook {
                        currentlyReadingSection(book: book)
                    }

                    // Add to Library Section
                    addBookSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            viewModel.loadBooks()
        }
        .fullScreenCover(isPresented: $showCapture) {
            viewModel.loadBooks()
        } content: {
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: selectedBook
            )
        }
    }

    // MARK: - Currently Reading Section

    @ViewBuilder
    private func currentlyReadingSection(book: Book) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("memorize.currently_reading".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title.isEmpty ? "memorize.untitled".localized : book.title)
                            .font(AppTypography.title2)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(book.author.isEmpty ? "memorize.unknown_author".localized : book.author)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        viewModel.deleteBook(book.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }

                HStack(spacing: AppSpacing.sm) {
                    Label("\(book.completedPages)", systemImage: "doc.text.fill")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))

                    Text("memorize.pages_captured".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Button {
                    selectedBook = book
                    showCapture = true
                } label: {
                    Text("memorize.continue_session".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.memorizeAccent, AppColors.memorizeAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.md)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .stroke(AppColors.memorizeAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Add Book Section

    private var addBookSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("memorize.add_to_library".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Button {
                selectedBook = nil
                showCapture = true
            } label: {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color.white.opacity(0.4))

                    Text("memorize.add_new_book".localized)
                        .font(AppTypography.callout)
                        .foregroundColor(Color.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.clear)
                .cornerRadius(AppCornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .foregroundColor(Color.white.opacity(0.15))
                )
            }
        }
    }
}
