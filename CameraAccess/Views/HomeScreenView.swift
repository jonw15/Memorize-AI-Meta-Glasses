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
  let forceProjectIntroOnly: Bool
  let onNewProject: (() -> Void)?
  @State private var showConnectionSuccess = false
  @State private var currentPage = 0

  init(
    viewModel: WearablesViewModel,
    forceProjectIntroOnly: Bool = false,
    onNewProject: (() -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.forceProjectIntroOnly = forceProjectIntroOnly
    self.onNewProject = onNewProject
  }

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      Group {
        if forceProjectIntroOnly || currentPage == 0 {
          projectIntroPage
            .transition(.opacity)
        } else {
          connectPage
            .transition(.opacity)
        }
      }

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
    .animation(.easeInOut(duration: 0.2), value: currentPage)
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

  private var projectIntroPage: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: 150)

      Text("Aria Spark")
        .font(.system(size: 24, weight: .regular))
        .foregroundStyle(.white)

      Spacer()

      Text("Let's start a project")
        .font(.system(size: 34, weight: .regular))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.85)
        .lineLimit(1)
        .padding(.horizontal, 28)

      Button {
        if let onNewProject {
          onNewProject()
        } else {
          currentPage = 1
        }
      } label: {
        Text("New Project")
          .font(.system(size: 16, weight: .regular))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 66)
          .background(
            LinearGradient(
              colors: [
                Color(red: 0.10, green: 0.11, blue: 0.13),
                Color(red: 0.06, green: 0.06, blue: 0.09)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(33)
      }
      .padding(.horizontal, 28)
      .padding(.top, 36)

      VStack(spacing: 12) {
        comingSoonButton(title: "Hanging Pictures")
        comingSoonButton(title: "Declutter")
      }
      .padding(.horizontal, 28)
      .padding(.top, 12)

      Spacer()
        .frame(height: 160)
    }
  }

  private func comingSoonButton(title: String) -> some View {
    Button {} label: {
      HStack {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))

        Spacer()

        Text("Coming Soon")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.75))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.white.opacity(0.12))
          .cornerRadius(12)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.white.opacity(0.06))
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.white.opacity(0.16), lineWidth: 1)
      )
    }
    .disabled(true)
    .buttonStyle(.plain)
  }

  private var connectPage: some View {
    VStack(spacing: AppSpacing.xl) {
      Spacer()

      Text("Put on your glasses,\ntake a look,\nand tell me what\nyou're working on.")
        .font(.system(size: 34, weight: .regular))
        .foregroundStyle(.white)
        .lineSpacing(2)
        .multilineTextAlignment(.leading)
        .minimumScaleFactor(0.9)
        .padding(.horizontal, 36)

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
            Image(systemName: "eye.fill")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(Color(red: 0.36, green: 0.58, blue: 0.95))
              .frame(width: 30, height: 30)
              .background(Color.white.opacity(0.95))
              .clipShape(Circle())

            Text("Connect Ray-Ban Meta")
          }
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 66)
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
        .cornerRadius(33)
        .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)
      }
      .disabled(viewModel.registrationState == .registering)
      .padding(.horizontal, 28)
      .padding(.bottom, AppSpacing.xl)
    }
    .padding(.vertical, AppSpacing.xl)
  }
}
