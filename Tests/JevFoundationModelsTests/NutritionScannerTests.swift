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

    // MARK: - OCR Nutrition Label Parsing Heuristics

    @Test("Nutrition OCR parser extracts calories, carbs, fat, added sugars and protein from label text")
    func testOCRLabelParsing() throws {
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

        let lower = rawOCRText.lowercased()

        // 1. Label detection
        let markers = ["nutrition facts", "calories", "total fat", "protein"]
        let markerCount = markers.filter { lower.contains($0) }.count
        #expect(markerCount >= 3)

        // 2. Calories
        let caloriesRegex = try NSRegularExpression(pattern: #"calories\s*(\d+)"#, options: [.caseInsensitive])
        let nsText = lower as NSString
        let calMatch = caloriesRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(calMatch != nil)
        let calories = Int(nsText.substring(with: calMatch!.range(at: 1)))
        #expect(calories == 190)

        // 3. Added Sugars
        let addedSugarRegex = try NSRegularExpression(pattern: #"(\d+)\s*g?\s*added sugars"#, options: [.caseInsensitive])
        let sugarMatch = addedSugarRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(sugarMatch != nil)
        let addedSugars = Double(nsText.substring(with: sugarMatch!.range(at: 1)))
        #expect(addedSugars == 11.0)
    }

    @Test("Multilingual OCR parser extracts German Nährwerte with comma decimals and converts Salz to Sodium")
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

        let lower = germanLentilsText.lowercased()

        // 1. Detection of German markers
        let germanMarkers = ["durchschnittliche nährwerte", "energie", "fett", "kohlenhydrate", "eiweiß", "salz", "zutaten"]
        let foundCount = germanMarkers.filter { lower.contains($0) }.count
        #expect(foundCount >= 5)

        // 2. Calories extraction from "1439 kJ / 341 kcal"
        let kcalRegex = try NSRegularExpression(pattern: #"(?:/\s*)?(\d+)\s*kcal"#, options: [.caseInsensitive])
        let nsText = lower as NSString
        let kcalMatch = kcalRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(kcalMatch != nil)
        let calories = Int(nsText.substring(with: kcalMatch!.range(at: 1)))
        #expect(calories == 341)

        // 3. Comma decimal extraction for Fat (1,5 g -> 1.5)
        let fatRegex = try NSRegularExpression(pattern: #"(?<!gesättigte[n\s])fett[\s:]*[<>]?\s*([\d,\.]+)"#, options: [.caseInsensitive])
        let fatMatch = fatRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(fatMatch != nil)
        let rawFat = nsText.substring(with: fatMatch!.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        let fat = Double(rawFat)
        #expect(fat == 1.5)

        // 4. Salz conversion to Sodium (< 0,01 g Salz -> 4 mg Sodium)
        let saltRegex = try NSRegularExpression(pattern: #"salz[\s:]*[<>]?\s*([\d,\.]+)\s*g"#, options: [.caseInsensitive])
        let saltMatch = saltRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(saltMatch != nil)
        let rawSalt = nsText.substring(with: saltMatch!.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        let saltGrams = Double(rawSalt)!
        let sodiumMg = Int(saltGrams * 400.0)
        #expect(sodiumMg == 4)
    }

    @Test("Multilingual OCR parser extracts German Canned Tomatoes with < 0,5 g values")
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

        let lower = tomatoText.lowercased()

        // 1. Calories extraction (24 kcal)
        let kcalRegex = try NSRegularExpression(pattern: #"(?:/\s*)?(\d+)\s*kcal"#, options: [.caseInsensitive])
        let nsText = lower as NSString
        let match = kcalRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(match != nil)
        let calories = Int(nsText.substring(with: match!.range(at: 1)))
        #expect(calories == 24)

        // 2. Fat with less-than sign (< 0,5 g -> 0.5)
        let fatRegex = try NSRegularExpression(pattern: #"(?<!gesättigte[n\s])fett[\s:]*[<>]?\s*([\d,\.]+)"#, options: [.caseInsensitive])
        let fatMatch = fatRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(fatMatch != nil)
        let rawFat = nsText.substring(with: fatMatch!.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        let fat = Double(rawFat)
        #expect(fat == 0.5)

        // 3. Salz to Sodium (0,25 g -> 100 mg Sodium)
        let saltRegex = try NSRegularExpression(pattern: #"salz[\s:]*[<>]?\s*([\d,\.]+)\s*g"#, options: [.caseInsensitive])
        let saltMatch = saltRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(saltMatch != nil)
        let rawSalt = nsText.substring(with: saltMatch!.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        let saltGrams = Double(rawSalt)!
        let sodiumMg = Int(saltGrams * 400.0)
        #expect(sodiumMg == 100)
    }

    @Test("Multilingual OCR parser extracts fragmented column OCR text from user screenshot")
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

        let lower = screenshotText.lowercased()

        // 1. Detection of German markers including "weib", "kca", "durchschnittliche"
        let isLabel = lower.contains("durchschnittliche") && lower.contains("nährwerte")
        #expect(isLabel == true)

        // 2. Parse Calories from "341 kca"
        let kcalRegex = try NSRegularExpression(pattern: #"(\d+)\s*kca[l]?"#, options: [.caseInsensitive])
        let nsText = lower as NSString
        let kcalMatch = kcalRegex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        #expect(kcalMatch != nil)
        let calories = Int(nsText.substring(with: kcalMatch!.range(at: 1)))
        #expect(calories == 341)

        // 3. Sequential grams extraction: ["1.5", "50", "13", "26", "0.01"]
        let gramRegex = try NSRegularExpression(pattern: #"[-–<>]?\s*([\d,\.]+)\s*g\b"#, options: [.caseInsensitive])
        let matches = gramRegex.matches(in: lower, options: [], range: NSRange(location: 0, length: nsText.length))
        var values = matches.compactMap { match -> Double? in
            let raw = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
            return Double(raw)
        }
        // Drop the 100g serving size header
        if values.first == 100.0 {
            values.removeFirst()
        }
        #expect(values.count >= 5)
        #expect(values[0] == 1.5) // Fat
        #expect(values[1] == 50.0) // Carbs
        #expect(values[2] == 13.0) // Fiber
        #expect(values[3] == 26.0) // Protein
        #expect(values[4] == 0.01) // Salt
    }
}
