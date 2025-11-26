//
//  SpamClassifier.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//


import Foundation
import TensorFlowLite

final class SpamClassifier {
    private var interpreter: Interpreter?
    private var tokenizer: WordPieceTokenizer?
    private let maxSequenceLength = 128

    init?(modelName: String, vocabFile: String) {
        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "tflite"),
              let vocabURL = Bundle.main.url(forResource: vocabFile, withExtension: "txt"),
              let tokenizer = WordPieceTokenizer(vocabFile: vocabURL) else {
            print("❌ Model or vocab not found.")
            return nil
        }

        self.tokenizer = tokenizer
        do {
            self.interpreter = try Interpreter(modelPath: modelPath)
            try self.interpreter?.allocateTensors()
        } catch {
            print("❌ Failed to initialize interpreter: \(error)")
            return nil
        }
    }

    func classify(_ message: String) -> (MessageCategory, [Float])? {
        guard let interpreter, let tokenizer else { return nil }

        var tokens = tokenizer.tokenize(message)
        tokens = ["[CLS]"] + tokens + ["[SEP]"]
        var inputIds = tokenizer.convertTokensToIds(tokens)
        var attentionMask = [Int32](repeating: 1, count: inputIds.count)

        inputIds = Array(inputIds.prefix(maxSequenceLength)) + Array(repeating: 0, count: max(0, maxSequenceLength - inputIds.count))
        attentionMask = Array(attentionMask.prefix(maxSequenceLength)) + Array(repeating: 0, count: max(0, maxSequenceLength - attentionMask.count))

        do {
            let inputIdData = inputIds.withUnsafeBufferPointer { Data(buffer: $0) }
            let attentionMaskData = attentionMask.withUnsafeBufferPointer { Data(buffer: $0) }

            try interpreter.copy(inputIdData, toInputAt: 0)
            try interpreter.copy(attentionMaskData, toInputAt: 1)

            try interpreter.invoke()

            let output = try interpreter.output(at: 0)
            let logits = [Float](unsafeData: output.data, as: Float.self) ?? []
            let probs = softmax(logits)
            let predictedIndex = probs.firstIndex(of: probs.max() ?? 0) ?? 0
            let category: MessageCategory = predictedIndex == 0 ? .ham : .spam

            return (category, probs)
        } catch {
            print("❌ Inference error: \(error)")
            return nil
        }
    }

    private func softmax(_ logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { exp($0 - maxLogit) }
        let sumExps = exps.reduce(0, +)
        return exps.map { $0 / sumExps }
    }
}
