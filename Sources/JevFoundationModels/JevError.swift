import Foundation

// See tech-notes/0006-http-resilience-and-confidence-routing.md

/// Errors that can occur when executing requests with the Jev decision model.
///
/// - Important: `CancellationError` is never wrapped in `JevError` and always propagates cleanly across concurrency boundaries.
public enum JevError: LocalizedError, Sendable, Equatable, Hashable {
    // MARK: - Foundation Models & Schema

    /// Jev requires a structured @Generable schema; arbitrary text generation is not supported.
    case structuredOutputRequired

    /// The provided schema could not be converted into valid Jev decision questions.
    case invalidSchema(String)

    // MARK: - HTTP & Transport Resilience

    /// 401 Unauthorized. The API key is missing or invalid. Never retried.
    case unauthorized

    /// 422 Unprocessable Content. The request failed server validation (e.g. state exceeds token context limit). Never retried.
    case invalidRequest(body: String)

    /// 429 Too Many Requests, after the retry policy was exhausted.
    case rateLimited(retryAfter: Duration?)

    /// 529 Site Overloaded, after the retry policy was exhausted.
    case overloaded

    /// An unhandled HTTP status code returned by the server.
    case apiError(statusCode: Int, message: String)

    /// A transport failure during network communication. Note that `CancellationError` is never wrapped.
    case transport(String)

    /// Backwards-compatible network error case.
    case networkError(String)

    // MARK: - Answer Mapping & Decoding

    /// The response has no answer for the requested question.
    case missingAnswer(question: String)

    /// The question returned an answer type that does not match the expected primitive.
    case answerTypeMismatch(question: String, expected: String, actual: String)

    /// The model selected a categorical choice that is not present in the options enum.
    case unrecognizedChoice(question: String, value: String, expected: [String])

    /// Response parsing or JSON decoding failure.
    case decodingError(String)

    /// Malformed response shape received from the server.
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case .structuredOutputRequired:
            return "Jev is a System One decision model and requires a @Generable schema. Free-form text generation is not supported."
        case .invalidSchema(let details):
            return "Failed to convert @Generable schema to Jev questions: \(details)"
        case .unauthorized:
            return "401: The TypeSafe AI API key is missing or invalid."
        case .invalidRequest(let body):
            return "422: The request failed server validation — \(body)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "429: Rate limited by TypeSafe AI gateway (retry after \(retryAfter))."
            } else {
                return "429: Rate limited by TypeSafe AI gateway."
            }
        case .overloaded:
            return "529: The TypeSafe AI decision engine is temporarily overloaded."
        case .apiError(let statusCode, let message):
            return "TypeSafe API returned HTTP \(statusCode): \(message)"
        case .transport(let details):
            return "Transport error: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .missingAnswer(let question):
            return "Response is missing an answer for question '\(question)'."
        case .answerTypeMismatch(let question, let expected, let actual):
            return "Question '\(question)' expected answer type '\(expected)', but received '\(actual)'."
        case .unrecognizedChoice(let question, let value, let expected):
            return "Question '\(question)' selected choice '\(value)', which is not in \(expected)."
        case .decodingError(let details):
            return "Failed to synthesize or decode response: \(details)"
        case .malformedResponse(let details):
            return "Malformed response received from TypeSafe API: \(details)"
        }
    }
}
