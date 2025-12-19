//
//  SearchService.swift
//  Enso
//

import Foundation
import SwiftUI
import SwiftData
import SwiftMail

/// Service for searching emails locally and on server
@MainActor
@Observable
final class SearchService {

    // MARK: - Types

    enum SearchScope: String, CaseIterable {
        case all = "All Mail"
        case currentFolder = "Current Folder"
        case subject = "Subject"
        case sender = "Sender"
        case body = "Body"
        case attachments = "Has Attachments"
        case unread = "Unread"
        case starred = "Starred"
    }

    struct SearchResult: Identifiable {
        let id: UUID
        let email: Email
        let matchField: String
        let snippet: String
    }

    // MARK: - Properties

    private(set) var isSearching = false
    private(set) var results: [SearchResult] = []
    private(set) var searchHistory: [String] = []

    private let keychainService: KeychainService

    // MARK: - Initialization

    init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService
        loadSearchHistory()
    }

    // MARK: - Local Search

    /// Search emails locally in SwiftData
    func searchLocal(
        query: String,
        scope: SearchScope,
        folder: Folder?,
        modelContext: ModelContext
    ) -> [SearchResult] {
        guard !query.isEmpty || scope == .attachments || scope == .unread || scope == .starred else {
            return []
        }

        let lowercaseQuery = query.lowercased()

        // Fetch all emails and filter in memory to avoid complex predicate issues
        var descriptor = FetchDescriptor<Email>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        do {
            let allEmails = try modelContext.fetch(descriptor)

            let filtered = allEmails.filter { email in
                switch scope {
                case .all:
                    let matchesQuery = email.subject.localizedCaseInsensitiveContains(query) ||
                        email.fromAddress.localizedCaseInsensitiveContains(query) ||
                        (email.fromName?.localizedCaseInsensitiveContains(query) ?? false) ||
                        (email.textBody?.localizedCaseInsensitiveContains(query) ?? false)
                    if let account = folder?.account {
                        return email.account?.id == account.id && matchesQuery
                    }
                    return matchesQuery

                case .currentFolder:
                    guard let folderId = folder?.id else { return false }
                    return email.folder?.id == folderId && (
                        email.subject.localizedCaseInsensitiveContains(query) ||
                        email.fromAddress.localizedCaseInsensitiveContains(query) ||
                        (email.textBody?.localizedCaseInsensitiveContains(query) ?? false)
                    )

                case .subject:
                    return email.subject.localizedCaseInsensitiveContains(query)

                case .sender:
                    return email.fromAddress.localizedCaseInsensitiveContains(query) ||
                        (email.fromName?.localizedCaseInsensitiveContains(query) ?? false)

                case .body:
                    return email.textBody?.localizedCaseInsensitiveContains(query) ?? false

                case .attachments:
                    return email.hasAttachments

                case .unread:
                    return !email.isRead

                case .starred:
                    return email.isStarred
                }
            }

            let limitedResults = Array(filtered.prefix(100))

            return limitedResults.map { email in
                let matchField = determineMatchField(email: email, query: lowercaseQuery, scope: scope)
                let snippet = createSnippet(email: email, query: lowercaseQuery)
                return SearchResult(id: email.id, email: email, matchField: matchField, snippet: snippet)
            }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }

    /// Perform search with progress tracking
    func search(
        query: String,
        scope: SearchScope,
        folder: Folder?,
        modelContext: ModelContext
    ) async {
        isSearching = true
        results = []

        // Perform local search
        results = searchLocal(query: query, scope: scope, folder: folder, modelContext: modelContext)

        isSearching = false
    }

    /// Search on server via IMAP
    func searchServer(
        query: String,
        account: Account,
        folder: Folder,
        modelContext: ModelContext
    ) async throws -> [UInt32] {
        let imapService = IMAPService(account: account, keychainService: keychainService)

        try await imapService.connect()

        // Build search criteria
        var criteria: [SwiftMail.SearchCriteria] = []

        // Search in subject, from, and body
        criteria.append(.or(.subject(query), .from(query)))

        let uids = try await imapService.search(mailbox: folder.path, criteria: criteria)

        await imapService.disconnect()

        return uids
    }

    // MARK: - Search History

    private func loadSearchHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "searchHistory") {
            searchHistory = history
        }
    }

    func recordSearch(_ query: String) {
        guard !query.isEmpty else { return }

        // Remove if exists, add to front
        searchHistory.removeAll { $0 == query }
        searchHistory.insert(query, at: 0)

        // Keep last 20 searches
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }

        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    func clearHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: "searchHistory")
    }

    // MARK: - Helpers

    private func determineMatchField(email: Email, query: String, scope: SearchScope) -> String {
        switch scope {
        case .subject:
            return "Subject"
        case .sender:
            return "Sender"
        case .body:
            return "Body"
        case .attachments:
            return "Has Attachments"
        case .unread:
            return "Unread"
        case .starred:
            return "Starred"
        case .all, .currentFolder:
            if email.subject.lowercased().contains(query) {
                return "Subject"
            } else if email.fromAddress.lowercased().contains(query) ||
                        (email.fromName?.lowercased().contains(query) ?? false) {
                return "Sender"
            } else {
                return "Body"
            }
        }
    }

    private func createSnippet(email: Email, query: String) -> String {
        guard !query.isEmpty else {
            return email.snippet ?? email.textBody?.prefix(100).description ?? ""
        }

        // Find query in body and create context snippet
        if let body = email.textBody?.lowercased(),
           let range = body.range(of: query) {
            let start = body.index(range.lowerBound, offsetBy: -30, limitedBy: body.startIndex) ?? body.startIndex
            let end = body.index(range.upperBound, offsetBy: 70, limitedBy: body.endIndex) ?? body.endIndex
            var snippet = String(email.textBody![start..<end])
            if start != body.startIndex { snippet = "..." + snippet }
            if end != body.endIndex { snippet = snippet + "..." }
            return snippet
        }

        return email.snippet ?? email.textBody?.prefix(100).description ?? ""
    }
}

// MARK: - Environment Key

private struct SearchServiceKey: EnvironmentKey {
    static let defaultValue: SearchService = SearchService()
}

extension EnvironmentValues {
    var searchService: SearchService {
        get { self[SearchServiceKey.self] }
        set { self[SearchServiceKey.self] = newValue }
    }
}
