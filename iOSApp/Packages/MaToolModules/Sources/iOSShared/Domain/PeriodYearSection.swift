import Shared

public struct PeriodYearSection: Equatable, Identifiable, Sendable {
    public let year: Int
    public let periods: [Period]

    public var id: Int { year }

    public var text: String {
        "\(String(year))年"
    }

    public init(year: Int, periods: [Period]) {
        self.year = year
        self.periods = periods
    }
}
