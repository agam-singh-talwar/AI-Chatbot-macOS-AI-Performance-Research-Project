//
//  OllamaService.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import Foundation
import Combine

/// Service for communicating with Ollama API for local AI inference
class OllamaService: ObservableObject {
    
    // MARK: - Configuration
    private let baseURL = "http://localhost:11434"
    private let defaultModel = "phi3:mini"
    
    // MARK: - Available Models
    static let recommendedModels = [
        AIModel(name: "phi3:mini", displayName: "Phi-3 Mini", size: "2.4GB", description: "Microsoft's efficient small model, great for on-device"),
        AIModel(name: "tinyllama:latest", displayName: "TinyLlama", size: "637MB", description: "Ultra-lightweight, fastest inference"),
    ]
    
    // MARK: - Properties
    @Published var isConnected: Bool = false
    @Published var availableModels: [AIModel] = []
    @Published var currentModel: String = "phi3:mini"
    @Published var isGenerating: Bool = false
    
    private var urlSession: URLSession
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        self.urlSession = URLSession(configuration: config)
        
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Connection Management
    @MainActor
    func checkConnection() async {
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isConnected = true
                await parseAvailableModels(from: data)
            } else {
                isConnected = false
            }
        } catch {
            print("Ollama connection failed: \(error.localizedDescription)")
            isConnected = false
        }
    }
    
    private func parseAvailableModels(from data: Data) async {
        do {
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            await MainActor.run {
                self.availableModels = response.models.map { model in
                    AIModel(
                        name: model.name,
                        displayName: model.name,
                        size: formatModelSize(model.size),
                        description: "Local model"
                    )
                }
            }
        } catch {
            print("Failed to parse models: \(error)")
        }
    }
    
    private func formatModelSize(_ sizeInBytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: sizeInBytes)
    }
    
    // MARK: - AI Inference Methods
    
    /// Sequential (blocking) inference - returns complete response at once
    func generateSequential(prompt: String, model: String? = nil) async throws -> (response: String, metrics: PerformanceMetrics) {
        let metricsCollector = await PerformanceMetricsCollector()
        await metricsCollector.startCollection()
        
        let modelToUse = model ?? currentModel
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let requestBody = OllamaRequest(
                model: modelToUse,
                prompt: prompt,
                stream: false,
                options: OllamaOptions(temperature: 0.7, top_p: 0.9)
            )
            
            let url = URL(string: "\(baseURL)/api/generate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, _) = try await urlSession.data(for: request)
            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            
            let tokenCount = estimateTokenCount(response.response)
            await metricsCollector.recordFirstToken()
            for _ in 0..<tokenCount {
                await metricsCollector.recordToken()
            }
            
            let metrics = await metricsCollector.finishCollection(
                tokenCount: tokenCount,
                executionMode: .sequential,
                modelName: modelToUse
            )
            
            return (response.response, metrics)
            
        } catch {
            await metricsCollector.recordError()
            let errorMetrics = await metricsCollector.finishCollection(
                tokenCount: 0,
                executionMode: .sequential,
                modelName: modelToUse
            )
            throw OllamaError.networkError(error.localizedDescription)
        }
    }
    
    /// Streaming inference - returns tokens as they're generated
    func generateStreaming(prompt: String, model: String? = nil) -> AsyncThrowingStream<StreamingResponse, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                let metricsCollector = await PerformanceMetricsCollector()
                await metricsCollector.startCollection()
                
                let modelToUse = model ?? currentModel
                await MainActor.run { isGenerating = true }
                defer { Task { await MainActor.run { isGenerating = false } } }
                
                do {
                    let requestBody = OllamaRequest(
                        model: modelToUse,
                        prompt: prompt,
                        stream: true,
                        options: OllamaOptions(temperature: 0.7, top_p: 0.9)
                    )
                    
                    let url = URL(string: "\(baseURL)/api/generate")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (asyncBytes, _) = try await urlSession.bytes(for: request)
                    
                    var fullResponse = ""
                    var tokenCount = 0
                    var firstToken = true
                    
                    for try await line in asyncBytes.lines {
                        if !line.isEmpty {
                            if let data = line.data(using: .utf8),
                               let response = try? JSONDecoder().decode(OllamaStreamResponse.self, from: data) {
                                
                                if firstToken {
                                    await metricsCollector.recordFirstToken()
                                    firstToken = false
                                }
                                
                                fullResponse += response.response
                                tokenCount += 1
                                await metricsCollector.recordToken()
                                
                                let streamResponse = StreamingResponse(
                                    token: response.response,
                                    fullResponse: fullResponse,
                                    isComplete: response.done,
                                    tokenCount: tokenCount
                                )
                                
                                continuation.yield(streamResponse)
                                
                                if response.done {
                                    let metrics = await metricsCollector.finishCollection(
                                        tokenCount: tokenCount,
                                        executionMode: .sequential,
                                        modelName: modelToUse
                                    )
                                    
                                    continuation.yield(StreamingResponse(
                                        token: "",
                                        fullResponse: fullResponse,
                                        isComplete: true,
                                        tokenCount: tokenCount,
                                        metrics: metrics
                                    ))
                                    break
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    await metricsCollector.recordError()
                    continuation.finish(throwing: OllamaError.networkError(error.localizedDescription))
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Parallel inference with parallel text processing algorithm
    func generateParallel(prompt: String, model: String? = nil) async throws -> (response: String, metrics: PerformanceMetrics) {
        let metricsCollector = await PerformanceMetricsCollector()
        await metricsCollector.startCollection()
        
        let modelToUse = model ?? currentModel
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // First, get the AI response using sequential method
            let requestBody = OllamaRequest(
                model: modelToUse,
                prompt: prompt,
                stream: false,
                options: OllamaOptions(temperature: 0.7, top_p: 0.9)
            )
            
            let url = URL(string: "\(baseURL)/api/generate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, _) = try await urlSession.data(for: request)
            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            
            await metricsCollector.recordFirstToken()
            
            // CORE PARALLEL ALGORITHM: Parallel Text Analysis
            let processedResponse = try await processTextInParallel(response.response)
            
            let tokenCount = estimateTokenCount(processedResponse)
            for _ in 0..<tokenCount {
                await metricsCollector.recordToken()
            }
            
            let metrics = await metricsCollector.finishCollection(
                tokenCount: tokenCount,
                executionMode: .parallel,
                modelName: modelToUse
            )
            
            return (processedResponse, metrics)
            
        } catch {
            await metricsCollector.recordError()
            let errorMetrics = await metricsCollector.finishCollection(
                tokenCount: 0,
                executionMode: .parallel,
                modelName: modelToUse
            )
            throw OllamaError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Parallel Text Processing Algorithm
    
    /// Core parallel algorithm: Parallel word frequency analysis and text enhancement
    /// This demonstrates data parallelism by processing text chunks concurrently
    private func processTextInParallel(_ text: String) async throws -> String {
        // Split text into chunks for parallel processing
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let processorCount = ProcessInfo.processInfo.processorCount
        let chunkSize = max(words.count / processorCount, 1)
        
        // Create chunks for parallel processing
        var chunks: [[String]] = []
        for i in stride(from: 0, to: words.count, by: chunkSize) {
            let end = min(i + chunkSize, words.count)
            chunks.append(Array(words[i..<end]))
        }
        
        // Process chunks in parallel using TaskGroup
        let processedChunks = try await withThrowingTaskGroup(of: ProcessedChunk.self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask {
                    return await self.processTextChunk(chunk, chunkIndex: index)
                }
            }
            
            var results: [ProcessedChunk] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by original chunk index to maintain order
            return results.sorted { $0.chunkIndex < $1.chunkIndex }
        }
        
        // Combine results and add parallel processing summary
        let processedText = processedChunks.map { $0.processedText }.joined(separator: " ")
        let totalWordCount = processedChunks.reduce(0) { $0 + $1.wordCount }
        let totalUniqueWords = processedChunks.reduce(0) { $0 + $1.uniqueWords }
        let avgWordsPerChunk = totalWordCount / max(chunks.count, 1)
        
        return processedText + "\n\n📊 **Parallel Processing Analysis:**\n" +
               "• Processed using \(chunks.count) parallel tasks\n" +
               "• Total words: \(totalWordCount)\n" +
               "• Unique words: \(totalUniqueWords)\n" +
               "• Average words per chunk: \(avgWordsPerChunk)\n"
    }
    
    /// Process a single chunk of text (individual parallel task)
    private func processTextChunk(_ words: [String], chunkIndex: Int) async -> ProcessedChunk {
        // Simulate computational work - word frequency analysis
        var wordFrequency: [String: Int] = [:]
        var processedWords: [String] = []
        
        for word in words {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            wordFrequency[cleanWord, default: 0] += 1
            
            // Example text enhancement: highlight frequently used words in this chunk
            if wordFrequency[cleanWord]! > 1 {
                processedWords.append("**\(word)**")  // Bold for repeated words
            } else {
                processedWords.append(word)
            }
        }
        
        // Simulate computational work (demonstrates parallel speedup potential)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms per chunk
        
        return ProcessedChunk(
            processedText: processedWords.joined(separator: " "),
            wordCount: words.count,
            chunkIndex: chunkIndex,
            uniqueWords: wordFrequency.count
        )
    }
    
    // MARK: - Helper Methods
    
    private func processChunkSequentially(_ chunk: String, model: String) async throws -> String {
        let requestBody = OllamaRequest(
            model: model,
            prompt: chunk,
            stream: false,
            options: OllamaOptions(temperature: 0.7, top_p: 0.9, max_tokens: 100)
        )
        
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, _) = try await urlSession.data(for: request)
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return response.response
    }
    
    private func splitPromptForParallelProcessing(_ prompt: String) -> [String] {
        // Simple demonstration - in practice, you'd need sophisticated
        // prompt splitting based on semantic boundaries
        let words = prompt.components(separatedBy: .whitespacesAndNewlines)
        let chunkSize = max(words.count / 3, 1)
        
        var chunks: [String] = []
        for i in stride(from: 0, to: words.count, by: chunkSize) {
            let end = min(i + chunkSize, words.count)
            let chunk = Array(words[i..<end]).joined(separator: " ")
            chunks.append(chunk)
        }
        
        return chunks.isEmpty ? [prompt] : chunks
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token on average
        return max(text.count / 4, 1)
    }
}

// MARK: - Data Models

struct AIModel: Identifiable, Codable {
    let id = UUID()
    let name: String
    let displayName: String
    let size: String
    let description: String
}

/// Data structure for parallel text processing results
struct ProcessedChunk {
    let processedText: String
    let wordCount: Int
    let chunkIndex: Int
    let uniqueWords: Int
}

struct StreamingResponse {
    let token: String
    let fullResponse: String
    let isComplete: Bool
    let tokenCount: Int
    let metrics: PerformanceMetrics?
    
    init(token: String, fullResponse: String, isComplete: Bool, tokenCount: Int, metrics: PerformanceMetrics? = nil) {
        self.token = token
        self.fullResponse = fullResponse
        self.isComplete = isComplete
        self.tokenCount = tokenCount
        self.metrics = metrics
    }
}

// MARK: - Ollama API Models

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Codable {
    let temperature: Double
    let top_p: Double
    let max_tokens: Int?
    
    init(temperature: Double = 0.7, top_p: Double = 0.9, max_tokens: Int? = nil) {
        self.temperature = temperature
        self.top_p = top_p
        self.max_tokens = max_tokens
    }
}

struct OllamaResponse: Codable {
    let response: String
    let done: Bool
}

struct OllamaStreamResponse: Codable {
    let response: String
    let done: Bool
}

struct ModelsResponse: Codable {
    let models: [ModelInfo]
}

struct ModelInfo: Codable {
    let name: String
    let size: Int64
}

// MARK: - Error Types

enum OllamaError: LocalizedError {
    case networkError(String)
    case invalidResponse
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .modelNotFound:
            return "Requested model not found"
        }
    }
}
