//
//  ModelHelpers.swift
//  GeoGroove
//
//  Created by Alex on 02/11/2025.
//

import Foundation
import CoreML
import Tokenizers

func loadTokenizer() async -> Tokenizer? {
    
    if let resourcePath = Bundle.main.resourcePath {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            print("📦 Bundle contents:", contents)
        } catch {
            print("❌ Failed to list bundle contents:", error)
        }
    }
    
    //guard let tokenizerDir = Bundle.main.url(forResource: "phi-3-mini-4k-instruct", withExtension: nil, subdirectory: "Tokenizers") else {
     //   print("⚠️ tokenizer directory not found in bundle")
     //   return nil
    //}

    do {
        //let tokenizer = try await AutoTokenizer.from(pretrained: tokenizerDir.path)
        let tokenizer = try await AutoTokenizer.from(pretrained: "microsoft/Phi-3-mini-4k-instruct")
        return tokenizer
    } catch {
        print("❌ Failed to load tokenizer: \(error)")
        return nil
    }
}

func makeInputArray(_ tokens: [Int32]) throws -> MLMultiArray {
    // Batch size 1, sequence length = tokens.count
    let array = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)

    for (i, token) in tokens.enumerated() {
        array[[0, i] as [NSNumber]] = NSNumber(value: token)
    }

    return array
}

// MARK: - Tokenization
func tokenize(_ text: String, tokenizer: Tokenizer) -> [Int32] {
    do {
        // Encode text into token IDs
        let tokenIDs = try tokenizer.encode(text: text) // Usually [Int]
        
        // Convert [Int] → [Int32]
        let tokenIDs32 = tokenIDs.map { Int32($0) }
        
        return tokenIDs32
    } catch {
        print("❌ Tokenization error: \(error)")
        return []
    }
}

// MARK: - Token Decoding
func decodeTokens(_ array: MLMultiArray, tokenizer: Tokenizer) -> String {
    do {
        let ids = (0..<array.count).map { Int(array[$0].int32Value) }
        return try tokenizer.decode(tokens: ids)
    } catch {
        print("❌ Decoding error: \(error)")
        return "Error decoding tokens"
    }
}

// MARK: - Song Selection from Summary
func songForSummary(_ summary: String) -> String {
    let lowercasedSummary = summary.lowercased()
    
    if lowercasedSummary.contains("park") {
        return "Walking on Sunshine"
    }
    if lowercasedSummary.contains("beach") {
        return "Ocean Eyes"
    }
    if lowercasedSummary.contains("city") || lowercasedSummary.contains("downtown") {
        return "City of Stars"
    }
    if lowercasedSummary.contains("quiet") || lowercasedSummary.contains("peaceful") {
        return "Weightless"
    }
    if lowercasedSummary.contains("lively") || lowercasedSummary.contains("music") {
        return "Uptown Funk"
    }
    
    return "Default Tune"
}
