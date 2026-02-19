import Foundation
import Shared

enum LocationPublicAccess {
    /// Location の一般公開可否（Period を日毎に集約して判定）
    /// - start: その日の start 最小値の 30 分前
    /// - end: その日の end 最大値
    static func isPublic(now: Date, periods: [Period]) -> Bool {
        guard let range = publicRange(for: SimpleDate.from(now), periods: periods) else { return false }
        return range.contains(now)
    }

    static func publicRange(for date: SimpleDate, periods: [Period]) -> ClosedRange<Date>? {
        let targetPeriods = periods.filter { $0.date.sortableKey == date.sortableKey }
        guard let minStart = targetPeriods.map(\.start).min(),
              let maxEnd = targetPeriods.map(\.end).max()
        else { return nil }

        let startDateTime = Date.combine(date: date, time: minStart).addingTimeInterval(-30 * 60)
        let endDateTime = Date.combine(date: date, time: maxEnd)
        return startDateTime...endDateTime
    }

    /// 一般公開時間外に管理者が Location を閲覧できる条件（変更しやすいように一箇所に集約）
    static func canViewOutsidePublicHours(user: UserRole, districtId: District.ID) -> Bool {
        guard case let .district(id) = user else { return false }
        return id == districtId
    }
}
