enum Mode: Equatable {
    case update
    case create
}

extension Mode {
    var title: String {
        switch self {
        case .update:
            return "更新"
        case .create:
            return "新規作成"
        }
    }
}
