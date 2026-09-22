public struct Interval: Equatable, Hashable, Sendable {
    public let label: String
    public let value: Int

    public init(label: String, value: Int) {
        self.label = label
        self.value = value
    }
}

public extension Interval {
    static let sample = Interval(label: "1分", value: 60)

    static let options = [
        Interval(label: "5秒（確認用）", value: 5),
        Interval(label: "1分", value: 60),
        Interval(label: "2分", value: 120),
        Interval(label: "3分", value: 180),
        Interval(label: "5分", value: 300),
        Interval(label: "10分", value: 600),
        Interval(label: "15分", value: 900)
    ]
}
