//
//  MetricsView.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import SwiftUI

struct MetricsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Summary Tab
                SummaryMetricsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Summary")
                    }
                    .tag(0)
                
                // Charts Tab
                DetailedChartsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Charts")
                    }
                    .tag(1)
                
                // Raw Data Tab
                RawDataView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Raw Data")
                    }
                    .tag(2)
            }
            .navigationTitle("Parallel Algorithm Analysis")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("Export") {
                        exportMetrics()
                    }
                    .disabled(viewModel.sessionMetrics.isEmpty)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func exportMetrics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ai_chat_metrics_\(Date().ISO8601Format())"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? viewModel.exportMetrics().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct SummaryMetricsView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if viewModel.sessionMetrics.isEmpty {
                    EmptyMetricsView()
                } else {
                    // Performance Comparison
                    PerformanceComparisonView(metrics: viewModel.sessionMetrics)
                    
                    Divider()
                    
                    // System Resources
                    SystemResourcesView(metrics: viewModel.sessionMetrics)
                    
                    Divider()
                    
                    // Detailed Summary
                    Text(viewModel.getAnalyticsSummary())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

struct PerformanceComparisonView: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution Mode Comparison")
                .font(.title2)
                .fontWeight(.bold)
            
            let grouped = Dictionary(grouping: metrics) { $0.executionMode }
            
            HStack(spacing: 20) {
                ForEach(ExecutionMode.allCases, id: \.self) { mode in
                    if let modeMetrics = grouped[mode], !modeMetrics.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title)
                                .foregroundColor(.accentColor)
                            
                            Text(mode.rawValue)
                                .font(.headline)
                            
                            let avgTime = modeMetrics.map { $0.totalResponseTime }.reduce(0, +) / Double(modeMetrics.count)
                            let avgTokens = modeMetrics.map { $0.tokensPerSecond }.reduce(0, +) / Double(modeMetrics.count)
                            let avgFirstToken = modeMetrics.compactMap { $0.firstTokenLatency }.reduce(0, +) / Double(modeMetrics.compactMap { $0.firstTokenLatency }.count)
                            
                            VStack(spacing: 4) {
                                MetricRow(title: "Avg Time", value: "\(String(format: "%.2f", avgTime))s")
                                MetricRow(title: "Tokens/sec", value: String(format: "%.1f", avgTokens))
                                if !avgFirstToken.isNaN {
                                    MetricRow(title: "First Token", value: "\(String(format: "%.2f", avgFirstToken))s")
                                }
                                MetricRow(title: "Requests", value: "\(modeMetrics.count)")
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct SystemResourcesView: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Resource Usage")
                .font(.title2)
                .fontWeight(.bold)
            
            let avgCPU = metrics.map { $0.peakCPUUsage }.reduce(0, +) / Double(metrics.count)
            let maxCPU = metrics.map { $0.peakCPUUsage }.max() ?? 0
            let avgMemory = metrics.map { Double($0.peakMemoryUsage) }.reduce(0, +) / Double(metrics.count)
            let maxMemory = metrics.map { $0.peakMemoryUsage }.max() ?? 0
            
            HStack(spacing: 40) {
                VStack(alignment: .leading) {
                    Text("CPU Usage")
                        .font(.headline)
                    MetricRow(title: "Average", value: "\(String(format: "%.1f", avgCPU))%")
                    MetricRow(title: "Peak", value: "\(String(format: "%.1f", maxCPU))%")
                }
                
                VStack(alignment: .leading) {
                    Text("Memory Usage")
                        .font(.headline)
                    MetricRow(title: "Average", value: ByteCountFormatter().string(fromByteCount: Int64(avgMemory)))
                    MetricRow(title: "Peak", value: ByteCountFormatter().string(fromByteCount: Int64(maxMemory)))
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(8)
        }
    }
}

struct DetailedChartsView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if viewModel.sessionMetrics.isEmpty {
                    EmptyMetricsView()
                } else {
                    // Response Time Chart
                    ResponseTimeChartView(metrics: viewModel.sessionMetrics)
                    
                    // Tokens per Second Chart
                    TokensPerSecondChartView(metrics: viewModel.sessionMetrics)
                    
                    // System Resource Chart
                    SystemResourceChartView(metrics: viewModel.sessionMetrics)
                }
            }
            .padding()
        }
    }
}

struct ResponseTimeChartView: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Time by Execution Mode")
                .font(.title2)
                .fontWeight(.bold)
            
            CustomBarChart(metrics: metrics)
                .frame(height: 200)
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }
}

struct CustomBarChart: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        GeometryReader { geometry in
            let maxTime = metrics.map { $0.totalResponseTime }.max() ?? 1.0
            let barWidth = geometry.size.width / CGFloat(metrics.count)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Rectangle()
                        .fill(colorForMode(metric.executionMode))
                        .frame(
                            width: max(barWidth - 4, 8),
                            height: CGFloat(metric.totalResponseTime / maxTime) * geometry.size.height
                        )
                        .overlay {
                            VStack {
                                Spacer()
                                Text(String(format: "%.1f", metric.totalResponseTime))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .bold()
                            }
                            .padding(.bottom, 2)
                        }
                }
            }
        }
    }
    
    private func colorForMode(_ mode: ExecutionMode) -> Color {
        switch mode {
        case .sequential: return .blue
        case .parallel: return .orange
        }
    }
}

struct TokensPerSecondChartView: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens per Second Over Time")
                .font(.title2)
                .fontWeight(.bold)
            
            CustomLineChart(metrics: metrics, valueKeyPath: \.tokensPerSecond, label: "Tokens/sec")
                .frame(height: 200)
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }
}

struct SystemResourceChartView: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Resource Usage")
                .font(.title2)
                .fontWeight(.bold)
            
            CustomDualLineChart(metrics: metrics)
                .frame(height: 200)
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("CPU %")
                }
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text("Memory (MB)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct CustomLineChart: View {
    let metrics: [PerformanceMetrics]
    let valueKeyPath: KeyPath<PerformanceMetrics, Double>
    let label: String
    
    var body: some View {
        GeometryReader { geometry in
            let values = metrics.map { $0[keyPath: valueKeyPath] }
            let maxValue = values.max() ?? 1.0
            let minValue = values.min() ?? 0.0
            let valueRange = maxValue - minValue
            
            if metrics.count > 1 {
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                        let normalizedValue = valueRange > 0 ? (value - minValue) / valueRange : 0.5
                        let y = geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(.blue, lineWidth: 2)
                
                // Data points
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                    let normalizedValue = valueRange > 0 ? (value - minValue) / valueRange : 0.5
                    let y = geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)
                    
                    Circle()
                        .fill(colorForMode(metrics[index].executionMode))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }
    
    private func colorForMode(_ mode: ExecutionMode) -> Color {
        switch mode {
        case .sequential: return .blue
        case .parallel: return .orange
        }
    }
}

struct CustomDualLineChart: View {
    let metrics: [PerformanceMetrics]
    
    var body: some View {
        GeometryReader { geometry in
            let cpuValues = metrics.map { $0.peakCPUUsage }
            let memoryValues = metrics.map { Double($0.peakMemoryUsage) / 1024 / 1024 } // Convert to MB
            
            let maxCPU = cpuValues.max() ?? 100.0
            let maxMemory = memoryValues.max() ?? 1024.0
            
            // CPU Line
            if metrics.count > 1 {
                Path { path in
                    for (index, value) in cpuValues.enumerated() {
                        let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                        let y = geometry.size.height - (CGFloat(value / maxCPU) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(.red, lineWidth: 2)
                
                // Memory Line (scaled to fit)
                Path { path in
                    for (index, value) in memoryValues.enumerated() {
                        let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                        let y = geometry.size.height - (CGFloat(value / maxMemory) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(.blue, lineWidth: 2)
                
                // Data points for CPU
                ForEach(Array(cpuValues.enumerated()), id: \.offset) { index, value in
                    let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                    let y = geometry.size.height - (CGFloat(value / maxCPU) * geometry.size.height)
                    
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
                
                // Data points for Memory
                ForEach(Array(memoryValues.enumerated()), id: \.offset) { index, value in
                    let x = CGFloat(index) / CGFloat(metrics.count - 1) * geometry.size.width
                    let y = geometry.size.height - (CGFloat(value / maxMemory) * geometry.size.height)
                    
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

struct RawDataView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.sessionMetrics.isEmpty {
                EmptyMetricsView()
            } else {
                // Search bar
                TextField("Search metrics...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                // Raw data table
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        // Header
                        HStack {
                            Text("Mode").frame(width: 80, alignment: .leading)
                            Text("Time (s)").frame(width: 60, alignment: .trailing)
                            Text("Tokens/s").frame(width: 60, alignment: .trailing)
                            Text("CPU %").frame(width: 60, alignment: .trailing)
                            Text("Memory").frame(width: 80, alignment: .trailing)
                            Text("Model").frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        
                        ForEach(Array(filteredMetrics.enumerated()), id: \.offset) { index, metric in
                            HStack {
                                Text(metric.executionMode.rawValue)
                                    .frame(width: 80, alignment: .leading)
                                    .font(.caption)
                                
                                Text(String(format: "%.2f", metric.totalResponseTime))
                                    .frame(width: 60, alignment: .trailing)
                                    .font(.caption)
                                
                                Text(String(format: "%.1f", metric.tokensPerSecond))
                                    .frame(width: 60, alignment: .trailing)
                                    .font(.caption)
                                
                                Text(String(format: "%.1f", metric.peakCPUUsage))
                                    .frame(width: 60, alignment: .trailing)
                                    .font(.caption)
                                
                                Text(ByteCountFormatter().string(fromByteCount: Int64(metric.peakMemoryUsage)))
                                    .frame(width: 80, alignment: .trailing)
                                    .font(.caption)
                                
                                Text(metric.modelName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .font(.caption)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(index % 2 == 0 ? .clear : .gray.opacity(0.05))
                        }
                    }
                }
                .background(.regularMaterial)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var filteredMetrics: [PerformanceMetrics] {
        if searchText.isEmpty {
            return viewModel.sessionMetrics
        } else {
            return viewModel.sessionMetrics.filter { metric in
                metric.executionMode.rawValue.localizedCaseInsensitiveContains(searchText) ||
                metric.modelName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct EmptyMetricsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Performance Data")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Send some messages to generate performance metrics and analytics.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    MetricsView(viewModel: ChatViewModel())
}
