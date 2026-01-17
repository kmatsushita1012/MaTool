//
//  Repository.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/09.
//

protocol Repository: Sendable {
    associatedtype Content: Sendable & Identifiable
    
    func put(_ item: Content) async throws -> Content
    func post(_ item: Content) async throws -> Content
    func delete(_ item: Content) async throws
}
