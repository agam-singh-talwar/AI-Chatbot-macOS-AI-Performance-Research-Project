//
//  ChatMessage.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import Foundation

/// Represents a chat message in the conversation
struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let executionMode: ExecutionMode?
    let metrics: PerformanceMetrics?
    
    init(content: String, isUser: Bool, executionMode: ExecutionMode? = nil, metrics: PerformanceMetrics? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.executionMode = executionMode
        self.metrics = metrics
    }
}

/// Execution modes for parallel algorithm comparison
enum ExecutionMode: String, CaseIterable, Codable {
    case sequential = "Sequential"
    case parallel = "Parallel"
    
    var description: String {
        switch self {
        case .sequential:
            return "Sequential text processing algorithm (baseline)"
        case .parallel:
            return "Parallel text processing using TaskGroup and data parallelism"
        }
    }
    
    var icon: String {
        switch self {
        case .sequential:
            return "arrow.right.circle"
        case .parallel:
            return "arrow.triangle.branch"
        }
    }
}
