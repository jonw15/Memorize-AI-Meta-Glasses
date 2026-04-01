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
  var forceProjectIntroOnly: Bool = false
  var onNewProject: ((ProjectContextSnapshot) -> Void)? = nil
  @State private var showConnectionSuccess = false
  @State private var showConnectPage = false

  private var hasDetectedGlasses: Bool {
    !viewModel.devices.isEmpty || viewModel.hasMockDevice
  }

  var body: some View {
    ZStack {
      AppColors.memorizeBackground
        .edgesIgnoringSafeArea(.all)

      if showConnectPage {
        connectGlassesPage
      } else {
        welcomePage
      }

      // Connection Success Toast
      if showConnectionSuccess {
        VStack {
          Spacer()

          HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
              .font(.title2)
              .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
              Text("Connected Successfully")
                .font(AppTypography.headline)
                .foregroundColor(.white)
              Text("Entering Recall...")
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.7))
            }

            Spacer()
          }
          .padding(AppSpacing.md)
          .background(AppColors.memorizeCard)
          .cornerRadius(AppCornerRadius.lg)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          withAnimation {
            showConnectionSuccess = false
          }
        }
      }
    }
  }

  // MARK: - Welcome Page

  private var welcomePage: some View {
    VStack(spacing: 0) {
      Spacer()

      // Logo & Title
      VStack(spacing: AppSpacing.sm) {
        Image(systemName: "brain.head.profile.fill")
          .font(.system(size: 52))
          .foregroundColor(AppColors.memorizeAccent)
          .padding(.bottom, AppSpacing.sm)

        Text("Recall")
          .font(.system(size: 38, weight: .bold))
          .foregroundColor(.white)

        Text("AI-Powered Study Assistant")
          .font(AppTypography.subheadline)
          .foregroundColor(Color.white.opacity(0.5))
      }
      .padding(.bottom, AppSpacing.xl)

      // Features
      VStack(spacing: AppSpacing.sm) {
        featureRow(icon: "camera.fill", title: "Capture Anything", text: "Snap pages with your glasses or phone camera")
        featureRow(icon: "sparkles", title: "AI Study Tools", text: "Podcasts, quizzes, summaries, and conversations")
        featureRow(icon: "doc.on.doc.fill", title: "Multiple Sources", text: "PDFs, notes, and photos — all in one project")
      }
      .padding(.horizontal, AppSpacing.md)

      Spacer()

      // "Do you have glasses?" section
      VStack(spacing: AppSpacing.sm) {
        if hasDetectedGlasses {
          HStack(spacing: 8) {
            Circle()
              .fill(Color.green)
              .frame(width: 8, height: 8)
            Text("Ray-Ban Meta glasses detected nearby")
              .font(AppTypography.caption)
              .foregroundColor(Color.green.opacity(0.95))
          }
        }

        Text("Do you have Ray-Ban Meta glasses?")
          .font(AppTypography.subheadline)
          .foregroundColor(Color.white.opacity(0.6))

        Button {
          if hasDetectedGlasses {
            Task { await viewModel.connectGlasses() }
          } else {
            withAnimation { showConnectPage = true }
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "eyeglasses")
              .font(.title3)
            if viewModel.registrationState == .registering {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
              Text("Connecting...")
            } else {
              Text(hasDetectedGlasses ? "Connect Ray-Ban Meta" : "Yes, connect my glasses")
            }
          }
          .font(AppTypography.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(AppColors.memorizeAccent)
          .cornerRadius(AppCornerRadius.lg)
        }
        .disabled(viewModel.registrationState == .registering)
        .padding(.horizontal, AppSpacing.lg)

        if hasDetectedGlasses {
          Button {
            withAnimation { showConnectPage = true }
          } label: {
            Text("Connection help")
              .font(AppTypography.subheadline)
              .foregroundColor(Color.white.opacity(0.5))
              .padding(.vertical, 4)
          }
        }

        Button {
          if forceProjectIntroOnly {
            onNewProject?(ProjectContextSnapshot(instructions: [], tools: [], parts: [], videos: []))
          } else {
            // Skip glasses — mark as registered so app proceeds
            viewModel.skipRegistration()
          }
        } label: {
          Text("No, use phone camera only")
            .font(AppTypography.subheadline)
            .foregroundColor(Color.white.opacity(0.5))
            .padding(.vertical, 12)
        }
      }
      .padding(.bottom, AppSpacing.xl)
    }
  }

  // MARK: - Connect Glasses Page

  private var connectGlassesPage: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(spacing: AppSpacing.md) {
        Image(systemName: "eyeglasses")
          .font(.system(size: 52))
          .foregroundColor(AppColors.memorizeAccent)

        Text("Connect Ray-Ban Meta")
          .font(.system(size: 28, weight: .bold))
          .foregroundColor(.white)

        Text("Make sure your glasses are in developer mode and nearby")
          .font(AppTypography.subheadline)
          .foregroundColor(Color.white.opacity(0.5))
          .multilineTextAlignment(.center)
          .padding(.horizontal, AppSpacing.xl)
      }

      Spacer()

      VStack(spacing: AppSpacing.md) {
        Button {
          Task { await viewModel.connectGlasses() }
        } label: {
          HStack(spacing: AppSpacing.sm) {
            if viewModel.registrationState == .registering {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
              Text("Connecting...")
            } else {
              Image(systemName: "link.circle.fill")
                .font(.title3)
              Text("Connect Now")
            }
          }
          .font(AppTypography.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(AppColors.memorizeAccent)
          .cornerRadius(AppCornerRadius.lg)
        }
        .disabled(viewModel.registrationState == .registering)
        .padding(.horizontal, AppSpacing.lg)

        Button {
          withAnimation { showConnectPage = false }
        } label: {
          Text("Back")
            .font(AppTypography.subheadline)
            .foregroundColor(Color.white.opacity(0.5))
            .padding(.vertical, 12)
        }
      }
      .padding(.bottom, AppSpacing.xl)
    }
  }

  private func featureRow(icon: String, title: String, text: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundColor(AppColors.memorizeAccent)
        .frame(width: 40, height: 40)
        .background(AppColors.memorizeAccent.opacity(0.15))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(AppTypography.subheadline)
          .foregroundColor(.white)
        Text(text)
          .font(AppTypography.caption)
          .foregroundColor(Color.white.opacity(0.5))
      }

      Spacer()
    }
    .padding(AppSpacing.sm)
    .background(AppColors.memorizeCard)
    .cornerRadius(AppCornerRadius.md)
  }

}

// MARK: - Feature Tip View (kept for backward compatibility)

struct FeatureTipView: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.md) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(AppColors.memorizeAccent)
        .frame(width: 48, height: 48)
        .background(AppColors.memorizeAccent.opacity(0.15))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(title)
          .font(AppTypography.headline)
          .foregroundColor(.white)

        Text(text)
          .font(AppTypography.subheadline)
          .foregroundColor(Color.white.opacity(0.5))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.horizontal, AppSpacing.lg)
  }
}
