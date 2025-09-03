//
//  PerformanceMetrics.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import Foundation

/// Comprehensive performance metrics for AI inference analysis
struct PerformanceMetrics: Codable {
    // Time-based metrics
    let totalResponseTime: TimeInterval
    let firstTokenLatency: TimeInterval?
    let averageTokenLatency: TimeInterval?
    
    // System resource metrics
    let peakCPUUsage: Double
    let averageCPUUsage: Double
    let peakMemoryUsage: UInt64  // in bytes
    let averageMemoryUsage: UInt64
    
    // Network metrics
    let networkBytesReceived: UInt64
    let networkBytesSent: UInt64
    let networkLatency: TimeInterval
    
    // Response quality metrics
    let tokenCount: Int
    let tokensPerSecond: Double
    let errorCount: Int
    let successRate: Double
    
    // UI responsiveness
    let uiBlockingTime: TimeInterval
    let frameDropCount: Int
    
    // Metadata
    let executionMode: ExecutionMode
    let modelName: String
    let timestamp: Date
    
    init(
        totalResponseTime: TimeInterval,
        firstTokenLatency: TimeInterval? = nil,
        averageTokenLatency: TimeInterval? = nil,
        peakCPUUsage: Double,
        averageCPUUsage: Double,
        peakMemoryUsage: UInt64,
        averageMemoryUsage: UInt64,
        networkBytesReceived: UInt64,
        networkBytesSent: UInt64,
        networkLatency: TimeInterval,
        tokenCount: Int,
        tokensPerSecond: Double,
        errorCount: Int,
        successRate: Double,
        uiBlockingTime: TimeInterval,
        frameDropCount: Int,
        executionMode: ExecutionMode,
        modelName: String
    ) {
        self.totalResponseTime = totalResponseTime
        self.firstTokenLatency = firstTokenLatency
        self.averageTokenLatency = averageTokenLatency
        self.peakCPUUsage = peakCPUUsage
        self.averageCPUUsage = averageCPUUsage
        self.peakMemoryUsage = peakMemoryUsage
        self.averageMemoryUsage = averageMemoryUsage
        self.networkBytesReceived = networkBytesReceived
        self.networkBytesSent = networkBytesSent
        self.networkLatency = networkLatency
        self.tokenCount = tokenCount
        self.tokensPerSecond = tokensPerSecond
        self.errorCount = errorCount
        self.successRate = successRate
        self.uiBlockingTime = uiBlockingTime
        self.frameDropCount = frameDropCount
        self.executionMode = executionMode
        self.modelName = modelName
        self.timestamp = Date()
    }
    
    /// Generate a formatted summary string for display
    var formattedSummary: String {
        return """
        📊 Performance Summary (\(executionMode.rawValue))
        ⏱️ Total Time: \(String(format: "%.2f", totalResponseTime))s
        🚀 First Token: \(firstTokenLatency.map { String(format: "%.2f", $0) + "s" } ?? "N/A")
        📈 Tokens/sec: \(String(format: "%.1f", tokensPerSecond))
        🧠 CPU Peak: \(String(format: "%.1f", peakCPUUsage))%
        💾 Memory Peak: \(formatBytes(peakMemoryUsage))
        🌐 Network: ↓\(formatBytes(networkBytesReceived)) ↑\(formatBytes(networkBytesSent))
        ✅ Success Rate: \(String(format: "%.1f", successRate * 100))%
        """
    }
    
    /// Format bytes into human-readable format
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Metrics collector to track performance during AI inference
@MainActor
class PerformanceMetricsCollector: ObservableObject {
    private var startTime: CFAbsoluteTime = 0
    private var firstTokenTime: CFAbsoluteTime?
    private var tokenTimes: [CFAbsoluteTime] = []
    private var cpuUsages: [Double] = []
    private var memoryUsages: [UInt64] = []
    private var networkStart: (received: UInt64, sent: UInt64) = (0, 0)
    private var errorCount: Int = 0
    
    func startCollection() {
        startTime = CFAbsoluteTimeGetCurrent()
        firstTokenTime = nil
        tokenTimes.removeAll()
        cpuUsages.removeAll()
        memoryUsages.removeAll()
        errorCount = 0
        
        // Start periodic system monitoring
        startSystemMonitoring()
    }
    
    func recordFirstToken() {
        if firstTokenTime == nil {
            firstTokenTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    func recordToken() {
        tokenTimes.append(CFAbsoluteTimeGetCurrent())
    }
    
    func recordError() {
        errorCount += 1
    }
    
    func finishCollection(
        tokenCount: Int,
        executionMode: ExecutionMode,
        modelName: String,
        uiBlockingTime: TimeInterval = 0,
        frameDropCount: Int = 0
    ) -> PerformanceMetrics {
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        let firstTokenLatency = firstTokenTime.map { $0 - startTime }
        let averageTokenLatency = tokenTimes.isEmpty ? nil : 
            tokenTimes.map { $0 - startTime }.reduce(0, +) / Double(tokenTimes.count)
        
        let tokensPerSecond = totalTime > 0 ? Double(tokenCount) / totalTime : 0
        let successRate = tokenCount > 0 ? Double(tokenCount - errorCount) / Double(tokenCount) : 0
        
        return PerformanceMetrics(
            totalResponseTime: totalTime,
            firstTokenLatency: firstTokenLatency,
            averageTokenLatency: averageTokenLatency,
            peakCPUUsage: cpuUsages.max() ?? 0,
            averageCPUUsage: cpuUsages.isEmpty ? 0 : cpuUsages.reduce(0, +) / Double(cpuUsages.count),
            peakMemoryUsage: memoryUsages.max() ?? 0,
            averageMemoryUsage: memoryUsages.isEmpty ? 0 : memoryUsages.reduce(0, +) / UInt64(memoryUsages.count),
            networkBytesReceived: getCurrentNetworkUsage().received - networkStart.received,
            networkBytesSent: getCurrentNetworkUsage().sent - networkStart.sent,
            networkLatency: 0.1, // Placeholder - would need actual network ping measurement
            tokenCount: tokenCount,
            tokensPerSecond: tokensPerSecond,
            errorCount: errorCount,
            successRate: successRate,
            uiBlockingTime: uiBlockingTime,
            frameDropCount: frameDropCount,
            executionMode: executionMode,
            modelName: modelName
        )
    }
    
    private func startSystemMonitoring() {
        networkStart = getCurrentNetworkUsage()
        
        // Monitor system resources periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            if self?.startTime == 0 { // Stop monitoring when collection ends
                timer.invalidate()
                return
            }
            
            self?.cpuUsages.append(self?.getCurrentCPUUsage() ?? 0)
            self?.memoryUsages.append(self?.getCurrentMemoryUsage() ?? 0)
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.user_time.seconds + info.system_time.seconds) * 100.0
        }
        return 0.0
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        return 0
    }
    
    private func getCurrentNetworkUsage() -> (received: UInt64, sent: UInt64) {
        // Simplified network usage tracking
        // In a real implementation, you would use system APIs to get actual network stats
        return (received: 0, sent: 0)
    }
}
