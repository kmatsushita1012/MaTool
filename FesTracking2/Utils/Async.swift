//
//  async.swift
//  FesTracking2
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
            return lhsError.localizedDescription == rhsError.localizedDescription // エラーの比較
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
            try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            throw AuthError.timeout("Operation timed out")
        }
        defer { group.cancelAll() } // 必ずキャンセルは投げておく
        return try await group.next()!
    }
}
