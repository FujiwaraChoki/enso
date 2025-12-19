//
//  TabManager.swift
//  Enso
//

import SwiftUI
import Combine

enum TabType: Equatable, Hashable {
    case mail(folderId: UUID?)
    case compose(draftId: UUID?)
    case aiConversation(conversationId: UUID?)
    case settings

    var defaultIcon: String {
        switch self {
        case .mail: return "envelope"
        case .compose: return "square.and.pencil"
        case .aiConversation: return "sparkles"
        case .settings: return "gear"
        }
    }

    var defaultTitle: String {
        switch self {
        case .mail: return "Inbox"
        case .compose: return "New Message"
        case .aiConversation: return "AI Assistant"
        case .settings: return "Settings"
        }
    }

    var isMailType: Bool {
        if case .mail = self {
            return true
        }
        return false
    }
}

struct EnsoTab: Identifiable, Equatable, Hashable {
    let id: UUID
    var type: TabType
    var title: String
    var icon: String
    var isClosable: Bool

    init(type: TabType, title: String? = nil, isClosable: Bool = true) {
        self.id = UUID()
        self.type = type
        self.title = title ?? type.defaultTitle
        self.icon = type.defaultIcon
        self.isClosable = isClosable
    }
}

// MARK: - Reply Context

enum ReplyMode {
    case reply
    case replyAll
    case forward
}

struct ReplyContext {
    let email: Email
    let mode: ReplyMode
}

enum TabBehavior: String, CaseIterable {
    case splitPaneWithTabs
    case autoOpenInNewTab
    case replaceCurrentTab

    var displayName: String {
        switch self {
        case .splitPaneWithTabs: return "Split Pane + Tabs"
        case .autoOpenInNewTab: return "Auto-open in New Tabs"
        case .replaceCurrentTab: return "Replace Current Tab"
        }
    }

    var description: String {
        switch self {
        case .splitPaneWithTabs: return "Email list stays visible, tabs for compose/AI"
        case .autoOpenInNewTab: return "Every email/compose opens a new tab"
        case .replaceCurrentTab: return "Content replaces current view"
        }
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [EnsoTab] = []
    @Published var selectedTabId: UUID?
    @Published var tabBehavior: TabBehavior
    @Published var selectedEmail: Email?

    var currentTab: EnsoTab? {
        tabs.first { $0.id == selectedTabId }
    }

    init() {
        // Load saved preference
        if let saved = UserDefaults.standard.string(forKey: "tabBehavior"),
           let behavior = TabBehavior(rawValue: saved) {
            self.tabBehavior = behavior
        } else {
            self.tabBehavior = .splitPaneWithTabs
        }

        // Create initial inbox tab
        let inboxTab = EnsoTab(type: .mail(folderId: nil), title: "Inbox", isClosable: false)
        tabs = [inboxTab]
        selectedTabId = inboxTab.id
    }

    // MARK: - Tab Operations

    func createTab(type: TabType = .mail(folderId: nil), title: String? = nil) {
        let newTab = EnsoTab(type: type, title: title)
        tabs.append(newTab)
        selectedTabId = newTab.id
    }

    func closeTab(_ tabId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }),
              tab.isClosable else { return }

        // Get index before removal
        let index = tabs.firstIndex { $0.id == tabId }

        tabs.removeAll { $0.id == tabId }

        // Select nearby tab if we closed the selected one
        if selectedTabId == tabId {
            if let index, index > 0 {
                selectedTabId = tabs[index - 1].id
            } else {
                selectedTabId = tabs.first?.id
            }
        }
    }

    func selectTab(_ tabId: UUID) {
        selectedTabId = tabId
    }

    func updateTabTitle(_ tabId: UUID, title: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].title = title
        }
    }

    // MARK: - Navigation Actions

    func openEmail(_ emailId: UUID, subject: String, folderId: UUID?) {
        switch tabBehavior {
        case .splitPaneWithTabs:
            // Just update selection in current mail tab (handled by view)
            break
        case .autoOpenInNewTab:
            createTab(type: .mail(folderId: folderId), title: subject)
        case .replaceCurrentTab:
            if let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) {
                tabs[currentIndex] = EnsoTab(
                    type: .mail(folderId: folderId),
                    title: subject
                )
            }
        }
    }

    func openCompose(draftId: UUID? = nil) {
        createTab(type: .compose(draftId: draftId), title: "New Message")
    }

    func openReply(to email: Email) {
        let title = "Re: \(email.subject)"
        createTab(type: .compose(draftId: nil), title: title)
        // Store reply context for compose view to use
        currentReplyContext = ReplyContext(email: email, mode: .reply)
    }

    func openReplyAll(to email: Email) {
        let title = "Re: \(email.subject)"
        createTab(type: .compose(draftId: nil), title: title)
        currentReplyContext = ReplyContext(email: email, mode: .replyAll)
    }

    func openForward(email: Email) {
        let title = "Fwd: \(email.subject)"
        createTab(type: .compose(draftId: nil), title: title)
        currentReplyContext = ReplyContext(email: email, mode: .forward)
    }

    // Reply/forward context for compose view
    @Published var currentReplyContext: ReplyContext?

    func openAIConversation(_ conversationId: UUID? = nil) {
        // Check if AI tab already exists
        if let existingTab = tabs.first(where: {
            if case .aiConversation = $0.type { return true }
            return false
        }) {
            selectedTabId = existingTab.id
        } else {
            createTab(type: .aiConversation(conversationId: conversationId), title: "AI Assistant")
        }
    }

    func openSettings() {
        // Check if settings tab already exists
        if let existingTab = tabs.first(where: {
            if case .settings = $0.type { return true }
            return false
        }) {
            selectedTabId = existingTab.id
        } else {
            createTab(type: .settings, title: "Settings")
        }
    }

    // MARK: - Persistence

    func savePreferences() {
        UserDefaults.standard.set(tabBehavior.rawValue, forKey: "tabBehavior")
    }
}
