public enum PeriodEditMode: Equatable, Sendable {
    case update
    case create

    public var title: String {
        switch self {
        case .update: "更新"
        case .create: "新規作成"
        }
    }
}
