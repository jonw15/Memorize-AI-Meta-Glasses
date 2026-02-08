/*
 * LeanEat ViewModel
 * Food nutrition analysis view model
 */

import Foundation
import SwiftUI

@MainActor
class LeanEatViewModel: ObservableObject {
    // Published properties
    @Published var isAnalyzing = false
    @Published var nutritionData: FoodNutritionResponse?
    @Published var errorMessage: String?

    private let service: LeanEatService
    private let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self.service = LeanEatService(apiKey: apiKey)
    }

    // MARK: - Public Methods

    func analyzeFood() async {
        isAnalyzing = true
        errorMessage = nil
        nutritionData = nil

        do {
            print("🍎 [LeanEat] Starting food nutrition analysis...")
            let result = try await service.analyzeFood(photo)
            nutritionData = result
            print("✅ [LeanEat] Analysis complete: \(result.foods.count) food items")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [LeanEat] Analysis failed: \(error)")
        }

        isAnalyzing = false
    }

    func retry() async {
        await analyzeFood()
    }

    func clear() {
        nutritionData = nil
        errorMessage = nil
    }
}
