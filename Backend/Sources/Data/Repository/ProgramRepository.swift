//
//  ProgramRepository.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/05.
//

import Foundation
import Dependencies
import Shared

// MARK: - DependencyKey

enum ProgramRepositoryKey: DependencyKey {
    static let liveValue: ProgramRepositoryProtocol = {
        @Dependency(\.dataStoreFactory) var dataStoreFactory
        return ProgramRepository()
    }()
}

// MARK: - Repository

protocol ProgramRepositoryProtocol: Sendable {
    func get(festivalId: String, year: Int) async throws -> Program?
    func query(by festivalId: String, limit: Int?) async throws -> [Program]
    func post(_ Program: Program) async throws -> Program
    func put(_ Program: Program) async throws -> Program
    func delete(festivalId: String, year: Int) async throws
}

struct ProgramRepository: ProgramRepositoryProtocol {
    private let dataStore: DataStore

    init() {
        @Dependency(DataStoreFactoryKey.self) var dataStoreFactory
        self.dataStore = dataStoreFactory("matool_programs")
    }

    func get(festivalId: String, year: Int) async throws -> Program? {
        let record = try await dataStore.get(keys: ["festival_id": festivalId, "year": year], as: Record<Program>.self)
        return record?.content
    }

    func query(by festivalId: String, limit: Int?) async throws -> [Program] {
        let records =  try await dataStore.query(keyCondition: .equals("festival_id", festivalId), limit: limit, ascending: false, as: Record<Program>.self)
        return records.map{ $0.content }
    }

    func post(_ item: Program) async throws -> Program {
        let record = Record(item)
        try await dataStore.put(record)
        return item
    }

    func put(_ item: Program) async throws -> Program {
        let record = Record(item)
        try await dataStore.put(record)
        return item
    }

    func delete(festivalId: String, year: Int) async throws {
        try await dataStore.delete(keys: ["festival_id": festivalId, "year": year])
    }
}

extension ProgramRepositoryProtocol {
    func get(_ festivalId: String) async throws -> Program? {
        return try await query(by: festivalId, limit: 1).first
    }
    
    func query(by festivalId: String) async throws -> [Program] {
        return try await query(by: festivalId, limit: nil)
    }
}

