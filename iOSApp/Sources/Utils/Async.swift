//
//  Async.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//
import SwiftUI

enum AsyncValue<T> {
    case loading
    case success(T)
    case failure(Error)

    var value: T? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var error: Error? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    func when<Result>(
        loading: () -> Result,
        success: (T) -> Result,
        failure: (Error) -> Result
    ) -> Result {
        switch self {
        case .loading:
            return loading()
        case .success(let data):
            return success(data)
        case .failure(let error):
            return failure(error)
        }
    }
    
    mutating func update(_ closure: (inout T)->Void)->Bool{
        switch self {
        case .loading:
            return false
        case .success(var data):
            closure(&data)
            self = .success(data)
            return true
        case .failure(_):
            return false
        }
    }
}

extension AsyncValue {
    @ViewBuilder
    func viewWhen(
        loading: () -> some View,
        success: (T) -> some View,
        failure: (Error) -> some View
    ) -> some View {
        switch self {
        case .loading:
            loading()
        case .success(let value):
            success(value)
        case .failure(let error):
            failure(error)
        }
    }
}


extension AsyncValue: Equatable where T: Equatable {
    static func == (lhs: AsyncValue<T>, rhs: AsyncValue<T>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError.asAppError == rhsError.asAppError
        case (.success(let lhsValue), .success(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

func withTimeout<T>(
    seconds: Int,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(
                nanoseconds: UInt64(seconds) * 1_000_000_000
            )
            throw AppError.auth(.timeout("タイムアウトしました"))
        }

        guard let result = try await group.next() else {
            throw CancellationError()
        }

        group.cancelAll()
        return result
    }
}

func task<Value>(_ operation: () async throws -> Value, defaultError: AppError = .system(.unknown("予期しないエラーが発生しました。"))) async -> AppResult<Value> {
    do {
        let value = try await operation()
        return .success(value)
    } catch {
        let appError = error.asAppError
        if case .system(.unexpected) = appError {
            return .failure(defaultError)
        }
        return .failure(appError)
    }
}

func task(_ operation: () async throws -> Void) async -> VoidAppResult {
    let result: AppResult<Void> = await task(operation, defaultError: .system(.unknown("予期しないエラーが発生しました。")))
    return result.map{ VoidSuccess() }
}
