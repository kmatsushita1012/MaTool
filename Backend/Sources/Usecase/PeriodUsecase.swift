//
//  PeriodUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum PeriodUsecaseKey: DependencyKey {
    static let liveValue: PeriodUsecaseProtocol = PeriodUsecase()
}

protocol PeriodUsecaseProtocol: Sendable {
    func query(by festivalId: String) async throws -> [Period]
    func queryLatest(by festivalId: String) async throws -> [Period]
    func query(festivalId: String, year: Int) async throws -> [Period]
    func get(id: String) async throws -> Period
    func post(period: Period, user: UserRole) async throws -> Period
    func put(id: String, period: Period, user: UserRole) async throws -> Period
    func delete(id: String, user: UserRole) async throws
}

struct PeriodUsecase: PeriodUsecaseProtocol {
    @Dependency(PeriodRepositoryKey.self) var repository
    
    func query(by festivalId: String) async throws -> [Period] {
        return try await repository.query(festivalId: festivalId)
    }
    
    func queryLatest(by festivalId: String) async throws -> [Period] {
        let periods = try await repository.query(festivalId: festivalId)
        if let latestYear = periods.map({ $0.date.year }).max() {
            return periods.filter { $0.date.year == latestYear }
        } else {
            return []
        }
    }
    
    func query(festivalId: String, year: Int) async throws -> [Period] {
        guard year > 0 else {
            throw Error.badRequest("年が正しくありません。")
        }
        return try await repository.query(festivalId: festivalId, year: year)
    }
    
    func get(id: String) async throws -> Period {
        guard let period = try await repository.get(id: id) else {
            throw Error.notFound("指定された日程が取得できませんでした。")
        }
        return period
    }
    
    func post(period: Period, user: UserRole) async throws -> Period {
        guard case let .headquarter(id) = user,
              period.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        return try await repository.post(period)
    }
    
    func put(id: String, period: Period, user: UserRole) async throws -> Period {
        guard case let .headquarter(festivalId) = user,
              period.festivalId == festivalId else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        guard period.id == id else {
            throw Error.badRequest("リクエストが不正です。")
        }
        return try await repository.put(period)
    }
    
    func delete(id: String, user: UserRole) async throws {
        guard let period = try await repository.get(id: id) else {
            throw Error.notFound("データが見つかりません。")
        }
        guard case let .headquarter(festivalId) = user,
            period.festivalId == festivalId else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        return try await repository.delete(id: id)
    }
}
