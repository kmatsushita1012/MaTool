import Foundation

public struct VoidSuccess: Equatable, Sendable {
    public init() {}
}

public typealias VoidResult<Failure: Swift.Error & Sendable> = Result<VoidSuccess, Failure>
public typealias VoidAppResult = VoidResult<AppError>
public typealias AppResult<Success: Sendable> = Result<Success, AppError>
