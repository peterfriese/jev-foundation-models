import Testing
import Foundation
@testable import JevFoundationModels

@Suite("Domain Values & Confidence Routing Tests")
struct ValuesAndRoutingTests {

    // MARK: - Probability Tests

    @Test("Probability clamps values into 0...1 and computes decisiveness correctly")
    func testProbabilityBasics() {
        let pHigh = Probability(clamping: 1.5)
        #expect(pHigh.value == 1.0)
        #expect(pHigh.decisiveness == 1.0)

        let pLow = Probability(clamping: -0.2)
        #expect(pLow.value == 0.0)
        #expect(pLow.decisiveness == 1.0)

        let pMid = Probability(clamping: 0.5)
        #expect(pMid.value == 0.5)
        #expect(pMid.decisiveness == 0.5)

        let pNo = Probability(clamping: 0.05)
        #expect(pNo.decisiveness == 0.95)

        let pYes = Probability(clamping: 0.95)
        #expect(pYes.decisiveness == 0.95)
    }

    @Test("Probability exact initializer rejects out-of-range values and NaN")
    func testProbabilityExactInit() {
        #expect(Probability(exactly: 0.5) != nil)
        #expect(Probability(exactly: 0.0) != nil)
        #expect(Probability(exactly: 1.0) != nil)
        #expect(Probability(exactly: 1.001) == nil)
        #expect(Probability(exactly: -0.001) == nil)
        #expect(Probability(exactly: Double.nan) == nil)
    }

    @Test("Probability Codable roundtrip and corruption handling")
    func testProbabilityCodable() throws {
        let original = Probability(clamping: 0.88)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Probability.self, from: data)
        #expect(decoded == original)

        let invalidJSON = Data("1.5".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Probability.self, from: invalidJSON)
        }
    }

    // MARK: - ScoreValue Tests

    @Test("ScoreValue computes rounded level and normalized score correctly")
    func testScoreValueCalculations() {
        // 3-level rubric (0, 1, 2)
        let score = ScoreValue(
            value: 1.6,
            legend: [0: "Low", 1: "Medium", 2: "High"],
            probabilities: [0: 0.05, 1: 0.30, 2: 0.65],
            confidence: 0.78
        )

        #expect(score.rounded == 2)
        #expect(score.normalized == 0.8) // 1.6 / (3 - 1) = 0.8
        #expect(score.confidence == 0.78)

        // Single level score cannot normalize (divide by zero protection)
        let singleLevel = ScoreValue(value: 0.5, legend: [0: "Single"], probabilities: [0: 1.0])
        #expect(singleLevel.normalized == nil)
    }

    @Test("ScoreValue Codable encodes and decodes accurately")
    func testScoreValueCodable() throws {
        let original = ScoreValue(
            value: 2.3,
            legend: [0: "P0", 1: "P1", 2: "P2", 3: "P3"],
            probabilities: [0: 0.02, 1: 0.08, 2: 0.70, 3: 0.20],
            confidence: 0.85
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScoreValue.self, from: data)

        #expect(decoded.value == 2.3)
        #expect(decoded.rounded == 2)
        #expect(decoded.normalized != nil)
        #expect(decoded.confidence == 0.85)
        #expect(decoded.legend[0] == "P0")
        #expect(decoded.probabilities[2] == 0.70)
    }

    @Test("ScoreValue telemetry remaps zero-based score indices into integer rubric ranges")
    func testScoreValueTelemetryForNonZeroBasedIntegerRange() throws {
        let synthesizer = ResponseSynthesizer()
        let layout = SchemaRootLayout.object(
            properties: [
                "priority": SchemaPropertyDescriptor(
                    name: "priority",
                    questionKey: "priority",
                    kind: .score(minimum: 1, maximum: 5, isInteger: true),
                    instructions: "Priority"
                )
            ],
            propertyOrder: ["priority"]
        )
        let answers = [
            "priority": JevAnswer(
                type: "score",
                score: 2.0,
                confidence: 0.9,
                probabilities: ["0": 0.05, "1": 0.10, "2": 0.70, "3": 0.10, "4": 0.05],
                legend: ["0": "P1", "1": "P2", "2": "P3", "3": "P4", "4": "P5"]
            )
        ]

        let json = try #require(synthesizer.extractScoresJSON(from: answers, layout: layout))
        let decoded = try JSONDecoder().decode([String: ScoreValue].self, from: Data(json.utf8))
        let score = try #require(decoded["priority"])

        #expect(score.value == 3.0)
        #expect(score.rounded == 3)
        #expect(score.legend[3] == "P3")
        #expect(score.probabilities[3] == 0.70)
    }

    // MARK: - RoutingPolicy: Choice & Score Tests

    @Test("RoutingPolicy maps confidence to decisions at calibrated thresholds")
    func testChoiceRoutingThresholds() {
        let policy = RoutingPolicy.default

        #expect(policy.decide(confidence: 0.0) == .escalate)
        #expect(policy.decide(confidence: 0.59) == .escalate)
        #expect(policy.decide(confidence: 0.60) == .confirm)
        #expect(policy.decide(confidence: 0.84) == .confirm)
        #expect(policy.decide(confidence: 0.85) == .auto)
        #expect(policy.decide(confidence: 1.00) == .auto)

        // Missing or unanswered question must safely escalate
        #expect(policy.decide(confidence: nil) == .escalate)
    }

    // MARK: - RoutingPolicy: Noul Tests

    @Test("Noul inside undecided band (0.35...0.65) returns nil answer and escalates")
    func testNoulUndecidedBand() {
        let policy = RoutingPolicy.default

        for p in [0.35, 0.45, 0.50, 0.55, 0.65] {
            let judgement = policy.decide(Probability(clamping: p))
            #expect(judgement.answer == nil)
            #expect(judgement.decision == .escalate)
        }
    }

    @Test("Noul confident Yes and confident No both resolve to .auto")
    func testNoulDecisiveJudgements() {
        let policy = RoutingPolicy.default

        // Confident Yes: p = 0.95 -> decisiveness = 0.95 -> .auto, answer = true
        let yesJudgement = policy.decide(Probability(clamping: 0.95))
        #expect(yesJudgement.answer == true)
        #expect(yesJudgement.decision == .auto)
        #expect(yesJudgement.decisiveness == 0.95)

        // Confident No: p = 0.05 -> decisiveness = 0.95 -> .auto, answer = false
        let noJudgement = policy.decide(Probability(clamping: 0.05))
        #expect(noJudgement.answer == false)
        #expect(noJudgement.decision == .auto)
        #expect(noJudgement.decisiveness == 0.95)
    }

    @Test("Noul leaning answers outside undecided band resolve to .confirm")
    func testNoulLeaningJudgements() {
        let policy = RoutingPolicy.default

        // Leaning Yes: p = 0.75 -> decisiveness = 0.75 (>= 0.60 and < 0.85) -> .confirm
        let leaningYes = policy.decide(Probability(clamping: 0.75))
        #expect(leaningYes.answer == true)
        #expect(leaningYes.decision == .confirm)

        // Leaning No: p = 0.25 -> decisiveness = 0.75 -> .confirm
        let leaningNo = policy.decide(Probability(clamping: 0.25))
        #expect(leaningNo.answer == false)
        #expect(leaningNo.decision == .confirm)
    }

    @Test("Missing noul probability safely escalates")
    func testMissingNoulProbabilityEscalates() {
        let policy = RoutingPolicy.default
        let judgement = policy.decide(nil as Probability?)
        #expect(judgement.answer == nil)
        #expect(judgement.decisiveness == 0.0)
        #expect(judgement.decision == .escalate)
    }

    // MARK: - Enriched JevError Taxonomy Tests

    @Test("JevError remains Equatable and preserves HTTP diagnostics")
    func testJevErrorDiagnostics() {
        let err401 = JevError.apiError(statusCode: 401, message: "Invalid API key")
        #expect(err401.localizedDescription.contains("401"))
        #expect(err401 == JevError.apiError(statusCode: 401, message: "Invalid API key"))

        let err429 = JevError.apiError(statusCode: 429, message: "Rate limited (retry after 5 seconds)")
        #expect(err429.localizedDescription.contains("429"))

        let networkError = JevError.networkError("connection lost")
        #expect(networkError.localizedDescription.contains("Network error"))
    }
}
