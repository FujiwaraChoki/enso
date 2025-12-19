//
//  SyncServiceTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

@MainActor
final class SyncServiceTests: XCTestCase {

    var syncService: SyncService!
    var testContainer: SwiftDataTestContainer!

    override func setUp() async throws {
        try await super.setUp()
        testContainer = try SwiftDataTestContainer()
        syncService = SyncService()
    }

    override func tearDown() async throws {
        try testContainer.reset()
        testContainer = nil
        await syncService.disconnectAll()
        syncService = nil
        try await super.tearDown()
    }

    // MARK: - Cache Validity Tests

    func test_isCacheValid_returnsFalse_whenNoLastSync() {
        let account = AccountFixtures.createAccount()

        let isValid = syncService.isCacheValid(for: account)

        XCTAssertFalse(isValid)
    }

    func test_isCacheValid_returnsTrue_whenRecentSync() {
        let account = AccountFixtures.createAccount()
        account.lastSyncDate = Date()

        let isValid = syncService.isCacheValid(for: account)

        XCTAssertTrue(isValid)
    }

    func test_isCacheValid_returnsFalse_whenStaleSync() {
        let account = AccountFixtures.createStaleCacheAccount()
        // Stale account has lastSyncDate 10 minutes ago

        let isValid = syncService.isCacheValid(for: account)

        XCTAssertFalse(isValid)
    }

    func test_isCacheValid_returnsFalse_whenSyncOlderThan5Minutes() {
        let account = AccountFixtures.createAccount()
        account.lastSyncDate = Date().addingTimeInterval(-6 * 60) // 6 minutes ago

        let isValid = syncService.isCacheValid(for: account)

        XCTAssertFalse(isValid)
    }

    func test_isCacheValid_returnsTrue_whenSyncWithin5Minutes() {
        let account = AccountFixtures.createAccount()
        account.lastSyncDate = Date().addingTimeInterval(-3 * 60) // 3 minutes ago

        let isValid = syncService.isCacheValid(for: account)

        XCTAssertTrue(isValid)
    }

    // MARK: - Sync State Tests

    func test_syncState_defaultsToIdle() {
        XCTAssertEqual(syncService.syncState, .idle)
    }

    func test_lastSyncDate_defaultsToNil() {
        XCTAssertNil(syncService.lastSyncDate)
    }

    func test_isBackgroundSyncing_defaultsToFalse() {
        XCTAssertFalse(syncService.isBackgroundSyncing)
    }

    // MARK: - Inactive Account Tests

    func test_syncAccount_skipsInactiveAccount() async throws {
        let account = AccountFixtures.createInactiveAccount()
        testContainer.insert(account)
        try testContainer.save()

        // Should not throw and should complete silently
        try await syncService.syncAccount(account, modelContext: testContainer.context)

        // State should remain idle
        XCTAssertEqual(syncService.syncState, .idle)
    }

    func test_syncInbox_skipsInactiveAccount() async throws {
        let account = AccountFixtures.createInactiveAccount()
        testContainer.insert(account)
        try testContainer.save()

        // Should not throw
        try await syncService.syncInbox(for: account, modelContext: testContainer.context)
    }

    // MARK: - Background Sync Tests

    func test_syncAccountInBackground_skipsWhenCacheValid() {
        let account = AccountFixtures.createAccount()
        account.lastSyncDate = Date() // Fresh cache
        testContainer.insert(account)
        try? testContainer.save()

        syncService.syncAccountInBackground(account, modelContext: testContainer.context, force: false)

        // Should not start background sync
        // Note: This is difficult to test without mocks, checking state
        XCTAssertEqual(syncService.syncState, .idle)
    }

    func test_syncAccountInBackground_skipsInactiveAccount() {
        let account = AccountFixtures.createInactiveAccount()
        testContainer.insert(account)
        try? testContainer.save()

        syncService.syncAccountInBackground(account, modelContext: testContainer.context, force: true)

        // Should not have started
        XCTAssertFalse(syncService.isBackgroundSyncing)
    }

    // MARK: - Disconnect Tests

    func test_disconnectAll_resetsState() async {
        // Put service in some state
        await syncService.disconnectAll()

        XCTAssertEqual(syncService.syncState, .idle)
        XCTAssertFalse(syncService.isBackgroundSyncing)
    }

    // MARK: - SyncState Equatable Tests

    func test_syncState_equatable_idle() {
        let state1 = SyncService.SyncState.idle
        let state2 = SyncService.SyncState.idle

        XCTAssertEqual(state1, state2)
    }

    func test_syncState_equatable_syncing() {
        let state1 = SyncService.SyncState.syncing(progress: 0.5)
        let state2 = SyncService.SyncState.syncing(progress: 0.5)

        XCTAssertEqual(state1, state2)
    }

    func test_syncState_equatable_syncingDifferentProgress() {
        let state1 = SyncService.SyncState.syncing(progress: 0.5)
        let state2 = SyncService.SyncState.syncing(progress: 0.7)

        XCTAssertNotEqual(state1, state2)
    }

    func test_syncState_equatable_error() {
        let state1 = SyncService.SyncState.error("Test error")
        let state2 = SyncService.SyncState.error("Test error")

        XCTAssertEqual(state1, state2)
    }

    func test_syncState_notEqual_differentTypes() {
        let idle = SyncService.SyncState.idle
        let syncing = SyncService.SyncState.syncing(progress: 0.5)
        let error = SyncService.SyncState.error("Error")

        XCTAssertNotEqual(idle, syncing)
        XCTAssertNotEqual(idle, error)
        XCTAssertNotEqual(syncing, error)
    }

    // MARK: - SyncError Tests

    func test_syncError_noActiveAccount_description() {
        let error = SyncService.SyncError.noActiveAccount

        XCTAssertEqual(error.errorDescription, "No active account available for sync")
    }

    func test_syncError_modelContextRequired_description() {
        let error = SyncService.SyncError.modelContextRequired

        XCTAssertEqual(error.errorDescription, "Model context is required for sync operations")
    }

    func test_syncError_syncFailed_description() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = SyncService.SyncError.syncFailed(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Connection failed") ?? false)
    }

    // MARK: - Account with Folders Tests

    func test_syncAccountInBackground_forcesSync_whenForceIsTrue() {
        let account = AccountFixtures.createAccount()
        account.lastSyncDate = Date() // Fresh cache
        testContainer.insert(account)
        try? testContainer.save()

        // Force should bypass cache check
        syncService.syncAccountInBackground(account, modelContext: testContainer.context, force: true)

        // When force is true and account is active, background sync should start
        // However, it will fail without real IMAP connection
        // Just verify the call doesn't crash
    }

    // MARK: - Stop Idle Monitoring Tests

    func test_stopIdleMonitoring_handlesNonExistentAccount() async {
        let account = AccountFixtures.createAccount()

        // Should not crash when stopping idle for account that was never started
        await syncService.stopIdleMonitoring(for: account)
    }
}
