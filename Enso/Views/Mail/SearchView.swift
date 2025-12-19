//
//  SearchView.swift
//  Enso
//

import SwiftUI
import SwiftData

// MARK: - Focused Values for Search Activation

struct SearchActivationKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var searchActivation: Binding<Bool>? {
        get { self[SearchActivationKey.self] }
        set { self[SearchActivationKey.self] = newValue }
    }
}

// MARK: - Searchable View Modifier

/// View modifier that adds native searchable interface to any view
struct SearchableEmailsModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.searchService) private var searchService

    let folder: Folder?
    @Binding var selectedEmail: Email?

    @State private var searchText = ""
    @State private var isSearchActive = false

    func body(content: Content) -> some View {
        content
            .focusedValue(\.searchActivation, $isSearchActive)
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                placement: .toolbar,
                prompt: "Search emails..."
            )
            .searchSuggestions {
                if searchText.isEmpty && !searchService.searchHistory.isEmpty {
                    Section("Recent Searches") {
                        ForEach(searchService.searchHistory.prefix(5), id: \.self) { query in
                            Label(query, systemImage: "clock")
                                .searchCompletion(query)
                        }
                    }

                    Button("Clear History", role: .destructive) {
                        searchService.clearHistory()
                    }
                    .foregroundStyle(.red)
                }
            }
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .onSubmit(of: .search) {
                searchService.recordSearch(searchText)
            }
            .overlay(alignment: .topTrailing) {
                if isSearchActive {
                    SearchResultsOverlay(
                        searchText: searchText,
                        results: searchService.results,
                        isSearching: searchService.isSearching,
                        onSelectEmail: { email in
                            selectedEmail = email
                            isSearchActive = false
                            searchText = ""
                        }
                    )
                    .frame(width: 420, height: 360, alignment: .top)
                    .padding(.top, 8)
                    .padding(.trailing, 20)
                }
            }
    }

    private func performSearch(query: String) {
        let serviceScope: SearchService.SearchScope = folder == nil ? .all : .currentFolder

        Task {
            await searchService.search(
                query: query,
                scope: serviceScope,
                folder: folder,
                modelContext: modelContext
            )
        }
    }
}

// MARK: - Search Results Overlay

struct SearchResultsOverlay: View {
    let searchText: String
    let results: [SearchService.SearchResult]
    let isSearching: Bool
    let onSelectEmail: (Email) -> Void

    var body: some View {
        Group {
            if isSearching {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
            } else if !results.isEmpty {
                List(results) { result in
                    SearchResultRow(result: result)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectEmail(result.email)
                        }
                }
                .listStyle(.plain)
            } else if !searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No emails match \"\(searchText)\"")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

// MARK: - View Extension

extension View {
    func searchableEmails(folder: Folder?, selectedEmail: Binding<Email?>) -> some View {
        modifier(SearchableEmailsModifier(folder: folder, selectedEmail: selectedEmail))
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchService.SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(result.email.isRead ? .clear : .blue)
                    .frame(width: 8, height: 8)

                Text(result.email.senderDisplayName)
                    .font(.headline)
                    .fontWeight(result.email.isRead ? .regular : .semibold)
                    .lineLimit(1)

                Spacer()

                Text(result.matchField)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())

                Text(result.email.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.email.subject)
                .font(.subheadline)
                .fontWeight(result.email.isRead ? .regular : .medium)
                .lineLimit(1)

            Text(result.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Indicators
            HStack(spacing: 8) {
                if let folderName = result.email.folder?.name {
                    Label(folderName, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if result.email.hasAttachments {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if result.email.isStarred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        Text("Email List Content")
            .searchableEmails(folder: nil, selectedEmail: .constant(nil))
    }
}
