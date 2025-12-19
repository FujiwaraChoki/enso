//
//  MainWindow.swift
//  Enso
//

import SwiftUI
import SwiftData

struct MainWindow: View {
    @StateObject private var tabManager = TabManager()
    @State private var showAISidebar = false
    @State private var showMoveSheet = false
    @State private var moveTargetEmail: Email?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService

    var body: some View {
        VStack(spacing: 0) {
            // Glass Tab Bar
            GlassTabBar(
                tabs: $tabManager.tabs,
                selectedTabId: $tabManager.selectedTabId,
                onNewTab: { tabManager.createTab() },
                onCloseTab: { tabManager.closeTab($0) }
            )

            // Tab Content
            TabContentView(
                tab: tabManager.currentTab,
                onCompose: { tabManager.openCompose() },
                onToggleAI: { showAISidebar.toggle() }
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $showAISidebar) {
            AISidebarView(email: tabManager.selectedEmail)
                .inspectorColumnWidth(min: 300, ideal: 350, max: 450)
        }
        .sheet(isPresented: $showMoveSheet) {
            if let email = moveTargetEmail {
                MoveFolderSheet(email: email, onMove: { folder in
                    do {
                        try await syncService.moveEmails([email], to: folder, modelContext: modelContext)
                    } catch {
                        print("Move failed: \(error)")
                    }
                })
            }
        }
        .environmentObject(tabManager)
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Tab Content Router

struct TabContentView: View {
    let tab: EnsoTab?
    let onCompose: () -> Void
    let onToggleAI: () -> Void

    var body: some View {
        Group {
            if let tab {
                switch tab.type {
                case .mail(let folderId):
                    MailSplitView(
                        folderId: folderId,
                        onCompose: onCompose,
                        onToggleAI: onToggleAI
                    )
                case .compose(let draftId):
                    ComposeView(draftId: draftId)
                case .aiConversation(let conversationId):
                    AITabView(conversationId: conversationId)
                case .settings:
                    SettingsView()
                }
            } else {
                EmptyStateView(
                    title: "No Tab Selected",
                    systemImage: "rectangle.on.rectangle",
                    description: "Select a tab or create a new one"
                )
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.medium)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainWindow()
        .modelContainer(for: [Account.self, Email.self, Folder.self])
}
