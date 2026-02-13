/*
 * Permissions Request View
 * Permissions request screen shown at app launch
 */

import SwiftUI

struct PermissionsRequestView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var isRequesting = false
    @State private var showSettings = false
    let onComplete: (Bool) -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [AppColors.primary.opacity(0.1), AppColors.secondary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.primary)

                // Title
                VStack(spacing: AppSpacing.sm) {
                    Text("Your Authorization Is Needed")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Aria needs the following permissions to work properly")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                // Permissions List
                VStack(spacing: AppSpacing.md) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Voice conversations and recording"
                    )

                    PermissionRow(
                        icon: "photo.fill",
                        title: "Photo Library",
                        description: "Save photos captured by the glasses"
                    )
                }
                .padding(.horizontal, AppSpacing.xl)

                Spacer()

                // Request Button
                VStack(spacing: AppSpacing.md) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                    } else if showSettings {
                        VStack(spacing: AppSpacing.sm) {
                            Text("Some permissions were not granted")
                                .font(AppTypography.caption)
                                .foregroundColor(.red)

                            Button {
                                permissionsManager.openSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Go to Settings")
                                        .font(AppTypography.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.primary)
                                .foregroundColor(.black)
                                .cornerRadius(AppCornerRadius.lg)
                            }

                            Button("Continue with Limited Features") {
                                onComplete(false)
                            }
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        Button {
                            requestPermissions()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Grant Permissions")
                                    .font(AppTypography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .foregroundColor(.black)
                            .cornerRadius(AppCornerRadius.lg)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .onAppear {
            // Check if permissions are already granted
            if permissionsManager.checkAllPermissions() {
                onComplete(true)
            }
        }
    }

    private func requestPermissions() {
        isRequesting = true

        permissionsManager.requestAllPermissions { allGranted in
            isRequesting = false

            if allGranted {
                // All permissions granted, continue
                onComplete(true)
            } else {
                // Some permissions not granted, show settings button
                showSettings = true
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.primary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(.black)

                Text(description)
                    .font(AppTypography.caption)
                    .foregroundColor(.black)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.md)
        .shadow(color: AppShadow.small(), radius: 5, x: 0, y: 2)
    }
}
