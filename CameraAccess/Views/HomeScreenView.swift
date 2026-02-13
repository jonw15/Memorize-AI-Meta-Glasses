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
      Color.black
        .ignoresSafeArea()

      VStack(spacing: AppSpacing.xl) {
        Spacer()

        Text("Put on your glasses,\ntake a look,\nand tell me what\nyou're working on.")
          .font(.system(size: 58, weight: .regular))
          .foregroundStyle(.white)
          .lineSpacing(6)
          .multilineTextAlignment(.leading)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, 40)

        Spacer()

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
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 78)
          .background(
            LinearGradient(
              colors: [
                Color(red: 0.33, green: 0.53, blue: 0.95),
                Color(red: 0.19, green: 0.80, blue: 0.86)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(39)
          .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.registrationState == .registering)
        .padding(.horizontal, 28)
        .padding(.bottom, AppSpacing.xl)
      }
      .padding(.vertical, AppSpacing.xl)

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
