/*
 * Conversation Detail View
 * Conversation detail page
 */

import SwiftUI

struct ConversationDetailView: View {
    let conversation: ConversationRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Conversation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Conversation info
                VStack(spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "clock")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text(conversation.formattedDate)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(conversation.messageCount) messages")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.tertiaryBackground.opacity(0.95))
            }
        }
    }
}
