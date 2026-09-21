import Testing
import Foundation
@testable import JevFoundationModels

@Suite("Jev Foundation Models Unit Tests")
struct JevFoundationModelsTests {

    @Test("JevRequest JSON encoding matches TypeSafe API format")
    func testRequestEncoding() throws {
        let request = JevRequest(
            state: "I was double charged on my receipt.",
            model: "jev-latest",
            questions: [
                "is_urgent": .noul(instructions: "Is this urgent?"),
                "department": .choice(
                    instructions: "Which team handles this?",
                    criteria: ["billing": "Invoices and charges", "sales": "Pricing"]
                ),
                "frustration": .score(
                    instructions: "Frustration level",
                    criteria: ["Calm", "Upset"]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"type\":\"noul\""))
        #expect(json.contains("\"type\":\"choice\""))
        #expect(json.contains("\"type\":\"score\""))
        #expect(json.contains("\"billing\":\"Invoices and charges\""))
    }

    @Test("JevResponse decodes answers and probabilities accurately")
    func testResponseDecoding() throws {
        let sampleJSON = """
        {
          "model": "jev-1.13.0",
          "answers": {
            "is_urgent": {
              "type": "noul",
              "noul": 0.95
            },
            "department": {
              "type": "choice",
              "choice": "billing",
              "confidence": 0.98,
              "probabilities": {
                "billing": 0.98,
                "sales": 0.02
              }
            }
          },
          "usage": {
            "input_tokens": 120,
            "output_tokens": 25
          }
        }
        """

        let decoder = JSONDecoder()
        let response = try decoder.decode(JevResponse.self, from: Data(sampleJSON.utf8))

        #expect(response.model == "jev-1.13.0")
        #expect(response.answers["is_urgent"]?.noul == 0.95)
        #expect(response.answers["department"]?.choice == "billing")
        #expect(response.answers["department"]?.confidence == 0.98)
        #expect(response.usage?.inputTokens == 120)
        #expect(response.usage?.outputTokens == 25)
    }

    @Test("JevLanguageModel capability configuration conforms to System One expectations")
    func testModelCapabilities() {
        let model = JevLanguageModel(apiKey: "test-api-key")
        #expect(model.capabilities.supportsStructuredOutput == true)
        #expect(model.capabilities.supportsTools == false)
        #expect(model.executorConfiguration.apiKey == "test-api-key")
        #expect(model.executorConfiguration.modelID == "jev-latest")
    }
}
