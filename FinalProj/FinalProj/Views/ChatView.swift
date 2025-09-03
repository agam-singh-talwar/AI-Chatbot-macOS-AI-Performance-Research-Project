//
//  ChatView.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView(viewModel: viewModel)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isProcessing {
                            TypingIndicatorView()
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input Area
            MessageInputView(viewModel: viewModel)
        }
        .navigationTitle("AI Chat Assistant")
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack {
            // Connection Status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnectedToOllama ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnectedToOllama ? "Ollama Connected" : "Ollama Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Parallel Algorithm Focus
            HStack(spacing: 4) {
                Image(systemName: viewModel.selectedExecutionMode.icon)
                    .foregroundColor(.accentColor)
                Text("\(viewModel.selectedExecutionMode.rawValue) Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(viewModel.selectedExecutionMode == .parallel ? .orange.opacity(0.2) : .clear)
            .cornerRadius(6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var showMetrics = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                Circle()
                    .fill(.blue)
                    .overlay {
                        Text("AI")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? .blue : .gray.opacity(0.1))
                    )
                
                // Metadata
                HStack(spacing: 8) {
                    if let executionMode = message.executionMode {
                        HStack(spacing: 2) {
                            Image(systemName: executionMode.icon)
                            Text(executionMode.rawValue)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.metrics != nil {
                        Button {
                            showMetrics.toggle()
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if message.isUser {
                Circle()
                    .fill(.green)
                    .overlay {
                        Text("U")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
            }
        }
        .popover(isPresented: $showMetrics) {
            if let metrics = message.metrics {
                MetricsSummaryView(metrics: metrics)
                    .frame(width: 300, height: 200)
            }
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            }
            Text("AI is thinking...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.1))
        )
        .onAppear {
            withAnimation {
                animationPhase = 0
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                withAnimation {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

struct MessageInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Execution Mode Picker
            Picker("Execution Mode", selection: $viewModel.selectedExecutionMode) {
                ForEach(ExecutionMode.allCases, id: \.self) { mode in
                    HStack {
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isProcessing)
            
            // Input field and send button
            HStack(spacing: 12) {
                TextField("Type your message...", text: $viewModel.currentInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .disabled(viewModel.isProcessing)
                    .onSubmit {
                        if !viewModel.isProcessing {
                            viewModel.sendMessage()
                        }
                    }
                
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: viewModel.isProcessing ? "stop.circle.fill" : "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.isProcessing ? .red : .blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isProcessing)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct MetricsSummaryView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                Text(metrics.formattedSummary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
}
