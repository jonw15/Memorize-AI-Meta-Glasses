/*
 * Add Source Sheet
 * Bottom sheet with options to add a source to a project
 */

import SwiftUI

struct AddSourceSheet: View {
    let onTextNote: () -> Void
    let onCamera: () -> Void
    let onFile: () -> Void
    let onYouTube: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.add_source_title".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(Color(hex: "1F2420"))
                    .padding(.top, AppSpacing.md)

                VStack(spacing: AppSpacing.sm) {
                    sourceOption(icon: "play.rectangle.fill", title: "memorize.source_youtube".localized, subtitle: "memorize.source_youtube_desc".localized) {
                        onYouTube()
                    }

                    sourceOption(icon: "camera.fill", title: "memorize.source_camera".localized, subtitle: "memorize.source_camera_desc".localized) {
                        onCamera()
                    }

                    sourceOption(icon: "doc.text.fill", title: "memorize.source_file".localized, subtitle: "memorize.source_file_desc".localized) {
                        onFile()
                    }

                    sourceOption(icon: "note.text", title: "memorize.source_text_note".localized, subtitle: "memorize.source_text_note_desc".localized) {
                        onTextNote()
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                Spacer()
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "8D958E"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private func sourceOption(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.memorizeAccent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(AppSpacing.sm)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.md)
        }
    }
}
