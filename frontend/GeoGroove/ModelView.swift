//
//  ModelView.swift
//  GeoGroove
//
//  Created by Alex on 02/11/2025.
//

import SwiftUI
import CoreML
import CoreLocation
import Tokenizers

struct ModelView: View {
    @State private var inputLocation: String = "Leeds City Centre"
    @State private var summary: String = ""
    @State private var suggestedSong: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.purple)
                
                Text("Local ML Model")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("On-device text summarization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Input Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Location Description")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Enter location name", text: $inputLocation)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            
            // Run Model Button
            Button(action: {
                runLocalSummarizer(with: "Describe \(inputLocation)")
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isProcessing ? "Processing..." : "Run Model")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(isProcessing || inputLocation.isEmpty)
            .padding(.horizontal, 20)
            
            // Results Section
            if !summary.isEmpty || !errorMessage.isEmpty {
                VStack(spacing: 16) {
                    if !errorMessage.isEmpty {
                        // Error Display
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        // Summary Display
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.purple)
                                Text("Summary")
                                    .font(.headline)
                            }
                            
                            Text(summary)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        // Song Suggestion Display
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue)
                                Text("Suggested Song")
                                    .font(.headline)
                            }
                            
                            Text(suggestedSong)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.06),
                    Color.blue.opacity(0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle("ML Model")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Local Summarizer Function
    private func runLocalSummarizer(with text: String) {
        isProcessing = true
        errorMessage = ""
        summary = ""
        suggestedSong = ""
        
        Task {
            do {
                // 1️⃣ Load the tokenizer
                guard let tokenizer = await loadTokenizer() else {
                    throw NSError(domain: "TokenizerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "tokenizer.json not found in bundle. Please add the tokenizer file."])
                }
                
                // 2️⃣ Load the model
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly
                let model = try LocalSummarizer(configuration: config)
                
                // 3️⃣ Tokenize input text using the real tokenizer
                let tokens: [Int32] = tokenize(text, tokenizer: tokenizer)
                
                guard !tokens.isEmpty else {
                    throw NSError(domain: "TokenizerError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Tokenization failed - empty token array"])
                }
                
                // 4️⃣ Create MLMultiArray for input (2D array with shape [1, sequence_length])
                let inputArray = try makeInputArray(tokens)
                
                // 5️⃣ Run prediction using the generated LocalSummarizerInput
                let input = LocalSummarizerInput(input_ids: inputArray)
                let output = try await model.prediction(input: input)
                
                // 6️⃣ Decode output tokens using the real tokenizer
                // Try to get the output - it might be named differently in your model
                guard let outputTokens = (output.featureValue(for: "output_ids") ?? 
                                          output.featureValue(for: "output") ?? 
                                          output.featureValue(for: "logits"))?.multiArrayValue else {
                    throw NSError(domain: "ModelError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not extract output from model. Check the model's output feature name."])
                }
                
                let decodedSummary = decodeTokens(outputTokens, tokenizer: tokenizer)
                
                // 7️⃣ Pick a song for the summary
                let song = songForSummary(decodedSummary)
                
                DispatchQueue.main.async {
                    self.summary = decodedSummary
                    self.suggestedSong = song
                    self.isProcessing = false
                    print("📝 Summary: \(decodedSummary)")
                    print("🎵 Suggested song: \(song)")
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                    print("❌ Error running model: \(error)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModelView()
    }
}
