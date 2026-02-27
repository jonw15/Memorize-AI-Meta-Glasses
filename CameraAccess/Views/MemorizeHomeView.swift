/*
 * Memorize Home View
 * Homepage for the Memorize feature - shows library and current reading
 */

import SwiftUI

struct MemorizeHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @StateObject private var viewModel = MemorizeHomeViewModel()
    @State private var showNewSessionForm = false
    @State private var selectedBook: Book?
    @State private var newSessionTitle: String = ""
    @State private var newSessionAuthor: String = ""

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
        .fullScreenCover(item: $selectedBook, onDismiss: {
            viewModel.loadBooks()
        }) { book in
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: book
            )
        }
        .sheet(isPresented: $showNewSessionForm) {
            newSessionSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
                newSessionTitle = ""
                newSessionAuthor = ""
                showNewSessionForm = true
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

    private var isNewSessionValid: Bool {
        !newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newSessionAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var newSessionSheet: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.enter_book_details".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: AppSpacing.sm) {
                    TextField("memorize.title_field".localized, text: $newSessionTitle)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 14)
                        .background(AppColors.memorizeCard)
                        .foregroundColor(.white)
                        .cornerRadius(AppCornerRadius.md)

                    TextField("memorize.author_field".localized, text: $newSessionAuthor)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 14)
                        .background(AppColors.memorizeCard)
                        .foregroundColor(.white)
                        .cornerRadius(AppCornerRadius.md)
                }

                Button {
                    selectedBook = Book(
                        title: newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        author: newSessionAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    showNewSessionForm = false
                } label: {
                    Text("memorize.start_session".localized)
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
                .disabled(!isNewSessionValid)
                .opacity(isNewSessionValid ? 1 : 0.5)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.new_session".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.cancel".localized) {
                        showNewSessionForm = false
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
