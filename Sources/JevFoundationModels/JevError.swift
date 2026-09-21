import Foundation

/// Errors that can occur when executing requests with the Jev decision model.
public enum JevError: LocalizedError, Sendable {
    /// Jev requires a structured @Generable schema; arbitrary text generation is not supported.
    case structuredOutputRequired
    /// The provided schema could not be converted into valid Jev decision questions.
    case invalidSchema(String)
    /// An error returned by the TypeSafe API.
    case apiError(statusCode: Int, message: String)
    /// Network or communication error.
    case networkError(String)
    /// Response parsing or decoding error.
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .structuredOutputRequired:
            return "Jev is a System One decision model and requires a @Generable schema. Free-form text generation is not supported."
        case .invalidSchema(let details):
            return "Failed to convert @Generable schema to Jev questions: \(details)"
        case .apiError(let statusCode, let message):
            return "TypeSafe API returned error \(statusCode): \(message)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .decodingError(let details):
            return "Failed to synthesize or decode response: \(details)"
        }
    }
}
