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

func withTimeout<T: Sendable>(
    seconds: Int,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = TimeoutRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            let operationTask = Task {
                do {
                    await race.resolve(.success(try await operation()))
                } catch {
                    await race.resolve(.failure(error))
                }
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(max(seconds, 0)) * 1_000_000_000
                    )
                    await race.resolve(.failure(AppError.auth(.timeout("タイムアウトしました"))))
                } catch {
                    // The operation completed first and canceled this timer.
                }
            }
            Task {
                await race.setContinuation(continuation)
                await race.add(operationTask)
                await race.add(timeoutTask)
            }
        }
    } onCancel: {
        Task {
            await race.resolve(.failure(CancellationError()))
        }
    }
}

private actor TimeoutRace<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    private var tasks: [Task<Void, Never>] = []

    func setContinuation(_ continuation: CheckedContinuation<Value, Error>) {
        if let result {
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
        }
    }

    func add(_ task: Task<Void, Never>) {
        if result != nil {
            task.cancel()
        } else {
            tasks.append(task)
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
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
