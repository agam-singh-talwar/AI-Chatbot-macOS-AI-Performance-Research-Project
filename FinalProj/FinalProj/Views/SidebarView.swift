//
//  SidebarView.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showSettings: Bool
    @Binding var showMetrics: Bool
    
    var body: some View {
        List {
            Section("Parallel Algorithm Research") {
                AlgorithmComparisonView(viewModel: viewModel)
            }
            
            Section("Algorithm Modes") {
                ExecutionModeInfoView()
            }
            
            Section("Actions") {
                QuickActionsView(viewModel: viewModel, showSettings: $showSettings, showMetrics: $showMetrics)
            }
            
            Section("Performance Stats") {
                SessionStatsView(viewModel: viewModel)
            }
        }
        .navigationTitle("Parallel Algorithms")
        .listStyle(.sidebar)
    }
}

struct AlgorithmComparisonView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.isConnectedToOllama ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnectedToOllama ? "Ready" : "Setup Required")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if !viewModel.sessionMetrics.isEmpty {
                let grouped = Dictionary(grouping: viewModel.sessionMetrics) { $0.executionMode }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Algorithm Performance:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(ExecutionMode.allCases, id: \.self) { mode in
                        if let metrics = grouped[mode], !metrics.isEmpty {
                            let avgTime = metrics.map { $0.totalResponseTime }.reduce(0, +) / Double(metrics.count)
                            
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(mode == .parallel ? .orange : .blue)
                                    .frame(width: 12)
                                Text(mode.rawValue)
                                    .font(.caption2)
                                Spacer()
                                Text("\(String(format: "%.1f", avgTime))s")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(mode == .parallel ? .orange : .primary)
                            }
                        }
                    }
                }
            } else {
                Text("Send messages to compare algorithm performance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConnectionStatusView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.isConnectedToOllama ? .green : .red)
                    .frame(width: 10, height: 10)
                
                Text(viewModel.isConnectedToOllama ? "Connected to Ollama" : "Disconnected")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if !viewModel.isConnectedToOllama {
                Text("Make sure Ollama is running on localhost:11434")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Retry Connection") {
                    Task {
                        await viewModel.checkOllamaConnection()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            if viewModel.isConnectedToOllama {
                HStack {
                    Text("Model:")
                    Text(viewModel.selectedModel)
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExecutionModeInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ExecutionMode.allCases, id: \.self) { mode in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: mode.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(mode.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showSettings: Bool
    @Binding var showMetrics: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                showSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
            
            Button {
                showMetrics = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar")
                    Text("Analytics")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.sessionMetrics.isEmpty)
            
            Button {
                viewModel.clearChat()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Chat")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.messages.count <= 1) // Keep welcome message
        }
        .padding(.vertical, 4)
    }
}

struct SessionStatsView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "message")
                Text("Messages: \(viewModel.messages.count)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Metrics: \(viewModel.sessionMetrics.count)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if !viewModel.sessionMetrics.isEmpty {
                let avgTime = viewModel.sessionMetrics.map { $0.totalResponseTime }.reduce(0, +) / Double(viewModel.sessionMetrics.count)
                let avgTokens = viewModel.sessionMetrics.map { $0.tokensPerSecond }.reduce(0, +) / Double(viewModel.sessionMetrics.count)
                
                Divider()
                
                HStack {
                    Image(systemName: "clock")
                    Text("Avg Time: \(String(format: "%.1f", avgTime))s")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "speedometer")
                    Text("Avg Speed: \(String(format: "%.1f", avgTokens)) tok/s")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        SidebarView(
            viewModel: ChatViewModel(),
            showSettings: .constant(false),
            showMetrics: .constant(false)
        )
    }
}
