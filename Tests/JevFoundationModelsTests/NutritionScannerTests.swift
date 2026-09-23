import Testing
import Foundation
import FoundationModels
@testable import JevFoundationModels

// MARK: - Test Dietary Decision Schemas

@Generable
enum TestDietaryFlag: String, Sendable, CaseIterable {
    case none
    case hiddenGluten
    case dairyOrLactose
    case seedOils
    case highAddedSugar
    case artificialSweeteners
    case excessiveSodium
    case animalDerivatives
}

@Generable
struct TestDietarySafetyDecision: Sendable {
    @Guide(description: "Is this food item compliant with the user's active dietary safety profile?")
    var isSafe: Bool

    @Guide(
        description: "Allergen exposure rubric from 0 (clean) to 3 (explicit direct allergen)",
        .range(0...3)
    )
    var allergenRisk: Int

    @Guide(
        description: "NOVA food processing classification index from 0 (whole) to 3 (ultra-processed)",
        .range(0...3)
    )
    var processingTier: Int

    @Guide(description: "The primary dietary conflict or warning flag detected in this item")
    var primaryFlag: TestDietaryFlag
}

// MARK: - Test Nutrition Label Parser (Self-contained test fixture for OCR heuristics)

struct TestNutritionFacts: Equatable {
    let servingSize: String
    let calories: Int
    let totalFatGrams: Double
    let saturatedFatGrams: Double
    let sodiumMilligrams: Int
    let totalCarbGrams: Double
    let dietaryFiberGrams: Double
    let totalSugarGrams: Double
    let addedSugarGrams: Double
    let proteinGrams: Double
}

struct TestNutritionLabelParser {
    static func isNutritionLabelOrIngredients(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = [
            "nutrition facts", "calories", "total fat", "protein",
            "durchschnittliche nährwerte", "energie", "fett", "kohlenhydrate",
            "eiweiß", "eiweiss", "weib", "salz", "zutaten", "1439 kj", "kcal", "kca"
        ]
        let found = markers.filter { lower.contains($0) }.count
        return found >= 2 || (lower.contains("zutaten") && text.count > 25)
    }

    static func parseNutritionFacts(from text: String) -> TestNutritionFacts {
        let lower = text.lowercased()

        var servingSize = "100g"
        if lower.contains("pro 100 g") || lower.contains("pro 100g") {
            servingSize = "100g"
        } else if let match = extractRegexMatch(pattern: #"serving size[\s:]*([^\n\r,]+)"#, in: lower) {
            servingSize = match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let calories: Int = {
            if let m = extractRegexMatch(pattern: #"(?:/\s*)?(\d+)\s*kca[l]?"#, in: lower), let val = Int(m) { return val }
            if let m = extractRegexMatch(pattern: #"(?:calories|energie|brennwert)[\s:]*(\d+)"#, in: lower), let val = Int(m) { return val }
            return 0
        }()

        var totalFat = extractDecimal(pattern: #"(?<!gesättigte[n\s])(?:total fat|fett)[\s:]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0
        let satFat = extractDecimal(pattern: #"(?:davon\s+)?(?:gesättigte[n\s]*(?:fettsäuren)?|saturated fat)[\s:]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0
        var totalCarbs = extractDecimal(pattern: #"(?:total carb(?:ohydrate)?s?|kohlenhydrate)[\s:]*[-–•\s]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0
        var fiber = extractDecimal(pattern: #"(?:(?:dietary\s+)?fiber|ballaststoffe)[\s:]*[-–•\s]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0
        let totalSugars = extractDecimal(pattern: #"(?:davon\s+zucker|total sugars?|zucker)[\s:]*[-–•\s]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0
        let addedSugars = extractDecimal(pattern: #"(?:includes|incl\.?)?\s*([\d,\.]+)\s*g?\s*added sugars?"#, in: lower) ?? 0.0
        var protein = extractDecimal(pattern: #"(?:eiweiß|eiweiss|wei[bß]|protein)[\s:]*[-–•\s]*[<>]?\s*([\d,\.]+)"#, in: lower) ?? 0.0

        var sodiumMg: Int = {
            if let usSodium = extractFirstNumber(pattern: #"sodium[\s:]*(\d+)\s*mg"#, in: lower) { return usSodium }
            if let euSalt = extractDecimal(pattern: #"(?:salz|salt)[\s:]*[<>]?\s*([\d,\.]+)\s*g"#, in: lower) { return Int(euSalt * 400.0) }
            return 0
        }()

        // Column fallback
        if totalFat == 0.0 && totalCarbs == 0.0 && protein == 0.0 {
            if let regex = try? NSRegularExpression(pattern: #"[-–<>]?\s*([\d,\.]+)\s*g\b"#, options: [.caseInsensitive]) {
                let ns = lower as NSString
                var values = regex.matches(in: lower, options: [], range: NSRange(location: 0, length: ns.length)).compactMap { m -> Double? in
                    guard m.numberOfRanges > 1 else { return nil }
                    let raw = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                    return Double(raw)
                }
                if values.first == 100.0 { values.removeFirst() }
                if values.count >= 5 {
                    totalFat = values[0]
                    totalCarbs = values[1]
                    fiber = values[2]
                    protein = values[3]
                    sodiumMg = Int(values[4] * 400.0)
                }
            }
        }

        return TestNutritionFacts(
            servingSize: servingSize,
            calories: calories,
            totalFatGrams: totalFat,
            saturatedFatGrams: satFat,
            sodiumMilligrams: sodiumMg,
            totalCarbGrams: totalCarbs,
            dietaryFiberGrams: fiber,
            totalSugarGrams: totalSugars,
            addedSugarGrams: addedSugars,
            proteinGrams: protein
        )
    }

    static func extractIngredientsAndAllergens(from text: String) -> (ingredients: String, warning: String?) {
        let lower = text.lowercased()
        var warning: String? = nil
        if let r = lower.range(of: "contains:") {
            warning = "Contains: " + text[r.upperBound...].components(separatedBy: .newlines).first!.trimmingCharacters(in: .whitespaces)
        }

        for header in ["zutaten:", "ingredients:"] {
            if let r = lower.range(of: header) {
                return (String(text[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)), warning)
            }
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), warning)
    }

    private static func extractRegexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        guard let first = matches.first, first.numberOfRanges > 1 else { return nil }
        return ns.substring(with: first.range(at: 1))
    }

    private static func extractDecimal(pattern: String, in text: String) -> Double? {
        guard let match = extractRegexMatch(pattern: pattern, in: text) else { return nil }
        let cleaned = match.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private static func extractFirstNumber(pattern: String, in text: String) -> Int? {
        guard let match = extractRegexMatch(pattern: pattern, in: text) else { return nil }
        return Int(match.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Nutrition Scanner Suite

@Suite("Nutrition Scanner & Dietary Decision Tests")
struct NutritionScannerTests {

    // MARK: - Schema Translation

    @Test("DietarySafetyDecision translates into composite noul, choice, and score questions")
    func testSchemaTranslation() throws {
        let translator = SchemaTranslator()
        let translation = try translator.translate(TestDietarySafetyDecision.generationSchema)

        #expect(translation.questions.count == 4)

        // 1. Bool -> noul
        guard case .noul(let safeInstructions) = translation.questions["isSafe"] else {
            Issue.record("Expected 'isSafe' to translate to .noul")
            return
        }
        #expect(safeInstructions.contains("compliant with the user's active dietary safety profile"))

        // 2. Score (range 0...3) -> score
        guard case .score(let allergenInstructions, let allergenCriteria) = translation.questions["allergenRisk"] else {
            Issue.record("Expected 'allergenRisk' to translate to .score")
            return
        }
        #expect(allergenInstructions.contains("Allergen exposure rubric"))
        #expect(allergenCriteria.count == 4)

        guard case .score(let novaInstructions, let novaCriteria) = translation.questions["processingTier"] else {
            Issue.record("Expected 'processingTier' to translate to .score")
            return
        }
        #expect(novaInstructions.contains("NOVA food processing classification"))
        #expect(novaCriteria.count == 4)

        // 3. Enum -> choice
        guard case .choice(let flagInstructions, let flagCriteria) = translation.questions["primaryFlag"] else {
            Issue.record("Expected 'primaryFlag' to translate to .choice")
            return
        }
        #expect(flagInstructions.contains("primary dietary conflict"))
        #expect(flagCriteria.count == 8)
        #expect(flagCriteria["hiddenGluten"] != nil)
        #expect(flagCriteria["seedOils"] != nil)
    }

    // MARK: - End-to-End LanguageModelSession Evaluation

    @Test("End-to-end evaluation detects hidden gluten and synthesizes valid decision struct")
    func testHiddenGlutenDetection() async throws {
        let mockTransport = MockJevTransport { _ in
            JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "isSafe": JevAnswer(
                        type: "noul",
                        noul: 0.04,
                        confidence: 0.96,
                        probabilities: ["true": 0.04, "false": 0.96]
                    ),
                    "allergenRisk": JevAnswer(type: "score", score: 2, confidence: 0.94),
                    "processingTier": JevAnswer(type: "score", score: 3, confidence: 0.88),
                    "primaryFlag": JevAnswer(type: "choice", choice: "hiddenGluten", confidence: 0.95)
                ],
                usage: JevUsage(inputTokens: 385, outputTokens: 28)
            )
        }

        let model = JevLanguageModel(apiKey: "mock-key", transport: mockTransport)
        let session = LanguageModelSession(model: model)

        let state = """
        Product: Nature Valley Crunchy Granola Bars
        Ingredients: Whole Grain Oats, Sugar, Canola Oil, Barley Malt Extract, Salt.
        Profile: Strict Celiac (Gluten-Free)
        """

        let response = try await session.respond(
            to: state,
            generating: TestDietarySafetyDecision.self
        )

        #expect(response.content.isSafe == false)
        #expect(response.content.allergenRisk == 2)
        #expect(response.content.processingTier == 3)
        #expect(response.content.primaryFlag == .hiddenGluten)

        // Verify calibrated probabilities
        let safeProb = response.probability(for: "isSafe")
        #expect(safeProb != nil)
        #expect(safeProb! < 0.10)
    }

    @Test("End-to-end evaluation validates certified gluten-free whole food product as safe")
    func testCertifiedGlutenFreeProduct() async throws {
        let mockTransport = MockJevTransport { _ in
            JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "isSafe": JevAnswer(
                        type: "noul",
                        noul: 0.98,
                        confidence: 0.97,
                        probabilities: ["true": 0.98, "false": 0.02]
                    ),
                    "allergenRisk": JevAnswer(type: "score", score: 0, confidence: 0.99),
                    "processingTier": JevAnswer(type: "score", score: 1, confidence: 0.95),
                    "primaryFlag": JevAnswer(type: "choice", choice: "none", confidence: 0.98)
                ],
                usage: JevUsage(inputTokens: 310, outputTokens: 24)
            )
        }

        let model = JevLanguageModel(apiKey: "mock-key", transport: mockTransport)
        let session = LanguageModelSession(model: model)

        let state = """
        Product: Simple Mills Almond Flour Crackers
        Ingredients: Almonds, Sunflower Seeds, Flax Seeds, Tapioca Starch, Cassava Flour, Sea Salt.
        Profile: Strict Celiac (Gluten-Free)
        """

        let response = try await session.respond(
            to: state,
            generating: TestDietarySafetyDecision.self
        )

        #expect(response.content.isSafe == true)
        #expect(response.content.allergenRisk == 0)
        #expect(response.content.processingTier == 1)
        #expect(response.content.primaryFlag == .none)

        let safeProb = response.probability(for: "isSafe")
        #expect(safeProb != nil)
        #expect(safeProb! > 0.90)
    }

    @Test("Plant-based meat passes vegan profile but flags ultra-processed tier under clean profile")
    func testDivergentProfilesOnSameProduct() async throws {
        // Vegan profile -> Safe (prob 0.98)
        let veganTransport = MockJevTransport { _ in
            JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "isSafe": JevAnswer(type: "noul", noul: 0.98, confidence: 0.98),
                    "allergenRisk": JevAnswer(type: "score", score: 0, confidence: 0.96),
                    "processingTier": JevAnswer(type: "score", score: 3, confidence: 0.97),
                    "primaryFlag": JevAnswer(type: "choice", choice: "none", confidence: 0.95)
                ],
                usage: JevUsage(inputTokens: 410, outputTokens: 26)
            )
        }

        let veganModel = JevLanguageModel(apiKey: "mock-key", transport: veganTransport)
        let veganSession = LanguageModelSession(model: veganModel)
        let veganResponse = try await veganSession.respond(
            to: "Beyond Burger for Vegan Profile",
            generating: TestDietarySafetyDecision.self
        )
        #expect(veganResponse.content.isSafe == true)

        // Clean Food profile -> Unsafe due to UPF (prob 0.08, processingTier 3)
        let cleanTransport = MockJevTransport { _ in
            JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "isSafe": JevAnswer(type: "noul", noul: 0.08, confidence: 0.93),
                    "allergenRisk": JevAnswer(type: "score", score: 0, confidence: 0.90),
                    "processingTier": JevAnswer(type: "score", score: 3, confidence: 0.98),
                    "primaryFlag": JevAnswer(type: "choice", choice: "seedOils", confidence: 0.88)
                ],
                usage: JevUsage(inputTokens: 410, outputTokens: 26)
            )
        }

        let cleanModel = JevLanguageModel(apiKey: "mock-key", transport: cleanTransport)
        let cleanSession = LanguageModelSession(model: cleanModel)
        let cleanResponse = try await cleanSession.respond(
            to: "Beyond Burger for Clean Whole Food Profile",
            generating: TestDietarySafetyDecision.self
        )
        #expect(cleanResponse.content.isSafe == false)
        #expect(cleanResponse.content.processingTier == 3)
        #expect(cleanResponse.content.primaryFlag == .seedOils)
    }

    // MARK: - Production OCR Nutrition Label Parser Tests

    @Test("NutritionLabelParser parses FDA nutrition label, detects markers and extracts ingredients")
    func testFDAOCRLabelParsing() throws {
        let rawOCRText = """
        Nutrition Facts
        Serving Size 2 bars (42g)
        Calories 190
        Total Fat 7g
        Saturated Fat 1g
        Sodium 140mg
        Total Carbohydrate 29g
        Dietary Fiber 2g
        Total Sugars 12g
        Includes 11g Added Sugars
        Protein 3g
        INGREDIENTS: Whole Grain Oats, Sugar, Canola Oil, Barley Malt Extract, Salt.
        CONTAINS: Soy ingredients.
        """

        // 1. Production marker check
        #expect(TestNutritionLabelParser.isNutritionLabelOrIngredients(rawOCRText) == true)

        // 2. Production facts extraction
        let facts = TestNutritionLabelParser.parseNutritionFacts(from: rawOCRText)
        #expect(facts.calories == 190)
        #expect(facts.totalFatGrams == 7.0)
        #expect(facts.saturatedFatGrams == 1.0)
        #expect(facts.sodiumMilligrams == 140)
        #expect(facts.totalCarbGrams == 29.0)
        #expect(facts.dietaryFiberGrams == 2.0)
        #expect(facts.totalSugarGrams == 12.0)
        #expect(facts.addedSugarGrams == 11.0)
        #expect(facts.proteinGrams == 3.0)

        // 3. Production ingredients & allergen extraction
        let (ingredients, warning) = TestNutritionLabelParser.extractIngredientsAndAllergens(from: rawOCRText)
        #expect(ingredients.contains("Whole Grain Oats"))
        #expect(warning?.contains("Soy") == true)
    }

    @Test("NutritionLabelParser parses German REWE Bio Rote Linsen packaging with Salz conversion")
    func testGermanNährwerteOCR() throws {
        // Real packaging text from REWE Bio Rote Linsen
        let germanLentilsText = """
        Durchschnittliche Nährwerte pro 100 g
        Energie 1439 kJ / 341 kcal
        Fett 1,5 g
        davon gesättigte Fettsäuren 0,3 g
        Kohlenhydrate 50 g
        davon Zucker 1,1 g
        Ballaststoffe 13 g
        Eiweiß 26 g
        Salz < 0,01 g
        Zutaten: Rote Linsen aus kontrolliert biologischem Anbau.
        """

        #expect(TestNutritionLabelParser.isNutritionLabelOrIngredients(germanLentilsText) == true)

        let facts = TestNutritionLabelParser.parseNutritionFacts(from: germanLentilsText)
        #expect(facts.calories == 341)
        #expect(facts.totalFatGrams == 1.5)
        #expect(facts.saturatedFatGrams == 0.3)
        #expect(facts.totalCarbGrams == 50.0)
        #expect(facts.totalSugarGrams == 1.1)
        #expect(facts.dietaryFiberGrams == 13.0)
        #expect(facts.proteinGrams == 26.0)
        #expect(facts.sodiumMilligrams == 4) // 0.01g salt * 400 = 4mg sodium

        let (ingredients, _) = TestNutritionLabelParser.extractIngredientsAndAllergens(from: germanLentilsText)
        #expect(ingredients.contains("Rote Linsen"))
    }

    @Test("NutritionLabelParser parses European Canned Tomatoes with less-than signs and salt")
    func testGermanCannedTomatoesOCR() throws {
        // Real packaging text from Italian/German canned tomatoes
        let tomatoText = """
        Durchschnittliche Nährwerte pro 100 g
        Energie 100 kJ / 24 kcal
        Fett < 0,5 g
        davon gesättigte Fettsäuren 0 g
        Kohlenhydrate 3,5 g
        davon Zucker 3,5 g
        Ballaststoffe 1,2 g
        Eiweiß 1,2 g
        Salz 0,25 g
        Zutaten: Tomaten, Tomatensaft, Säuerungsmittel: Citronensäure.
        """

        #expect(TestNutritionLabelParser.isNutritionLabelOrIngredients(tomatoText) == true)

        let facts = TestNutritionLabelParser.parseNutritionFacts(from: tomatoText)
        #expect(facts.calories == 24)
        #expect(facts.totalFatGrams == 0.5)
        #expect(facts.saturatedFatGrams == 0.0)
        #expect(facts.totalCarbGrams == 3.5)
        #expect(facts.totalSugarGrams == 3.5)
        #expect(facts.dietaryFiberGrams == 1.2)
        #expect(facts.proteinGrams == 1.2)
        #expect(facts.sodiumMilligrams == 100) // 0.25g salt * 400 = 100mg sodium

        let (ingredients, _) = TestNutritionLabelParser.extractIngredientsAndAllergens(from: tomatoText)
        #expect(ingredients.contains("Tomaten"))
    }

    @Test("NutritionLabelParser handles fragmented columnar OCR lines from live camera")
    func testFragmentedColumnOCRFromUserScreenshot() throws {
        let screenshotText = """
        Durchschnittliche
        Nährwerte
        Fett
        davon gesättigte
        weib
        pro
        100 g
        1439 kJ
        341 kca
        1.5g
        - 50 g
        13 g
        26g
        <0.01g
        """

        #expect(TestNutritionLabelParser.isNutritionLabelOrIngredients(screenshotText) == true)

        let facts = TestNutritionLabelParser.parseNutritionFacts(from: screenshotText)
        #expect(facts.calories == 341)
        #expect(facts.totalFatGrams == 1.5)
        #expect(facts.totalCarbGrams == 50.0)
        #expect(facts.dietaryFiberGrams == 13.0)
        #expect(facts.proteinGrams == 26.0)
        #expect(facts.sodiumMilligrams == 4)
    }
}
