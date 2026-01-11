//
//  Extensions.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/09.
//

extension Array where Element: Equatable & Identifiable {
    func update<R: Repository>(
        with new: [Element],
        repository: R
    ) async throws -> [Element] where R.Content == Element {
        let oldItems = self
        
        return try await oldItems.diff(
            with: new,
            onAdd: { try await repository.post($0) },
            onUpdate: { try await repository.put( $0) },
            onDelete: { try await repository.delete( $0.id) }
        )
    }
}

extension SimpleDate {
    var sortableKey: String {
        "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}
