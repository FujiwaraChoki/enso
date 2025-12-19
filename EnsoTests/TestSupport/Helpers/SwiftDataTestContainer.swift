//
//  SwiftDataTestContainer.swift
//  EnsoTests
//

import Foundation
import SwiftData
import XCTest
@testable import Enso

/// In-memory SwiftData container for testing
@MainActor
final class SwiftDataTestContainer {
    let container: ModelContainer
    let context: ModelContext

    /// Initialize with an in-memory container containing all Enso models
    init() throws {
        let schema = Schema([
            Account.self,
            Email.self,
            Folder.self,
            Attachment.self,
            AIConversation.self,
            AIMessage.self
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    // MARK: - CRUD Operations

    /// Insert a model into the context
    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    /// Insert multiple models into the context
    func insert<T: PersistentModel>(contentsOf models: [T]) {
        for model in models {
            context.insert(model)
        }
    }

    /// Delete a model from the context
    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    /// Save any pending changes
    func save() throws {
        try context.save()
    }

    // MARK: - Fetch Operations

    /// Fetch all models of a given type
    func fetch<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try context.fetch(descriptor)
    }

    /// Fetch models with a predicate
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.predicate = predicate
        return try context.fetch(descriptor)
    }

    /// Fetch models with sorting
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        sortBy sortDescriptors: [SortDescriptor<T>],
        predicate: Predicate<T>? = nil
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = sortDescriptors
        descriptor.predicate = predicate
        return try context.fetch(descriptor)
    }

    /// Fetch a single model by predicate
    func fetchFirst<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> T? {
        var descriptor = FetchDescriptor<T>()
        descriptor.predicate = predicate
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Count Operations

    /// Count models of a given type
    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        return try context.fetchCount(descriptor)
    }

    /// Count models with a predicate
    func count<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> Int {
        var descriptor = FetchDescriptor<T>()
        descriptor.predicate = predicate
        return try context.fetchCount(descriptor)
    }

    // MARK: - Reset Operations

    /// Delete all entities of a specific type
    func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let items = try fetch(type)
        for item in items {
            context.delete(item)
        }
    }

    /// Reset the container by deleting all entities
    func reset() throws {
        try deleteAll(Attachment.self)
        try deleteAll(Email.self)
        try deleteAll(Folder.self)
        try deleteAll(Account.self)
        try deleteAll(AIMessage.self)
        try deleteAll(AIConversation.self)
    }
}
