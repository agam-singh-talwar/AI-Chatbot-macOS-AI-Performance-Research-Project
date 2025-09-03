//
//  ContentView.swift
//  FinalProj - AI Chat Assistant
//
//  Created by Agam Singh Talwar on 2025-08-07.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false
    @State private var showMetrics = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(viewModel: viewModel, showSettings: $showSettings, showMetrics: $showMetrics)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            // Main Chat Interface
            ChatView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showMetrics) {
            MetricsView(viewModel: viewModel)
        }
        .task {
            await viewModel.checkOllamaConnection()
        }
    }
}

#Preview {
    ContentView()
}
