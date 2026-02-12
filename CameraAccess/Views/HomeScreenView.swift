/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// HomeScreenView.swift
//
// Welcome screen that guides users through the DAT SDK registration process.
// This view is displayed when the app is not yet registered.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel
  @State private var showConnectionSuccess = false

  var body: some View {
    ZStack {
      // Gradient background
      LinearGradient(
        colors: [
          AppColors.primary.opacity(0.15),
          AppColors.secondary.opacity(0.15),
          Color.white
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .edgesIgnoringSafeArea(.all)

      VStack(spacing: AppSpacing.xl) {
        Spacer()

        // Aria Logo
        VStack(spacing: AppSpacing.md) {
          Image(.cameraAccessIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)

          Text("Aria")
            .font(AppTypography.largeTitle)
            .foregroundColor(AppColors.textPrimary)

          Text("Rayban Meta Assistant")
            .font(AppTypography.callout)
            .foregroundColor(AppColors.textSecondary)
        }

        // Features
        VStack(spacing: AppSpacing.md) {
          FeatureTipView(
            icon: "video.fill",
            title: "Live Video",
            text: "Record video directly from the glasses perspective, capturing what you see and hear"
          )
          FeatureTipView(
            icon: "brain.head.profile",
            title: "AI Chat",
            text: "Real-time AI assistant, providing smart help anytime, anywhere"
          )
          FeatureTipView(
            icon: "waveform",
            title: "Open Audio",
            text: "Keep your ears open to the world around you while receiving notifications"
          )
        }

        Spacer()

        // Connection Button
        VStack(spacing: AppSpacing.md) {
          Text("You will be redirected to the Meta AI app to confirm connection")
            .font(AppTypography.footnote)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.lg)

          Button {
            viewModel.connectGlasses()
          } label: {
            HStack(spacing: AppSpacing.sm) {
              if viewModel.registrationState == .registering {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("Connecting...")
              } else {
                Image(systemName: "eye.circle.fill")
                  .font(.title3)
                Text("Connect Ray-Ban Meta")
              }
            }
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
              LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)
          }
          .disabled(viewModel.registrationState == .registering)
          .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.xl)
      }
      .padding(.vertical, AppSpacing.xl)

      // Connection Success Toast
      if showConnectionSuccess {
        VStack {
          Spacer()

          HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
              .font(.title2)
              .foregroundColor(.green)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
              Text("Connected Successfully")
                .font(AppTypography.headline)
                .foregroundColor(.white)
              Text("Entering Aria...")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
          }
          .padding(AppSpacing.md)
          .background(Color.black.opacity(0.85))
          .cornerRadius(AppCornerRadius.lg)
          .shadow(color: AppShadow.large(), radius: 15, x: 0, y: 8)
          .padding(AppSpacing.lg)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .onChange(of: viewModel.registrationState) { _, newState in
      if newState == .registered {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
          showConnectionSuccess = true
        }

        // Auto dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          withAnimation {
            showConnectionSuccess = false
          }
        }
      }
    }
  }

}

// MARK: - Feature Tip View

struct FeatureTipView: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.md) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [AppColors.primary.opacity(0.2), AppColors.secondary.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 48, height: 48)

        Image(systemName: icon)
          .font(.title3)
          .foregroundColor(AppColors.primary)
      }

      VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(title)
          .font(AppTypography.headline)
          .foregroundColor(AppColors.textPrimary)

        Text(text)
          .font(AppTypography.subheadline)
          .foregroundColor(AppColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.horizontal, AppSpacing.lg)
  }
}
