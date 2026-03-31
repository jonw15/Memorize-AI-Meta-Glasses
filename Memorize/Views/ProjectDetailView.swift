/*
 * Project Detail View
 * Container with Sources and Study bottom tabs for a single project
 */

import SwiftUI

struct ProjectDetailView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProjectTab = .sources

    enum ProjectTab {
        case sources, study
    }

    init(book: Book, streamViewModel: StreamSessionViewModel) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: ProjectDetailViewModel(book: book))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content
                switch selectedTab {
                case .sources:
                    SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
                case .study:
                    StudyTabView(viewModel: viewModel)
                }

                // Bottom tab bar
                bottomTabBar
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle(viewModel.book.title.isEmpty ? "memorize.untitled".localized : viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            MemorizeStorage.shared.deleteBook(viewModel.book.id)
                            dismiss()
                        } label: {
                            Label("memorize.delete_session_confirm".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            viewModel.reload()
        }
    }

    private var bottomTabBar: some View {
        HStack {
            tabButton(tab: .sources, icon: "doc.on.doc.fill", label: "memorize.sources".localized)
            tabButton(tab: .study, icon: "sparkles", label: "memorize.study".localized)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppColors.memorizeCard)
    }

    private func tabButton(tab: ProjectTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(AppTypography.caption)
            }
            .foregroundColor(selectedTab == tab ? AppColors.memorizeAccent : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
    }
}
