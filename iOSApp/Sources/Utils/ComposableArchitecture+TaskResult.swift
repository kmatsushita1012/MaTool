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
typealias VoidAppResult = VoidResult<AppError>
typealias AppResult<Success> = Result<Success, AppError>

extension VoidResult where Success == VoidSuccess {
    static var success: Self {
        .success(.init())
    }
}

extension Effect {
    static func task<Success>(_ action: @escaping (AppResult<Success>) -> Action, operation: @escaping @Sendable () async throws -> Success ) -> Self {
        return Self.run { send in
            do {
                let value = try await operation()
                await send(action(.success(value)))
            } catch {
                await send(action(.failure(error.asAppError)))
            }
        }
    }
    
    static func task(_ action: @escaping (VoidAppResult) -> Action, operation: @escaping @Sendable () async throws -> Void) -> Self {
        return Self.run { send in
            do {
                try await operation()
                await send(action(.success))
            } catch {
                await send(action(.failure(error.asAppError)))
            }
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
