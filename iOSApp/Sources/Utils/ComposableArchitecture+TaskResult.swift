//
//  ComposableArchitecture+TaskResult.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/15.
//

import ComposableArchitecture

struct VoidSuccess: Equatable {
    init() {}
}

typealias VoidResult<Failure: Swift.Error> = Result<VoidSuccess, Failure>

extension VoidResult where Success == VoidSuccess {
    static var success: Self {
        .success(.init())
    }
}

typealias VoidTaskResult = TaskResult<VoidSuccess>

extension TaskResult where Success == VoidSuccess {
    init(catching body: @Sendable () async throws -> Void) async {
        do {
            try await body()
            self = .success(VoidSuccess())
        } catch {
            self = .failure(error)
        }
    }
}

extension Effect {
    static func task<Success>(_ action: @escaping (TaskResult<Success>) -> Action, operation: @escaping @Sendable () async throws -> Success ) -> Self {
        return Self.run { send in
            await send(
                action(
                    TaskResult {
                        try await operation()
                    }
                )
            )
        }
    }
    
    static func task(_ action: @escaping (VoidTaskResult) -> Action, operation: @escaping @Sendable () async throws -> Void) -> Self {
        return Self.run { send in
            await send(
                action(
                    VoidTaskResult {
                        try await operation()
                    }
                )
            )
        }
    }
}

extension Effect {
    static var dismiss: Self {
        @Dependency(\.dismiss) var dismiss
        return .run { _ in
            await dismiss()
        }
    }
}
