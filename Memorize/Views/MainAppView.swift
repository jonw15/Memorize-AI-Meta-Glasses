/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// MainAppView.swift
//
// Central navigation hub that displays different views based on DAT SDK registration and device states.
// When unregistered, shows the registration flow. When registered, shows the device selection screen
// for choosing which Meta wearable device to stream from.
//

import MWDATCore
import SwiftUI

struct MainAppView: View {
  let wearables: WearablesInterface
  @ObservedObject private var viewModel: WearablesViewModel
  @StateObject private var streamViewModel: StreamSessionViewModel
  @StateObject private var quickVisionManager = QuickVisionManager.shared
  @State private var hasCheckedPermissions = false
  @State private var shouldAutoLaunchLiveAI = false
  @State private var showLaunchIntro = true
  @State private var restoreProjectContext: ProjectContextSnapshot?
  @State private var showWelcome = true

  init(wearables: WearablesInterface, viewModel: WearablesViewModel) {
    self.wearables = wearables
    self.viewModel = viewModel
    self._streamViewModel = StateObject(wrappedValue: StreamSessionViewModel(wearables: wearables))
  }

  var body: some View {
    Group {
      if showWelcome {
        // Welcome / onboarding screen
        HomeScreenView(viewModel: viewModel, onContinue: {
          withAnimation(.easeInOut(duration: 0.4)) {
            showWelcome = false
          }
        })
        .transition(.opacity)
      } else if !hasCheckedPermissions {
        // Request permissions
        PermissionsRequestView { _ in
          hasCheckedPermissions = true
        }
        .transition(.opacity)
      } else {
        // Main app interface
        MainTabView(
          streamViewModel: streamViewModel,
          wearablesViewModel: viewModel,
          autoLaunchLiveAI: $shouldAutoLaunchLiveAI,
          restoreProjectContext: $restoreProjectContext
        )
        .onAppear {
          quickVisionManager.setStreamViewModel(streamViewModel)
        }
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.4), value: showWelcome)
    .animation(.easeInOut(duration: 0.4), value: hasCheckedPermissions)
    .onReceive(NotificationCenter.default.publisher(for: .returnToNewProjectIntro)) { _ in
      shouldAutoLaunchLiveAI = false
      showLaunchIntro = true
    }
  }
}
