//
//  EnsoApp.swift
//  Enso
//
//  Created by Sami Hindi on 19.12.2025.
//

import SwiftUI
import SwiftData

@main
struct EnsoApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Email.self,
            Folder.self,
            Attachment.self,
            AIConversation.self,
            AIMessage.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var onboardingManager = OnboardingManager()
    @State private var syncService = SyncService()
    @State private var searchService = SearchService()
    @State private var draftService = DraftService()
    @State private var attachmentService = AttachmentService()
    @State private var aiService = AIService()

    init() {
        // Register custom fonts
        Typography.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainWindow()
                } else {
                    OnboardingContainerView()
                        .environmentObject(onboardingManager)
                }
            }
            .environment(\.syncService, syncService)
            .environment(\.searchService, searchService)
            .environment(\.draftService, draftService)
            .environment(\.attachmentService, attachmentService)
            .environment(\.aiService, aiService)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            SearchCommands()
        }

        Settings {
            SettingsView()
                .environment(\.syncService, syncService)
                .environment(\.searchService, searchService)
                .environment(\.draftService, draftService)
                .environment(\.attachmentService, attachmentService)
                .environment(\.aiService, aiService)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Search Commands

struct SearchCommands: Commands {
    @FocusedValue(\.searchActivation) private var searchActivation: Binding<Bool>?

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Search") {
                searchActivation?.wrappedValue = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(searchActivation == nil)
        }
    }
}
