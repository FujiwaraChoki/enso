//
//  TabManagerTests.swift
//  EnsoTests
//

import XCTest
@testable import Enso

final class TabManagerTests: XCTestCase {

    var tabManager: TabManager!

    override func setUp() {
        super.setUp()
        tabManager = TabManager()
    }

    override func tearDown() {
        tabManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_createsInboxTab() {
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.title, "Inbox")
    }

    func test_init_selectsInboxTab() {
        XCTAssertNotNil(tabManager.selectedTabId)
        XCTAssertEqual(tabManager.selectedTabId, tabManager.tabs.first?.id)
    }

    func test_init_inboxTabIsNotClosable() {
        XCTAssertFalse(tabManager.tabs.first?.isClosable ?? true)
    }

    func test_init_inboxTabIsMailType() {
        if case .mail = tabManager.tabs.first?.type {
            // Success
        } else {
            XCTFail("Expected mail tab type")
        }
    }

    func test_init_defaultsToSplitPaneBehavior() {
        // Clear UserDefaults for clean test
        UserDefaults.standard.removeObject(forKey: "tabBehavior")
        let freshManager = TabManager()

        XCTAssertEqual(freshManager.tabBehavior, .splitPaneWithTabs)
    }

    // MARK: - Tab Creation Tests

    func test_createTab_addsNewTab() {
        let initialCount = tabManager.tabs.count

        tabManager.createTab(type: .compose(draftId: nil))

        XCTAssertEqual(tabManager.tabs.count, initialCount + 1)
    }

    func test_createTab_selectsNewTab() {
        tabManager.createTab(type: .compose(draftId: nil), title: "New Email")

        let newTab = tabManager.tabs.last
        XCTAssertEqual(tabManager.selectedTabId, newTab?.id)
    }

    func test_createTab_usesProvidedTitle() {
        tabManager.createTab(type: .compose(draftId: nil), title: "Custom Title")

        XCTAssertEqual(tabManager.tabs.last?.title, "Custom Title")
    }

    func test_createTab_usesDefaultTitle_whenNil() {
        tabManager.createTab(type: .compose(draftId: nil))

        XCTAssertEqual(tabManager.tabs.last?.title, "New Message")
    }

    func test_createTab_newTabsAreClosable() {
        tabManager.createTab(type: .compose(draftId: nil))

        XCTAssertTrue(tabManager.tabs.last?.isClosable ?? false)
    }

    // MARK: - Tab Closing Tests

    func test_closeTab_removesTab() {
        tabManager.createTab(type: .compose(draftId: nil))
        let tabToClose = tabManager.tabs.last!

        tabManager.closeTab(tabToClose.id)

        XCTAssertFalse(tabManager.tabs.contains { $0.id == tabToClose.id })
    }

    func test_closeTab_doesNotCloseNonClosableTab() {
        let inboxTab = tabManager.tabs.first!
        XCTAssertFalse(inboxTab.isClosable)

        tabManager.closeTab(inboxTab.id)

        XCTAssertTrue(tabManager.tabs.contains { $0.id == inboxTab.id })
    }

    func test_closeTab_selectsPreviousTab_whenClosingSelected() {
        let inboxTab = tabManager.tabs.first!
        tabManager.createTab(type: .compose(draftId: nil))
        let composeTab = tabManager.tabs.last!
        XCTAssertEqual(tabManager.selectedTabId, composeTab.id)

        tabManager.closeTab(composeTab.id)

        XCTAssertEqual(tabManager.selectedTabId, inboxTab.id)
    }

    func test_closeTab_selectsFirstTab_whenClosingOnlyRemainingClosable() {
        tabManager.createTab(type: .compose(draftId: nil))
        let composeTab = tabManager.tabs.last!
        tabManager.selectTab(composeTab.id)

        tabManager.closeTab(composeTab.id)

        XCTAssertEqual(tabManager.selectedTabId, tabManager.tabs.first?.id)
    }

    func test_closeTab_handlesNonExistentTab() {
        let fakeId = UUID()

        // Should not crash
        tabManager.closeTab(fakeId)

        // Tabs unchanged
        XCTAssertEqual(tabManager.tabs.count, 1)
    }

    // MARK: - Tab Selection Tests

    func test_selectTab_updatesSelectedTabId() {
        tabManager.createTab(type: .compose(draftId: nil))
        let inboxTab = tabManager.tabs.first!

        tabManager.selectTab(inboxTab.id)

        XCTAssertEqual(tabManager.selectedTabId, inboxTab.id)
    }

    func test_currentTab_returnsSelectedTab() {
        tabManager.createTab(type: .compose(draftId: nil))
        let composeTab = tabManager.tabs.last!

        XCTAssertEqual(tabManager.currentTab?.id, composeTab.id)
    }

    // MARK: - Tab Title Update Tests

    func test_updateTabTitle_changesTitle() {
        let inboxTab = tabManager.tabs.first!

        tabManager.updateTabTitle(inboxTab.id, title: "Updated Title")

        XCTAssertEqual(tabManager.tabs.first?.title, "Updated Title")
    }

    func test_updateTabTitle_handlesNonExistentTab() {
        let fakeId = UUID()

        // Should not crash
        tabManager.updateTabTitle(fakeId, title: "Test")
    }

    // MARK: - Navigation Action Tests

    func test_openCompose_createsComposeTab() {
        let initialCount = tabManager.tabs.count

        tabManager.openCompose()

        XCTAssertEqual(tabManager.tabs.count, initialCount + 1)
        if case .compose = tabManager.tabs.last?.type {
            // Success
        } else {
            XCTFail("Expected compose tab type")
        }
    }

    func test_openCompose_withDraftId_passesId() {
        let draftId = UUID()

        tabManager.openCompose(draftId: draftId)

        if case .compose(let id) = tabManager.tabs.last?.type {
            XCTAssertEqual(id, draftId)
        } else {
            XCTFail("Expected compose tab type with draft ID")
        }
    }

    func test_openReply_createsComposeTab() {
        let email = EmailFixtures.createEmail(subject: "Original Subject")

        tabManager.openReply(to: email)

        if case .compose = tabManager.tabs.last?.type {
            // Success
        } else {
            XCTFail("Expected compose tab type")
        }
    }

    func test_openReply_setsReTitle() {
        let email = EmailFixtures.createEmail(subject: "Original Subject")

        tabManager.openReply(to: email)

        XCTAssertEqual(tabManager.tabs.last?.title, "Re: Original Subject")
    }

    func test_openReply_setsReplyContext() {
        let email = EmailFixtures.createEmail()

        tabManager.openReply(to: email)

        XCTAssertNotNil(tabManager.currentReplyContext)
        XCTAssertEqual(tabManager.currentReplyContext?.mode, .reply)
    }

    func test_openReplyAll_setsReplyAllMode() {
        let email = EmailFixtures.createEmail()

        tabManager.openReplyAll(to: email)

        XCTAssertEqual(tabManager.currentReplyContext?.mode, .replyAll)
    }

    func test_openForward_setsForwardMode() {
        let email = EmailFixtures.createEmail()

        tabManager.openForward(email: email)

        XCTAssertEqual(tabManager.currentReplyContext?.mode, .forward)
    }

    func test_openForward_setsFwdTitle() {
        let email = EmailFixtures.createEmail(subject: "Original Subject")

        tabManager.openForward(email: email)

        XCTAssertEqual(tabManager.tabs.last?.title, "Fwd: Original Subject")
    }

    // MARK: - AI Conversation Tests

    func test_openAIConversation_createsAITab() {
        tabManager.openAIConversation()

        if case .aiConversation = tabManager.tabs.last?.type {
            // Success
        } else {
            XCTFail("Expected AI conversation tab type")
        }
    }

    func test_openAIConversation_reusesExistingTab() {
        tabManager.openAIConversation()
        let firstAITab = tabManager.tabs.last!
        tabManager.selectTab(tabManager.tabs.first!.id) // Select inbox

        tabManager.openAIConversation()

        // Should not create new tab
        let aiTabs = tabManager.tabs.filter {
            if case .aiConversation = $0.type { return true }
            return false
        }
        XCTAssertEqual(aiTabs.count, 1)
        XCTAssertEqual(tabManager.selectedTabId, firstAITab.id)
    }

    // MARK: - Settings Tests

    func test_openSettings_createsSettingsTab() {
        tabManager.openSettings()

        if case .settings = tabManager.tabs.last?.type {
            // Success
        } else {
            XCTFail("Expected settings tab type")
        }
    }

    func test_openSettings_reusesExistingTab() {
        tabManager.openSettings()
        let settingsTab = tabManager.tabs.last!
        tabManager.selectTab(tabManager.tabs.first!.id)

        tabManager.openSettings()

        let settingsTabs = tabManager.tabs.filter {
            if case .settings = $0.type { return true }
            return false
        }
        XCTAssertEqual(settingsTabs.count, 1)
        XCTAssertEqual(tabManager.selectedTabId, settingsTab.id)
    }

    // MARK: - Tab Behavior Tests

    func test_tabBehavior_canBeChanged() {
        tabManager.tabBehavior = .autoOpenInNewTab

        XCTAssertEqual(tabManager.tabBehavior, .autoOpenInNewTab)
    }

    func test_savePreferences_savesToUserDefaults() {
        tabManager.tabBehavior = .replaceCurrentTab
        tabManager.savePreferences()

        let saved = UserDefaults.standard.string(forKey: "tabBehavior")
        XCTAssertEqual(saved, "replaceCurrentTab")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "tabBehavior")
    }

    // MARK: - Selected Email Tests

    func test_selectedEmail_defaultsToNil() {
        XCTAssertNil(tabManager.selectedEmail)
    }

    func test_selectedEmail_canBeSet() {
        let email = EmailFixtures.createEmail()

        tabManager.selectedEmail = email

        XCTAssertEqual(tabManager.selectedEmail?.id, email.id)
    }

    // MARK: - TabType Tests

    func test_tabType_defaultIcon_mail() {
        let type = TabType.mail(folderId: nil)
        XCTAssertEqual(type.defaultIcon, "envelope")
    }

    func test_tabType_defaultIcon_compose() {
        let type = TabType.compose(draftId: nil)
        XCTAssertEqual(type.defaultIcon, "square.and.pencil")
    }

    func test_tabType_defaultIcon_aiConversation() {
        let type = TabType.aiConversation(conversationId: nil)
        XCTAssertEqual(type.defaultIcon, "sparkles")
    }

    func test_tabType_defaultIcon_settings() {
        let type = TabType.settings
        XCTAssertEqual(type.defaultIcon, "gear")
    }

    func test_tabType_defaultTitle_values() {
        XCTAssertEqual(TabType.mail(folderId: nil).defaultTitle, "Inbox")
        XCTAssertEqual(TabType.compose(draftId: nil).defaultTitle, "New Message")
        XCTAssertEqual(TabType.aiConversation(conversationId: nil).defaultTitle, "AI Assistant")
        XCTAssertEqual(TabType.settings.defaultTitle, "Settings")
    }

    // MARK: - EnsoTab Tests

    func test_ensoTab_generatesUniqueId() {
        let tab1 = EnsoTab(type: .compose(draftId: nil))
        let tab2 = EnsoTab(type: .compose(draftId: nil))

        XCTAssertNotEqual(tab1.id, tab2.id)
    }

    func test_ensoTab_usesTypeDefaultIcon() {
        let tab = EnsoTab(type: .compose(draftId: nil))

        XCTAssertEqual(tab.icon, "square.and.pencil")
    }

    // MARK: - TabBehavior Tests

    func test_tabBehavior_displayNames() {
        XCTAssertEqual(TabBehavior.splitPaneWithTabs.displayName, "Split Pane + Tabs")
        XCTAssertEqual(TabBehavior.autoOpenInNewTab.displayName, "Auto-open in New Tabs")
        XCTAssertEqual(TabBehavior.replaceCurrentTab.displayName, "Replace Current Tab")
    }

    func test_tabBehavior_allCases() {
        XCTAssertEqual(TabBehavior.allCases.count, 3)
    }
}
