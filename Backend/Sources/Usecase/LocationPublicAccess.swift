import Foundation
import Shared

enum LocationPublicAccess {
    /// Location の一般公開可否（Period を日毎に集約して判定）
    /// - start: その日の start 最小値の 30 分前
    /// - end: その日の end 最大値
    static func isPublic(now: Date, periods: [Period]) -> Bool {
        let date = SimpleDate.from(now)
        let calendar = Calendar.japanGregorian
        let previousDate = calendar.date(byAdding: .day, value: -1, to: date.toDate).map(SimpleDate.from)
        let candidateDates = [previousDate, date].compactMap { $0 }

        return candidateDates.contains { candidateDate in
            publicRange(for: candidateDate, periods: periods)?.contains(now) == true
        }
    }

    static func publicRange(for date: SimpleDate, periods: [Period]) -> ClosedRange<Date>? {
        let targetPeriods = periods.filter { $0.date == date }
        guard !targetPeriods.isEmpty else { return nil }

        let startDateTimes = targetPeriods.map { Date.combine(date: date, time: $0.start) }
        let endDateTimes = targetPeriods.map { period -> Date in
            let startDateTime = Date.combine(date: date, time: period.start)
            let endDateTime = Date.combine(date: date, time: period.end)
            guard endDateTime < startDateTime else { return endDateTime }
            return Calendar.japanGregorian.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
        }
        guard let earliestStart = startDateTimes.min(),
              let latestEnd = endDateTimes.max()
        else { return nil }

        let startDateTime = earliestStart.addingTimeInterval(-30 * 60)
        let endDateTime = latestEnd
        return startDateTime...endDateTime
    }

    /// 一般公開時間外に管理者が Location を閲覧できる条件（変更しやすいように一箇所に集約）
    static func canViewOutsidePublicHours(user: UserRole, districtId: District.ID) -> Bool {
        guard case let .district(id) = user else { return false }
        return id == districtId
    }
}
