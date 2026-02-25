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
  struct PastProject: Identifiable, Equatable {
    let id: String
    let title: String
    let context: ProjectContextSnapshot?

    init(title: String, context: ProjectContextSnapshot? = nil) {
      self.title = title
      self.id = title.lowercased()
      self.context = context
    }
  }

  @ObservedObject var viewModel: WearablesViewModel
  let forceProjectIntroOnly: Bool
  let onNewProject: ((ProjectContextSnapshot?) -> Void)?
  @State private var showConnectionSuccess = false
  @State private var currentPage = 0
  @State private var pastProjects: [PastProject] = []
  @State private var projectPendingDelete: PastProject?
  @State private var pastProjectsScrollOffset: CGFloat = 0
  @State private var pastProjectsInitialMinY: CGFloat?

  init(
    viewModel: WearablesViewModel,
    forceProjectIntroOnly: Bool = false,
    onNewProject: ((ProjectContextSnapshot?) -> Void)? = nil
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
    .onAppear {
      loadPastProjects()
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
          onNewProject(nil)
        } else {
          currentPage = 1
        }
      } label: {
        Text("New Project")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 66)
          .background(
            LinearGradient(
              colors: [
                Color(red: 0.27, green: 0.43, blue: 0.93),
                Color(red: 0.18, green: 0.31, blue: 0.78)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(33)
          .overlay(
            RoundedRectangle(cornerRadius: 33, style: .continuous)
              .stroke(Color.white.opacity(0.28), lineWidth: 1)
          )
          .shadow(color: Color(red: 0.27, green: 0.43, blue: 0.93).opacity(0.45), radius: 10, x: 0, y: 5)
      }
      .padding(.horizontal, 28)
      .padding(.top, 36)

      pastProjectsSection
      .padding(.horizontal, 28)
      .padding(.top, 36)

      Spacer()
        .frame(height: 120)
    }
  }

  private var pastProjectsSection: some View {
    let panelHeight: CGFloat = 170
    let rowHeight: CGFloat = 56
    let rowSpacing: CGFloat = 10
    let verticalPadding: CGFloat = 20
    let contentHeight = max(
      (CGFloat(pastProjects.count) * rowHeight)
        + (CGFloat(max(pastProjects.count - 1, 0)) * rowSpacing)
        + verticalPadding,
      panelHeight
    )
    let rawThumbHeight = panelHeight * panelHeight / contentHeight
    let thumbHeight = min(panelHeight, max(32, rawThumbHeight))
    let scrollableHeight = max(contentHeight - panelHeight, 1)
    let progress = min(max(-pastProjectsScrollOffset / scrollableHeight, 0), 1)
    let thumbTravel = max(panelHeight - thumbHeight, 0)
    let thumbOffset = progress * thumbTravel

    return VStack(alignment: .leading, spacing: 12) {
      Text("Past Projects")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white.opacity(0.75))

      if pastProjects.isEmpty {
        Text("No past projects yet.")
          .font(.system(size: 15, weight: .regular))
          .foregroundStyle(.white.opacity(0.6))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.vertical, 18)
          .background(Color.white.opacity(0.06))
          .cornerRadius(16)
      } else {
        ZStack(alignment: .trailing) {
          ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
              ForEach(pastProjects) { project in
                pastProjectRow(project)
              }
            }
            .background(
              GeometryReader { geo in
                Color.clear
                  .preference(key: PastProjectsScrollOffsetKey.self, value: geo.frame(in: .named("PastProjectsScrollArea")).minY)
              }
            )
            .padding(10)
            .padding(.trailing, 12)
          }
          .coordinateSpace(name: "PastProjectsScrollArea")
          .frame(height: panelHeight)

          Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 3, height: panelHeight - 16)
            .overlay(alignment: .top) {
              Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: 3, height: thumbHeight)
                .offset(y: thumbOffset)
            }
            .padding(.trailing, 6)
            .allowsHitTesting(false)
        }
        .onPreferenceChange(PastProjectsScrollOffsetKey.self) { value in
          if pastProjectsInitialMinY == nil {
            pastProjectsInitialMinY = value
          }
          let baseline = pastProjectsInitialMinY ?? value
          let scrollAmount = max(0, baseline - value)
          pastProjectsScrollOffset = -scrollAmount
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
      }
    }
    .sheet(item: $projectPendingDelete) { project in
      DeleteProjectConfirmationView(projectTitle: project.title) {
        ConversationStorage.shared.deleteConversations(withTitle: project.title)
        loadPastProjects()
      }
    }
  }

  private func pastProjectRow(_ project: PastProject) -> some View {
    HStack {
      Button {
        if let onNewProject {
          onNewProject(project.context)
        } else {
          currentPage = 1
        }
      } label: {
        Text(project.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      Spacer()

      Button {
        projectPendingDelete = project
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.red.opacity(0.9))
          .frame(width: 34, height: 34)
          .background(Color.red.opacity(0.12))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Delete \(project.title)")
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

  private func loadPastProjects() {
    let sessions = ConversationStorage.shared.loadPastProjectSessions(limit: 20)
    pastProjects = sessions.map { PastProject(title: $0.title, context: $0.context) }
    pastProjectsInitialMinY = nil
    pastProjectsScrollOffset = 0
  }
}

private struct PastProjectsScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value += nextValue()
  }
}

private struct DeleteProjectConfirmationView: View {
  @Environment(\.dismiss) private var dismiss

  let projectTitle: String
  let onConfirmDelete: () -> Void

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        Spacer()

        Image(systemName: "trash.circle.fill")
          .font(.system(size: 68))
          .foregroundStyle(.red)

        Text("Delete Project?")
          .font(.system(size: 26, weight: .semibold))
          .foregroundStyle(.white)

        Text("Are you sure you want to delete \"\(projectTitle)\"? This action cannot be undone.")
          .font(.system(size: 16))
          .foregroundStyle(.white.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 28)

        Spacer()

        VStack(spacing: 12) {
          Button {
            onConfirmDelete()
            dismiss()
          } label: {
            Text("Delete Project")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 54)
              .background(Color.red.opacity(0.9))
              .cornerRadius(16)
          }

          Button {
            dismiss()
          } label: {
            Text("Cancel")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 54)
              .background(Color.white.opacity(0.12))
              .cornerRadius(16)
          }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
      }
      .background(Color.black.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") {
            dismiss()
          }
          .foregroundStyle(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
