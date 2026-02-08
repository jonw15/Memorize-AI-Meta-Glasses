/*
 * Live AI Settings View
 * Live conversation settings - Mode selection, custom prompts, translation target language
 */

import SwiftUI

struct LiveAISettingsView: View {
    @ObservedObject var modeManager = LiveAIModeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Conversation mode selection
                Section {
                    ForEach(LiveAIMode.allCases) { mode in
                        Button {
                            modeManager.setMode(mode)
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(modeColor(mode))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if modeManager.currentMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("liveai.settings.mode".localized)
                } footer: {
                    Text("liveai.settings.mode.footer".localized)
                }

                // Translation target language (only shown in translate mode)
                if modeManager.currentMode == .translate {
                    Section {
                        ForEach(LiveAIModeManager.supportedLanguages, id: \.code) { language in
                            Button {
                                modeManager.setTranslateTargetLanguage(language.code)
                            } label: {
                                HStack {
                                    Text(language.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if modeManager.translateTargetLanguage == language.code {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("liveai.settings.targetlanguage".localized)
                    }
                }

                // Custom prompt (only shown in custom mode)
                if modeManager.currentMode == .custom {
                    Section {
                        TextEditor(text: $modeManager.customPrompt)
                            .frame(minHeight: 150)
                            .font(.body)
                    } header: {
                        Text("liveai.settings.customprompt".localized)
                    } footer: {
                        Text("liveai.settings.customprompt.footer".localized)
                    }
                }
            }
            .navigationTitle("liveai.settings".localized)
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

    private func modeColor(_ mode: LiveAIMode) -> Color {
        switch mode {
        case .standard:
            return .blue
        case .museum:
            return .brown
        case .blind:
            return .purple
        case .reading:
            return .green
        case .translate:
            return .orange
        case .custom:
            return .gray
        }
    }
}
