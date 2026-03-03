/*
 * Food Nutrition Model
 * Food nutrition data model
 */

import Foundation

// MARK: - Food Nutrition Response

struct FoodNutritionResponse: Codable {
    let foods: [FoodItem]
    let totalCalories: Int
    let totalProtein: Double
    let totalFat: Double
    let totalCarbs: Double
    let healthScore: Int
    let suggestions: [String]

    enum CodingKeys: String, CodingKey {
        case foods
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalFat = "total_fat"
        case totalCarbs = "total_carbs"
        case healthScore = "health_score"
        case suggestions
    }
}

// MARK: - Food Item

struct FoodItem: Codable, Identifiable {
    let id = UUID()
    let name: String
    let portion: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double?
    let sugar: Double?
    let healthRating: String

    enum CodingKeys: String, CodingKey {
        case name
        case portion
        case calories
        case protein
        case fat
        case carbs
        case fiber
        case sugar
        case healthRating = "health_rating"
    }

    var healthRatingEmoji: String {
        switch healthRating {
        case "Excellent": return "🟢"
        case "Good": return "🟡"
        case "Average": return "🟠"
        case "Poor": return "🔴"
        default: return "⚪️"
        }
    }
}

// MARK: - Nutrition Summary

extension FoodNutritionResponse {
    var formattedTotalCalories: String {
        "\(totalCalories) kcal"
    }

    var formattedTotalProtein: String {
        String(format: "%.1f g", totalProtein)
    }

    var formattedTotalFat: String {
        String(format: "%.1f g", totalFat)
    }

    var formattedTotalCarbs: String {
        String(format: "%.1f g", totalCarbs)
    }

    var healthScoreColor: String {
        if healthScore >= 80 {
            return "green"
        } else if healthScore >= 60 {
            return "yellow"
        } else if healthScore >= 40 {
            return "orange"
        } else {
            return "red"
        }
    }

    var healthScoreText: String {
        if healthScore >= 80 {
            return "Very Healthy"
        } else if healthScore >= 60 {
            return "Fairly Healthy"
        } else if healthScore >= 40 {
            return "Average"
        } else {
            return "Needs Improvement"
        }
    }
}
