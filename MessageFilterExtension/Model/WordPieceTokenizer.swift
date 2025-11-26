//
//  WordPieceTokenizer.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//


import Foundation

final class WordPieceTokenizer {
    private let vocab: [String: Int32]
    private let unkToken = "[UNK]"
    private let maxInputCharsPerWord = 100

    /// Initializes the tokenizer using a vocabulary file URL.
    init?(vocabFile: URL) {
        guard let contents = try? String(contentsOf: vocabFile) else { return nil }

        var vocabDict: [String: Int32] = [:]
        let lines = contents.components(separatedBy: .newlines)
        for (i, token) in lines.enumerated() where !token.isEmpty {
            vocabDict[token] = Int32(i)
        }

        self.vocab = vocabDict
    }

    /// Tokenizes input text into WordPiece tokens.
    func tokenize(_ text: String) -> [String] {
        let lowercasedText = text.lowercased()
        let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines)
        var outputTokens: [String] = []

        for word in words {
            guard !word.isEmpty else { continue }

            if word.count > maxInputCharsPerWord {
                outputTokens.append(unkToken)
                continue
            }

            var start = 0
            var subTokens: [String] = []

            while start < word.count {
                var end = word.count
                var currSubstring: String?

                while start < end {
                    let range = word.index(word.startIndex, offsetBy: start)..<word.index(word.startIndex, offsetBy: end)
                    var substring = String(word[range])
                    if start > 0 { substring = "##" + substring }

                    if vocab[substring] != nil {
                        currSubstring = substring
                        break
                    }

                    end -= 1
                }

                if let substr = currSubstring {
                    subTokens.append(substr)
                    start += substr.replacingOccurrences(of: "##", with: "").count
                } else {
                    subTokens = [unkToken]
                    break
                }
            }

            outputTokens.append(contentsOf: subTokens)
        }

        return outputTokens
    }

    /// Converts WordPiece tokens into vocabulary IDs.
    func convertTokensToIds(_ tokens: [String]) -> [Int32] {
        return tokens.map { vocab[$0] ?? vocab[unkToken]! }
    }
}
