import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol AutoCreateEditionUseCaseProtocol: Sendable {
    func callAsFunction(sourceEdition: Edition, targetYear: Int) async throws -> EditionPack
}

struct AutoCreateEditionUseCase: AutoCreateEditionUseCaseProtocol {
    @Dependency(EditionDataFetcherKey.self) private var editionDataFetcher

    func callAsFunction(sourceEdition: Edition, targetYear: Int) async throws -> EditionPack {
        let sourcePack = try await editionDataFetcher.fetch(
            festivalID: sourceEdition.festivalId,
            year: sourceEdition.year
        )
        guard !sourcePack.periods.isEmpty else {
            throw AppError.validation(.badRequest("コピー元の年度に日程がありません。"))
        }

        let calendar = Calendar.japanGregorian
        let shiftedPeriods = try sourcePack.periods.sorted().map { period -> (Period, SimpleDate) in
            let sourceDate = period.date.toDate
            guard let targetDate = sourceDate.sameWeekday(in: targetYear) else {
                throw AppError.validation(.badRequest("コピー元の日程を指定年度へ移せません。"))
            }

            let sourceComponents = calendar.dateComponents([.month, .weekOfMonth, .weekday], from: sourceDate)
            let targetComponents = calendar.dateComponents([.year, .month, .weekOfMonth, .weekday], from: targetDate)
            guard targetComponents.year == targetYear,
                  targetComponents.month == sourceComponents.month,
                  targetComponents.weekOfMonth == sourceComponents.weekOfMonth,
                  targetComponents.weekday == sourceComponents.weekday else {
                throw AppError.validation(.badRequest("コピー元の日程を指定年度に同じ月・第N曜日で移せません。"))
            }

            return (period, .from(targetDate))
        }

        let createdPack = try await editionDataFetcher.create(
            festivalID: sourceEdition.festivalId,
            year: targetYear
        )
        let periods = shiftedPeriods.map { pair in
            let (source, date) = pair
            return Period(
                id: UUID().uuidString,
                editionId: createdPack.edition.id,
                title: source.title,
                date: date,
                start: source.start,
                end: source.end
            )
        }
        let pack = EditionPack(edition: createdPack.edition, periods: periods)
        return try await editionDataFetcher.update(pack)
    }
}

enum AutoCreateEditionUseCaseKey: DependencyKey {
    static let liveValue: any AutoCreateEditionUseCaseProtocol = AutoCreateEditionUseCase()
}
