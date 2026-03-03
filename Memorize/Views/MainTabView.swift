/*
 * Main Tab View
 * Main tab navigation view
 */

import SwiftUI

struct MainTabView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel
    @Binding var autoLaunchLiveAI: Bool
    @Binding var restoreProjectContext: ProjectContextSnapshot?

    @State private var selectedTab = 0

    // Read API Key from secure storage
    private var apiKey: String {
        APIKeyManager.shared.getAPIKey() ?? ""
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Memorize - Book learning
            MemorizeHomeView(streamViewModel: streamViewModel, wearablesViewModel: wearablesViewModel)
                .tabItem {
                    Label("tab.memorize".localized, systemImage: "book.fill")
                }
                .tag(0)

            // Records
            RecordsView()
                .tabItem {
                    Label("tab.records".localized, systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            // Gallery
            GalleryView()
                .tabItem {
                    Label("tab.gallery".localized, systemImage: "photo.on.rectangle")
                }
                .tag(2)

            // Settings
            SettingsView(streamViewModel: streamViewModel, apiKey: apiKey)
                .tabItem {
                    Label("tab.settings".localized, systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(AppColors.primary)
    }
}
