import Foundation

extension Date {
    func sameWeekday(in year: Int, calendar: Calendar = .current) -> Date? {
        let weekday = calendar.component(.weekday, from: self)
        let weekOfMonth = calendar.component(.weekOfMonth, from: self)
        let month = calendar.component(.month, from: self)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekOfMonth = weekOfMonth
        components.weekday = weekday

        return calendar.date(from: components)
    }
}
