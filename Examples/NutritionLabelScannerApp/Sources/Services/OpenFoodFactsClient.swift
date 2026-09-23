import Foundation

// MARK: - Open Food Facts Real-World Barcode Lookup Client

public struct OpenFoodFactsClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches verified real-world product details by barcode from the Open Food Facts API.
    public func fetchProduct(barcode: String) async -> FoodProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0
        request.setValue("NutritionLabelScanner - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else {
                return nil
            }

            return product.toFoodProduct(barcode: barcode)
        } catch {
            return nil
        }
    }
}

// MARK: - Decodable Open Food Facts Models

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let product_name: String?
    let brands: String?
    let categories: String?
    let ingredients_text: String?
    let allergens: String?
    let serving_size: String?
    let nutriments: OFFNutriments?

    func toFoodProduct(barcode: String) -> FoodProduct {
        let brandName = brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Scanned Brand"
        let prodName = product_name ?? "Food Item"
        let category = categories?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Grocery"
        let serving = serving_size ?? "1 serving"

        let cals = Int(nutriments?.energyKcalServing ?? nutriments?.energyKcal100g ?? 0)
        let fat = nutriments?.fatServing ?? nutriments?.fat100g ?? 0.0
        let satFat = nutriments?.saturatedFatServing ?? nutriments?.saturatedFat100g ?? 0.0
        let sodiumG = nutriments?.sodiumServing ?? nutriments?.sodium100g ?? 0.0
        let sodiumMg = Int(sodiumG * 1000)
        let carbs = nutriments?.carbohydratesServing ?? nutriments?.carbohydrates100g ?? 0.0
        let fiber = nutriments?.fiberServing ?? nutriments?.fiber100g ?? 0.0
        let sugars = nutriments?.sugarsServing ?? nutriments?.sugars100g ?? 0.0
        let addedSugars = nutriments?.addedSugarsServing ?? 0.0
        let protein = nutriments?.proteinsServing ?? nutriments?.proteins100g ?? 0.0

        let warning = allergens?.isEmpty == false ? "Allergens reported: \(allergens!)" : nil

        return FoodProduct(
            id: barcode,
            brand: brandName,
            name: prodName,
            packageCategory: category,
            barcode: barcode,
            iconSystemName: "barcode.viewfinder",
            ingredientsText: ingredients_text ?? "Ingredients not recorded in database. Please point camera at the ingredients panel to verify with Jev.",
            facilityWarning: warning,
            nutrition: NutritionFacts(
                servingSize: serving,
                calories: cals,
                totalFatGrams: fat,
                saturatedFatGrams: satFat,
                sodiumMilligrams: sodiumMg,
                totalCarbGrams: carbs,
                dietaryFiberGrams: fiber,
                totalSugarGrams: sugars,
                addedSugarGrams: addedSugars,
                proteinGrams: protein
            )
        )
    }
}

private struct OFFNutriments: Decodable {
    let energyKcalServing: Double?
    let energyKcal100g: Double?
    let fatServing: Double?
    let fat100g: Double?
    let saturatedFatServing: Double?
    let saturatedFat100g: Double?
    let sodiumServing: Double?
    let sodium100g: Double?
    let carbohydratesServing: Double?
    let carbohydrates100g: Double?
    let fiberServing: Double?
    let fiber100g: Double?
    let sugarsServing: Double?
    let sugars100g: Double?
    let addedSugarsServing: Double?
    let proteinsServing: Double?
    let proteins100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcalServing = "energy-kcal_serving"
        case energyKcal100g = "energy-kcal_100g"
        case fatServing = "fat_serving"
        case fat100g = "fat_100g"
        case saturatedFatServing = "saturated-fat_serving"
        case saturatedFat100g = "saturated-fat_100g"
        case sodiumServing = "sodium_serving"
        case sodium100g = "sodium_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case fiberServing = "fiber_serving"
        case fiber100g = "fiber_100g"
        case sugarsServing = "sugars_serving"
        case sugars100g = "sugars_100g"
        case addedSugarsServing = "added-sugars_serving"
        case proteinsServing = "proteins_serving"
        case proteins100g = "proteins_100g"
    }
}
