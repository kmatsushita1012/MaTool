import Shared

extension Shared.Anchor {
    var text: String {
        switch self {
        case .start:
            "出発"
        case .end:
            "到着"
        case .rest:
            "休憩"
        }
    }
}
