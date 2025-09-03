//
//  ChatViewModel.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import Foundation
import Combine
import SwiftUI

/// Main controller managing chat state and coordinating between UI and AI service
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var selectedExecutionMode: ExecutionMode = .sequential
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var showMetrics: Bool = false
    @Published var selectedModel: String = "phi3:mini"
    
    // MARK: - Services
    private let ollamaService = OllamaService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Analytics
    @Published var sessionMetrics: [PerformanceMetrics] = []
    
    // MARK: - Initialization
    init() {
        setupBindings()
        addWelcomeMessage()
    }
    
    private func setupBindings() {
        // Observe Ollama service state
        ollamaService.$isGenerating
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        ollamaService.$currentModel
            .assign(to: \.selectedModel, on: self)
            .store(in: &cancellables)
    }
    
    private func addWelcomeMessage() {
        let welcomeText = """
        🧬 Welcome to Parallel Algorithm Research Demo!
        
        This app demonstrates parallel text processing algorithms:
        • Sequential: Baseline text processing algorithm (single-threaded)
        • Parallel: Parallel word frequency analysis using TaskGroup (multi-threaded)
        
        Switch between modes and send messages to compare algorithm performance!
        📊 View detailed analysis in the Analytics tab.
        """
        
        messages.append(ChatMessage(content: welcomeText, isUser: false))
    }
    
    // MARK: - Chat Actions
    
    /// Send a message using the selected execution mode
    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isProcessing else { return }
        
        let userMessage = ChatMessage(content: currentInput, isUser: true)
        messages.append(userMessage)
        
        let prompt = currentInput
        currentInput = ""
        errorMessage = nil
        
        Task {
            switch selectedExecutionMode {
            case .sequential:
                await handleSequentialGeneration(prompt: prompt)
            case .parallel:
                await handleParallelGeneration(prompt: prompt)
            }
        }
    }
    
    // MARK: - Generation Handlers
    
    private func handleSequentialGeneration(prompt: String) async {
        do {
            let (response, metrics) = try await ollamaService.generateSequential(prompt: prompt, model: selectedModel)
            
            let aiMessage = ChatMessage(
                content: response,
                isUser: false,
                executionMode: .sequential,
                metrics: metrics
            )
            
            messages.append(aiMessage)
            sessionMetrics.append(metrics)
            
        } catch {
            handleError(error)
        }
    }
    

    private func handleParallelGeneration(prompt: String) async {
        do {
            let (response, metrics) = try await ollamaService.generateParallel(prompt: prompt, model: selectedModel)
            
            let aiMessage = ChatMessage(
                content: response,
                isUser: false,
                executionMode: .parallel,
                metrics: metrics
            )
            
            messages.append(aiMessage)
            sessionMetrics.append(metrics)
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Utility Methods
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        
        let errorMessage = ChatMessage(
            content: "❌ Error: \(error.localizedDescription)",
            isUser: false,
            executionMode: selectedExecutionMode
        )
        messages.append(errorMessage)
    }
    
    func clearChat() {
        messages.removeAll()
        sessionMetrics.removeAll()
        addWelcomeMessage()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Analytics
    
    func getAnalyticsSummary() -> String {
        guard !sessionMetrics.isEmpty else {
            return "No metrics available yet. Send some messages to see performance data!"
        }
        
        let sequentialMetrics = sessionMetrics.filter { $0.executionMode == .sequential }
        let parallelMetrics = sessionMetrics.filter { $0.executionMode == .parallel }
        
        var summary = "📊 Session Analytics Summary\n\n"
        
        if !sequentialMetrics.isEmpty {
            let avgTime = sequentialMetrics.map { $0.totalResponseTime }.reduce(0, +) / Double(sequentialMetrics.count)
            let avgTokensPerSec = sequentialMetrics.map { $0.tokensPerSecond }.reduce(0, +) / Double(sequentialMetrics.count)
            summary += "🔄 Sequential Mode (\(sequentialMetrics.count) requests):\n"
            summary += "   • Avg Response Time: \(String(format: "%.2f", avgTime))s\n"
            summary += "   • Avg Tokens/sec: \(String(format: "%.1f", avgTokensPerSec))\n\n"
        }
        
        if !parallelMetrics.isEmpty {
            let avgTime = parallelMetrics.map { $0.totalResponseTime }.reduce(0, +) / Double(parallelMetrics.count)
            let avgTokensPerSec = parallelMetrics.map { $0.tokensPerSecond }.reduce(0, +) / Double(parallelMetrics.count)
            summary += "⚡ Parallel Mode (\(parallelMetrics.count) requests):\n"
            summary += "   • Avg Response Time: \(String(format: "%.2f", avgTime))s\n"
            summary += "   • Avg Tokens/sec: \(String(format: "%.1f", avgTokensPerSec))\n\n"
        }
        
        // Overall comparison
        let allMetrics = sessionMetrics
        let avgCPU = allMetrics.map { $0.peakCPUUsage }.reduce(0, +) / Double(allMetrics.count)
        let avgMemory = allMetrics.map { Double($0.peakMemoryUsage) }.reduce(0, +) / Double(allMetrics.count)
        
        summary += "🔍 Overall Session Stats:\n"
        summary += "   • Total Requests: \(allMetrics.count)\n"
        summary += "   • Avg Peak CPU: \(String(format: "%.1f", avgCPU))%\n"
        summary += "   • Avg Peak Memory: \(ByteCountFormatter().string(fromByteCount: Int64(avgMemory)))\n"
        
        return summary
    }
    
    func exportMetrics() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(sessionMetrics)
            return String(data: data, encoding: .utf8) ?? "Failed to encode metrics"
        } catch {
            return "Failed to export metrics: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Model Management
    
    func updateModel(_ modelName: String) {
        selectedModel = modelName
        ollamaService.currentModel = modelName
    }
    
    func checkOllamaConnection() async {
        await ollamaService.checkConnection()
    }
    
    // MARK: - Computed Properties
    
    var isConnectedToOllama: Bool {
        ollamaService.isConnected
    }
    
    var availableModels: [AIModel] {
        ollamaService.availableModels
    }
    
    var recommendedModels: [AIModel] {
        OllamaService.recommendedModels
    }
}
