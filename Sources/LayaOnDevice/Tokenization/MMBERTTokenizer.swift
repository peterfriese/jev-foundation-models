import Foundation

/// A native Swift tokenizer for mmBERT multilingual backbones (`laya-multilingual` 322M).
///
/// Supports 100+ languages using a 256k token vocabulary based on SentencePiece unigram/BPE.
/// See `tech-notes/0007-on-device-coreml-decision-engine.md`.
public struct MMBERTTokenizer: LayaTokenizer, Sendable {
    public let clsTokenId: Int
    public let sepTokenId: Int
    public let padTokenId: Int
    public let maskTokenId: Int
    public let maskToken: String

    private let vocab: [String: Int]
    private let invVocab: [Int: String]
    private let unkTokenId: Int

    public init(
        vocab: [String: Int],
        clsTokenId: Int = 2,
        sepTokenId: Int = 1,
        padTokenId: Int = 0,
        maskTokenId: Int = 4,
        maskToken: String = "<mask_1>",
        unkTokenId: Int = 3
    ) {
        self.vocab = vocab
        var inverse: [Int: String] = [:]
        for (k, v) in vocab {
            inverse[v] = k
        }
        self.invVocab = inverse
        self.clsTokenId = clsTokenId
        self.sepTokenId = sepTokenId
        self.padTokenId = padTokenId
        self.maskTokenId = maskTokenId
        self.maskToken = maskToken
        self.unkTokenId = unkTokenId
    }

    /// Initializes a tokenizer by loading a Hugging Face `tokenizer.json` file.
    public init(jsonURL: URL) throws {
        let data = try Data(contentsOf: jsonURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = root["model"] as? [String: Any],
              let vocabDict = model["vocab"] as? [String: Int] else {
            throw NSError(domain: "MMBERTTokenizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid tokenizer.json"])
        }
        self.init(vocab: vocabDict)
    }

    /// Creates a default tokenizer with fallback multilingual tokens for testing.
    public static func defaultTokenizer() -> MMBERTTokenizer {
        var sampleVocab: [String: Int] = [
            "<pad>": 0,
            "<eos>": 1,
            "<bos>": 2,
            "<unk>": 3,
            "<mask_1>": 4,
            "choice": 10,
            "score": 11,
            "noul": 12,
            "question:": 13,
            "true": 14,
            "false": 15,
            "level": 16
        ]
        for code in 32...126 {
            let charStr = String(UnicodeScalar(code)!)
            if sampleVocab[charStr] == nil {
                sampleVocab[charStr] = code + 1000
            }
        }
        return MMBERTTokenizer(vocab: sampleVocab)
    }

    public func encode(_ text: String, addSpecialTokens: Bool = false) -> [Int] {
        var tokenIds: [Int] = []
        if addSpecialTokens {
            tokenIds.append(clsTokenId)
        }

        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for word in words {
            if let direct = vocab[word] {
                tokenIds.append(direct)
            } else {
                for char in word {
                    let s = String(char)
                    tokenIds.append(vocab[s] ?? unkTokenId)
                }
            }
        }

        if addSpecialTokens {
            tokenIds.append(sepTokenId)
        }
        return tokenIds
    }

    public func decode(_ tokens: [Int]) -> String {
        let pieces = tokens.compactMap { invVocab[$0] }
        return pieces.joined(separator: " ")
    }
}
