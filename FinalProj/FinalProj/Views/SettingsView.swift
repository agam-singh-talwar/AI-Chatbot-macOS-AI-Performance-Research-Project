//
//  SettingsView.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Model Selection") {
                    ModelSelectionView(viewModel: viewModel)
                }
                
                Section("Ollama Setup") {
                    ConnectionSettingsView(viewModel: viewModel)
                }
                
                Section("Parallel Algorithm Info") {
                    AlgorithmInfoView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 500)
    }
}

struct ModelSelectionView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isConnectedToOllama && !viewModel.availableModels.isEmpty {
                Text("Available Models")
                    .font(.headline)
                
                Picker("Select Model", selection: Binding(
                    get: { viewModel.selectedModel },
                    set: { viewModel.updateModel($0) }
                )) {
                    ForEach(viewModel.availableModels, id: \.name) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                            Text(model.size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(model.name)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("No models available")
                    .foregroundColor(.secondary)
                
                if !viewModel.isConnectedToOllama {
                    Text("Connect to Ollama to see available models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Current Model:")
                Text(viewModel.selectedModel)
                    .fontWeight(.medium)
                Spacer()
            }
            .font(.subheadline)
        }
    }
}

struct RecommendedModelsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("For best performance on Apple Silicon:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(Array(OllamaService.recommendedModels.prefix(3)), id: \.id) { model in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .fontWeight(.medium)
                        Spacer()
                        Text(model.size)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Install: `ollama run \(model.name)`")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
                
                if model.id != Array(OllamaService.recommendedModels.prefix(3)).last?.id {
                    Divider()
                }
            }
        }
    }
}

struct ConnectionSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.isConnectedToOllama ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.isConnectedToOllama ? "Connected" : "Disconnected")
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await viewModel.checkOllamaConnection()
                    }
                }
                .buttonStyle(.borderless)
            }
            
            if !viewModel.isConnectedToOllama {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama Setup Instructions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("1. Install Ollama from https://ollama.ai")
                    Text("2. Run: `ollama serve`")
                    Text("3. Download a model: `ollama run phi3:mini`")
                    
                    Text("Default URL: http://localhost:11434")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
    }
}

struct AlgorithmInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This app demonstrates parallel text processing algorithms:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 6) {
                AlgorithmInfoRow(
                    icon: "square.stack.3d.down.right",
                    title: "Sequential",
                    description: "Baseline algorithm processing text linearly"
                )
                
                AlgorithmInfoRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Streaming",
                    description: "Real-time token processing with async streams"
                )
                
                AlgorithmInfoRow(
                    icon: "square.grid.3x3",
                    title: "Parallel",
                    description: "Parallel word frequency analysis using TaskGroup",
                    highlight: true
                )
            }
            
            Divider()
            
            Text("Key Concepts Demonstrated:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Data Parallelism: Text divided into chunks")
                Text("• Task Parallelism: Swift TaskGroup coordination")
                Text("• Load Balancing: Work distributed across cores")
                Text("• Performance Analysis: Speedup and efficiency")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct AlgorithmInfoRow: View {
    let icon: String
    let title: String
    let description: String
    let highlight: Bool
    
    init(icon: String, title: String, description: String, highlight: Bool = false) {
        self.icon = icon
        self.title = title
        self.description = description
        self.highlight = highlight
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(highlight ? .orange : .blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(highlight ? .orange : .primary)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PerformanceSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Tips:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Use quantized models (Q4_0, Q4_1) for better speed")
                Text("• Smaller models (1B-3B parameters) are faster")
                Text("• Streaming mode provides better user experience")
                Text("• Monitor CPU/Memory usage in Analytics")
                Text("• Close other applications for better performance")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Divider()
            
            Text("Apple Silicon Optimizations:")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Models run on GPU when possible")
                Text("• Metal Performance Shaders acceleration")
                Text("• Unified memory architecture benefits")
                Text("• Consider 16GB+ RAM for larger models")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView(viewModel: ChatViewModel())
}
