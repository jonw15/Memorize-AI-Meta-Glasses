/*
 * Settings View
 * Personal Center - Device management and settings
 */

import SwiftUI
import MWDATCore

struct SettingsView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var providerManager = APIProviderManager.shared
    let apiKey: String

    @State private var showAPIKeySettings = false
    @State private var showProviderSettings = false
    @State private var showModelSettings = false
    @State private var showLanguageSettings = false
    @State private var showAppLanguageSettings = false
    @State private var showQualitySettings = false
    @State private var showGoogleAPIKeySettings = false
    @State private var showQuickVisionSettings = false
    @State private var showLiveAISettings = false
    @State private var showLiveTranslateSettings = false
    @ObservedObject var quickVisionModeManager = QuickVisionModeManager.shared
    @ObservedObject var liveAIModeManager = LiveAIModeManager.shared
    @State private var selectedModel = "gemini-2.5-flash-native-audio-preview-12-2025"
    @State private var selectedLanguage = "en-US" // Default English
    @State private var selectedQuality = UserDefaults.standard.string(forKey: "video_quality") ?? "medium"
    @State private var hasAPIKey = false // Changed to State variable
    @State private var hasGoogleAPIKey = false // Google API Key state

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self.apiKey = apiKey
    }

    // Refresh API Key status
    private func refreshAPIKeyStatus() {
        hasAPIKey = providerManager.hasAPIKey
        hasGoogleAPIKey = APIKeyManager.shared.hasGoogleAPIKey()
    }

    var body: some View {
        NavigationView {
            List {
                // Device Management
                Section {
                    // Connection Status
                    HStack {
                        Image(systemName: "eye.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ray-Ban Meta")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text(streamViewModel.hasActiveDevice ? "settings.device.connected".localized : "settings.device.notconnected".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(streamViewModel.hasActiveDevice ? .green : AppColors.textSecondary)
                        }

                        Spacer()

                        // Connection status indicator
                        Circle()
                            .fill(streamViewModel.hasActiveDevice ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // Device Info
                    if streamViewModel.hasActiveDevice {
                        InfoRow(title: "settings.device.status".localized, value: "settings.device.online".localized)

                        if streamViewModel.isStreaming {
                            InfoRow(title: "settings.device.stream".localized, value: "settings.device.stream.active".localized)
                        } else {
                            InfoRow(title: "settings.device.stream".localized, value: "settings.device.stream.inactive".localized)
                        }
                    }
                } header: {
                    Text("settings.device".localized)
                }

                // AI Settings
                Section {
                    Button {
                        showAppLanguageSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe.asia.australia.fill")
                                .foregroundColor(AppColors.primary)
                            Text("settings.applanguage".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(languageManager.currentLanguage.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showLanguageSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(AppColors.translate)
                            Text("settings.language".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(languageDisplayName(selectedLanguage))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showQualitySettings = true
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                                .foregroundColor(AppColors.liveStream)
                            Text("settings.quality".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(qualityDisplayName(selectedQuality))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Quick Vision Settings
                    Button {
                        showQuickVisionSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "eye.circle.fill")
                                .foregroundColor(AppColors.quickVision)
                            Text("quickvision.settings".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(quickVisionModeManager.currentMode.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("settings.ai".localized)
                }

                // Live AI Settings
                Section {
                    // Live AI Mode Settings
                    Button {
                        showLiveAISettings = true
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(AppColors.liveAI)
                            Text("liveai.settings".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(liveAIModeManager.currentMode.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Live Translate Settings
                    Button {
                        showLiveTranslateSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(AppColors.translate)
                            Text("livetranslate.settings.title".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("settings.liveai".localized)
                }

            }
            .navigationTitle("settings.title".localized)
            .sheet(isPresented: $showAPIKeySettings) {
                APIKeySettingsView(provider: providerManager.currentProvider)
            }
            .onChange(of: showAPIKeySettings) { isShowing in
                // Refresh status when API Key settings view is dismissed
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showProviderSettings) {
                APIProviderSettingsView()
            }
            .onChange(of: showProviderSettings) { isShowing in
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showModelSettings) {
                VisionModelSettingsView()
            }
            .sheet(isPresented: $showLanguageSettings) {
                LanguageSettingsView(selectedLanguage: $selectedLanguage)
            }
            .sheet(isPresented: $showQualitySettings) {
                VideoQualitySettingsView(selectedQuality: $selectedQuality)
            }
            .sheet(isPresented: $showAppLanguageSettings) {
                AppLanguageSettingsView()
            }
            .sheet(isPresented: $showGoogleAPIKeySettings) {
                GoogleAPIKeySettingsView()
            }
            .onChange(of: showGoogleAPIKeySettings) { isShowing in
                // Refresh status when Google API Key settings view is dismissed
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showQuickVisionSettings) {
                QuickVisionSettingsView()
            }
            .sheet(isPresented: $showLiveAISettings) {
                LiveAISettingsView()
            }
            .sheet(isPresented: $showLiveTranslateSettings) {
                LiveTranslateSettingsView(viewModel: LiveTranslateViewModel())
            }
            .onAppear {
                // Refresh API Key status when view appears
                refreshAPIKeyStatus()
            }
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "Chinese"
        case "en-US": return "English"
        case "ja-JP": return "Japanese"
        case "ko-KR": return "Korean"
        case "es-ES": return "Spanish"
        case "fr-FR": return "French"
        default: return "Chinese"
        }
    }

    private func qualityDisplayName(_ code: String) -> String {
        switch code {
        case "low": return "Low Quality"
        case "medium": return "Medium Quality"
        case "high": return "High Quality"
        default: return "Medium Quality"
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - API Provider Settings

struct APIProviderSettingsView: View {
    @ObservedObject var providerManager = APIProviderManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Button {
                            providerManager.currentProvider = provider
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .foregroundColor(.primary)
                                    Text(providerDescription(provider))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if providerManager.currentProvider == provider {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.provider.select".localized)
                } footer: {
                    Text("settings.provider.description".localized)
                }

                // API Key status for current provider
                Section {
                    HStack {
                        Text("settings.apikey.status".localized)
                        Spacer()
                        if providerManager.hasAPIKey {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("settings.apikey.configured".localized)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("settings.apikey.notconfigured".localized)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Link(destination: URL(string: providerManager.currentProvider.apiKeyHelpURL)!) {
                        HStack {
                            Text("settings.provider.getapikey".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                } header: {
                    Text("\(providerManager.currentProvider.displayName) API Key")
                }
            }
            .navigationTitle("settings.provider".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func providerDescription(_ provider: APIProvider) -> String {
        switch provider {
        case .google:
            return "settings.provider.google.desc".localized
        case .openrouter:
            return "settings.provider.openrouter.desc".localized
        }
    }
}

// MARK: - API Key Settings

struct APIKeySettingsView: View {
    let provider: APIProvider
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("settings.apikey.placeholder".localized, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("\(provider.displayName) API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(provider == .google ? "settings.apikey.google.help".localized : "settings.apikey.openrouter.help".localized)
                        Link("settings.apikey.get".localized, destination: URL(string: provider.apiKeyHelpURL)!)
                            .font(.caption)
                    }
                }

                Section {
                    Button("save".localized) {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasAPIKey(for: provider) {
                        Button("settings.apikey.delete".localized, role: .destructive) {
                            deleteAPIKey()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("settings.apikey.manage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.apikey.saved".localized, isPresented: $showSaveSuccess) {
                Button("ok".localized) {
                    dismiss()
                }
            } message: {
                Text("settings.apikey.saved.message".localized)
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Load existing key if available
                if let existingKey = APIKeyManager.shared.getAPIKey(for: provider) {
                    apiKey = existingKey
                }
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "settings.apikey.empty".localized
            showError = true
            return
        }

        if APIKeyManager.shared.saveAPIKey(apiKey, for: provider) {
            showSaveSuccess = true
        } else {
            errorMessage = "settings.apikey.savefailed".localized
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteAPIKey(for: provider) {
            apiKey = ""
            dismiss()
        } else {
            errorMessage = "settings.apikey.deletefailed".localized
            showError = true
        }
    }
}

// MARK: - Vision Model Settings

struct VisionModelSettingsView: View {
    @ObservedObject var providerManager = APIProviderManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showVisionOnly = true

    var body: some View {
        NavigationView {
            Group {
                if providerManager.currentProvider == .google {
                    googleModelList
                } else {
                    openRouterModelList
                }
            }
            .navigationTitle("settings.model".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var googleModelList: some View {
        let models = [
            ("gemini-3-flash-preview", "Gemini 3 Flash", "settings.model.gemini3flash.desc".localized),
            ("gemini-3-pro-preview", "Gemini 3 Pro", "settings.model.gemini3pro.desc".localized)
        ]

        return List {
            Section {
                ForEach(models, id: \.0) { model in
                    Button {
                        providerManager.selectedModel = model.0
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.1)
                                    .foregroundColor(.primary)
                                Text(model.2)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if providerManager.selectedModel == model.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("settings.model.google".localized)
            } footer: {
                Text("settings.model.current".localized + ": \(providerManager.selectedModel)")
            }
        }
    }

    private var openRouterModelList: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("settings.model.search".localized, text: $searchText)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)

            // Vision only toggle
            Toggle("settings.model.visiononly".localized, isOn: $showVisionOnly)
                .padding(.horizontal)
                .padding(.vertical, 4)

            if providerManager.isLoadingModels {
                Spacer()
                ProgressView("settings.model.loading".localized)
                Spacer()
            } else if let error = providerManager.modelsError {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("settings.model.retry".localized) {
                        Task {
                            await providerManager.fetchOpenRouterModels()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else {
                List {
                    let filteredModels = getFilteredModels()

                    if filteredModels.isEmpty {
                        Text("settings.model.notfound".localized)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredModels) { model in
                            Button {
                                providerManager.selectedModel = model.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(model.displayName)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            if model.isVisionCapable {
                                                Image(systemName: "eye.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                        Text(model.id)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                        if !model.priceDisplay.isEmpty {
                                            Text(model.priceDisplay)
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                    if providerManager.selectedModel == model.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            if providerManager.openRouterModels.isEmpty {
                await providerManager.fetchOpenRouterModels()
            }
        }
    }

    private func getFilteredModels() -> [OpenRouterModel] {
        var models = providerManager.openRouterModels

        if showVisionOnly {
            models = models.filter { $0.isVisionCapable }
        }

        if !searchText.isEmpty {
            models = providerManager.searchModels(searchText)
            if showVisionOnly {
                models = models.filter { $0.isVisionCapable }
            }
        }

        return models
    }
}

// MARK: - Language Settings

struct LanguageSettingsView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss

    let languages = [
        ("en-US", "English"),
        ("zh-CN", "Chinese"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("es-ES", "Spanish"),
        ("fr-FR", "French")
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(languages, id: \.0) { lang in
                        Button {
                            selectedLanguage = lang.0
                        } label: {
                            HStack {
                                Text(lang.1)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedLanguage == lang.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select Output Language")
                } footer: {
                    Text("AI will use this language for voice output and text replies")
                }
            }
            .navigationTitle("Output Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Video Quality Settings

struct VideoQualitySettingsView: View {
    @Binding var selectedQuality: String
    @Environment(\.dismiss) private var dismiss

    var qualities: [(String, String, String)] {
        [
            ("low", "settings.quality.low".localized, "settings.quality.low.desc".localized),
            ("medium", "settings.quality.medium".localized, "settings.quality.medium.desc".localized),
            ("high", "settings.quality.high".localized, "settings.quality.high.desc".localized)
        ]
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(qualities, id: \.0) { quality in
                        Button {
                            selectedQuality = quality.0
                            UserDefaults.standard.set(quality.0, forKey: "video_quality")
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quality.1)
                                        .foregroundColor(.primary)
                                    Text(quality.2)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if selectedQuality == quality.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.quality.select".localized)
                } footer: {
                    Text("settings.quality.description".localized)
                }
            }
            .navigationTitle("settings.quality".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - App Language Settings

struct AppLanguageSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            // Only prompt restart when selecting a different language
                            if languageManager.currentLanguage != language {
                                pendingLanguage = language
                                showRestartAlert = true
                            }
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.applanguage.select".localized)
                } footer: {
                    Text("settings.applanguage.description".localized)
                }
            }
            .navigationTitle("settings.applanguage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.applanguage.restart.title".localized, isPresented: $showRestartAlert) {
                Button("cancel".localized, role: .cancel) {
                    pendingLanguage = nil
                }
                Button("settings.applanguage.restart.confirm".localized) {
                    if let language = pendingLanguage {
                        languageManager.currentLanguage = language
                        // Delay exit slightly to ensure settings are saved
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            exit(0)
                        }
                    }
                }
            } message: {
                Text("settings.applanguage.restart.message".localized)
            }
        }
    }
}

// MARK: - Google API Key Settings

struct GoogleAPIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("settings.apikey.placeholder".localized, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Google Gemini API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.apikey.google.help".localized)
                        Link("settings.apikey.get".localized, destination: URL(string: "https://aistudio.google.com/apikey")!)
                            .font(.caption)
                    }
                }

                Section {
                    Button("save".localized) {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasGoogleAPIKey() {
                        Button("settings.apikey.delete".localized, role: .destructive) {
                            deleteAPIKey()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("settings.apikey.manage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.apikey.saved".localized, isPresented: $showSaveSuccess) {
                Button("ok".localized) {
                    dismiss()
                }
            } message: {
                Text("settings.apikey.saved.message".localized)
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let existingKey = APIKeyManager.shared.getGoogleAPIKey() {
                    apiKey = existingKey
                }
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "settings.apikey.empty".localized
            showError = true
            return
        }

        if APIKeyManager.shared.saveGoogleAPIKey(apiKey) {
            showSaveSuccess = true
        } else {
            errorMessage = "settings.apikey.savefailed".localized
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteGoogleAPIKey() {
            apiKey = ""
            dismiss()
        } else {
            errorMessage = "settings.apikey.deletefailed".localized
            showError = true
        }
    }
}
