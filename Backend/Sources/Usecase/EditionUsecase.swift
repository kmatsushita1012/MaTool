import Dependencies
import Foundation
import Shared

enum EditionUsecaseKey: DependencyKey {
    static let liveValue: EditionUsecaseProtocol = EditionUsecase()
}

protocol EditionUsecaseProtocol: Sendable {
    func query(festivalId: Festival.ID, user: UserRole) async throws -> EditionListResponse
    func create(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack
    func get(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack
    func put(festivalId: Festival.ID, year: Int, pack: EditionPack, user: UserRole) async throws -> EditionPack
    func putActive(festivalId: Festival.ID, editionId: Edition.ID, user: UserRole) async throws -> ActiveEdition
}

struct EditionUsecase: EditionUsecaseProtocol {
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(EditionRepositoryKey.self) var editionRepository
    @Dependency(ActiveEditionRepositoryKey.self) var activeEditionRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(PointRepositoryKey.self) var pointRepository
    @Dependency(PassageRepositoryKey.self) var passageRepository

    func query(festivalId: Festival.ID, user: UserRole) async throws -> EditionListResponse {
        try authorize(festivalId: festivalId, user: user)
        try await requireFestival(festivalId)

        async let editionsTask = editionRepository.query(by: festivalId)
        async let activeEditionTask = activeEditionRepository.get(festivalId: festivalId)
        let (editions, activeEdition) = try await (editionsTask, activeEditionTask)
        let sortedEditions = editions.sorted { $0.year < $1.year }

        if let activeEdition,
           activeEdition.festivalId != festivalId || !sortedEditions.contains(where: { $0.id == activeEdition.editionId }) {
            throw Error.internalServerError("有効Editionの参照が不正です。")
        }

        return EditionListResponse(editions: sortedEditions, activeEditionId: activeEdition?.editionId)
    }

    func create(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack {
        try authorize(festivalId: festivalId, user: user)
        try await requireFestival(festivalId)
        try validate(year: year)
        guard try await editionRepository.get(festivalId: festivalId, year: year) == nil else {
            throw Error.conflict("この祭典には同じ年度のEditionがすでに存在します。")
        }

        let edition = Edition(id: UUID().uuidString, festivalId: festivalId, year: year)
        _ = try await editionRepository.post(edition)
        return EditionPack(edition: edition, periods: [])
    }

    func get(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack {
        try authorize(festivalId: festivalId, user: user)
        try await requireFestival(festivalId)
        try validate(year: year)
        guard let edition = try await editionRepository.get(festivalId: festivalId, year: year) else {
            throw Error.notFound("指定されたEditionが見つかりません。")
        }
        return try await pack(for: edition)
    }

    func put(festivalId: Festival.ID, year: Int, pack: EditionPack, user: UserRole) async throws -> EditionPack {
        try authorize(festivalId: festivalId, user: user)
        try await requireFestival(festivalId)
        try validate(year: year)

        guard let edition = try await editionRepository.get(festivalId: festivalId, year: year) else {
            throw Error.notFound("指定されたEditionが見つかりません。")
        }
        guard pack.edition.id == edition.id,
              pack.edition.festivalId == festivalId,
              pack.edition.year == year else {
            throw Error.badRequest("URLと送信されたEditionの情報が一致しません。")
        }

        try await validate(periods: pack.periods, edition: edition)
        let currentPeriods = try await periodRepository.query(byEditionId: edition.id)
        let requestedIds = Set(pack.periods.map(\.id))
        for period in currentPeriods where !requestedIds.contains(period.id) {
            try await deleteRoutes(
                for: period,
                festivalId: festivalId,
                districtRepository: districtRepository,
                routeRepository: routeRepository,
                pointRepository: pointRepository,
                passageRepository: passageRepository
            )
            try await periodRepository.delete(id: period.id)
        }

        for period in pack.periods {
            _ = try await periodRepository.put(period)
        }

        return try await self.pack(for: edition)
    }

    func putActive(festivalId: Festival.ID, editionId: Edition.ID, user: UserRole) async throws -> ActiveEdition {
        try authorize(festivalId: festivalId, user: user)
        try await requireFestival(festivalId)
        guard let edition = try await editionRepository.get(id: editionId), edition.festivalId == festivalId else {
            throw Error.notFound("指定されたEditionが見つかりません。")
        }
        let activeEdition = ActiveEdition(festivalId: festivalId, editionId: edition.id)
        return try await activeEditionRepository.put(activeEdition)
    }

    private func pack(for edition: Edition) async throws -> EditionPack {
        let periods = try await periodRepository.query(byEditionId: edition.id)
        return EditionPack(edition: edition, periods: periods)
    }

    private func requireFestival(_ festivalId: Festival.ID) async throws {
        guard try await festivalRepository.get(id: festivalId) != nil else {
            throw Error.notFound("指定された祭典が見つかりません。")
        }
    }

    private func authorize(festivalId: Festival.ID, user: UserRole) throws {
        guard case let .headquarter(id) = user else {
            if case .guest = user {
                throw Error.unauthorized("ログインしてください。")
            }
            throw Error.forbidden("祭典本部の権限が必要です。")
        }
        guard id == festivalId else {
            throw Error.forbidden("対象祭典の本部ユーザーのみ操作できます。")
        }
    }

    private func validate(year: Int) throws {
        guard (1...9999).contains(year) else {
            throw Error.badRequest("年度が正しくありません。")
        }
    }

    private func validate(periods: [Period], edition: Edition) async throws {
        guard Set(periods.map(\.id)).count == periods.count else {
            throw Error.badRequest("日程IDが重複しています。")
        }
        let startKeys = periods.map { period in
            "\(period.date.year)-\(period.date.month)-\(period.date.day)@\(period.start.hour):\(period.start.minute)"
        }
        guard Set(startKeys).count == startKeys.count else {
            throw Error.badRequest("同じ日時の開始時刻を持つ日程は登録できません。")
        }

        for period in periods {
            guard !period.id.isEmpty,
                  period.editionId == edition.id,
                  period.date.isValid,
                  period.start.isValid,
                  period.end.isValid,
                  period.start <= period.end else {
                throw Error.badRequest("日程のID、所属、日時が正しくありません。")
            }
            if let existing = try await periodRepository.get(id: period.id),
               existing.editionId != edition.id {
                throw Error.badRequest("別のEditionに所属する日程は移動できません。")
            }
        }
    }
}
