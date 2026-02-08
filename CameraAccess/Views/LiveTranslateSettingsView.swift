/*
 * Live Translate Settings View
 * Live translation settings interface
 */

import SwiftUI

struct LiveTranslateSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LiveTranslateViewModel

    var body: some View {
        NavigationView {
            List {
                // Source language
                Section {
                    ForEach(TranslateLanguage.sourceLanguages) { language in
                        Button {
                            viewModel.sourceLanguage = language
                        } label: {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)
                                Text(language.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.sourceLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("livetranslate.settings.sourceLanguage".localized)
                }

                // Target language
                Section {
                    ForEach(TranslateLanguage.targetLanguages) { language in
                        Button {
                            viewModel.targetLanguage = language
                        } label: {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)
                                Text(language.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.targetLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("livetranslate.settings.targetLanguage".localized)
                } footer: {
                    Text("livetranslate.settings.targetLanguage.footer".localized)
                }

                // Voice selection
                Section {
                    ForEach(TranslateVoice.allCases) { voice in
                        Button {
                            viewModel.selectedVoice = voice
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(voice.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.selectedVoice == voice {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                Text(voice.description)
                                    .font(AppTypography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(!voice.supports(language: viewModel.targetLanguage))
                        .opacity(voice.supports(language: viewModel.targetLanguage) ? 1.0 : 0.5)
                    }
                } header: {
                    Text("livetranslate.settings.voice".localized)
                } footer: {
                    Text("livetranslate.settings.voice.footer".localized)
                }

                // Microphone selection
                Section {
                    Toggle(isOn: $viewModel.usePhoneMic) {
                        HStack {
                            Image(systemName: viewModel.usePhoneMic ? "iphone" : "airpodsmax")
                                .foregroundColor(.purple)
                            Text("livetranslate.settings.usePhoneMic".localized)
                        }
                    }
                } header: {
                    Text("livetranslate.settings.microphone".localized)
                } footer: {
                    Text("livetranslate.settings.microphone.footer".localized)
                }

                // Output options
                Section {
                    Toggle(isOn: $viewModel.audioOutputEnabled) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text("livetranslate.settings.audioOutput".localized)
                        }
                    }

                    Toggle(isOn: $viewModel.imageEnhanceEnabled) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.green)
                            Text("livetranslate.settings.imageEnhance".localized)
                        }
                    }
                } header: {
                    Text("livetranslate.settings.output".localized)
                } footer: {
                    Text("livetranslate.settings.imageEnhance.footer".localized)
                }

                // History
                if !viewModel.translationHistory.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("livetranslate.settings.clearHistory".localized)
                            }
                        }
                    } header: {
                        Text("livetranslate.settings.history".localized)
                    } footer: {
                        Text(String(format: "livetranslate.settings.historyCount".localized, viewModel.translationHistory.count))
                    }
                }
            }
            .navigationTitle("livetranslate.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LiveTranslateSettingsView(viewModel: LiveTranslateViewModel())
}
