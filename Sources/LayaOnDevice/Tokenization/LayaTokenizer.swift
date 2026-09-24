import Foundation

/// A tokenizer protocol providing encoding, decoding, and special token properties for Laya backbones.
public protocol LayaTokenizer: Sendable {
    /// Token ID for `[CLS]` or beginning-of-sequence token.
    var clsTokenId: Int { get }
    /// Token ID for `[SEP]` or end-of-sequence token.
    var sepTokenId: Int { get }
    /// Token ID for `[PAD]` token.
    var padTokenId: Int { get }
    /// Token ID for `[MASK]` token.
    var maskTokenId: Int { get }
    /// The string representation of the mask token (e.g. `"[MASK]"` or `"<mask_1>"`).
    var maskToken: String { get }

    /// Encodes text into an array of token IDs.
    func encode(_ text: String, addSpecialTokens: Bool) -> [Int]

    /// Decodes an array of token IDs back into a string.
    func decode(_ tokens: [Int]) -> String
}

extension LayaTokenizer {
    public func encode(_ text: String) -> [Int] {
        encode(text, addSpecialTokens: false)
    }
}
