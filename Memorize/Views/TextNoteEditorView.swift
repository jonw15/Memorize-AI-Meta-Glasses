/*
 * Text Note Editor View
 * Simple editor for adding a text note as a source
 */

import SwiftUI

struct TextNoteEditorView: View {
    let onSave: (String, String) -> Void  // (title, text)

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""

    private var isValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                TextField("memorize.note_title_placeholder".localized, text: $title)
                    .font(AppTypography.headline)
                    .foregroundColor(Color(hex: "1F2420"))
                    .padding(AppSpacing.sm)
                    .background(Color.white.opacity(0.94))
                    .cornerRadius(AppCornerRadius.md)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("memorize.note_text_placeholder".localized)
                            .font(AppTypography.body)
                            .foregroundColor(Color(hex: "8D958E"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $text)
                        .font(AppTypography.body)
                        .foregroundColor(Color(hex: "1F2420"))
                        .scrollContentBackground(.hidden)
                }
                .padding(AppSpacing.sm)
                .background(Color.white.opacity(0.94))
                .cornerRadius(AppCornerRadius.md)
                .frame(maxHeight: .infinity)

                Button {
                    let noteTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalTitle = noteTitle.isEmpty ? "Note · \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))" : noteTitle
                    onSave(finalTitle, text.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Text("memorize.save_note".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(Color(hex: "1F2420"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid ? AppColors.memorizeAccent : Color(hex: "EAE4DC"))
                        .cornerRadius(AppCornerRadius.md)
                }
                .disabled(!isValid)
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.add_text_note".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "1F2420"))
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}
