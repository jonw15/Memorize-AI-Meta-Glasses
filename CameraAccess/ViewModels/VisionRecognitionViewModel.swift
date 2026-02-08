/*
 * Vision Recognition ViewModel
 * Manages image recognition state and API interaction
 */

import Foundation
import SwiftUI

@MainActor
class VisionRecognitionViewModel: ObservableObject {
    // Published properties for UI
    @Published var isAnalyzing = false
    @Published var recognitionResult: String?
    @Published var errorMessage: String?
    @Published var customPrompt: String = "What scene is depicted in the image?"

    private let apiService: VisionAPIService
    private let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self.apiService = VisionAPIService(apiKey: apiKey)
    }

    // MARK: - Public Methods

    func analyzeImage(with prompt: String? = nil) async {
        isAnalyzing = true
        errorMessage = nil
        recognitionResult = nil

        do {
            let promptToUse = prompt ?? customPrompt
            let result = try await apiService.analyzeImage(photo, prompt: promptToUse)
            recognitionResult = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    func retryAnalysis() async {
        await analyzeImage()
    }

    func clearResult() {
        recognitionResult = nil
        errorMessage = nil
    }

    // MARK: - Quick Prompts

    static let quickPrompts = [
        "What scene is depicted in the image?",
        "Please describe the contents of this image in detail",
        "What objects are in this image?",
        "Describe this image in English",
        "What place is this?",
        "What are the people in the image doing?"
    ]
}
