import Foundation

#if DEBUG
enum DebugAPIEnvironment: String, CaseIterable, Identifiable, Sendable {
    case prod
    case dev
    case custom

    var id: String { rawValue }

    func baseURL(baseURL: String, customStage: String) -> String {
        switch self {
        case .prod:
            return baseURL
        case .dev:
            return "\(baseURL)/dev"
        case .custom:
            let stage = customStage.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return stage.isEmpty ? baseURL : "\(baseURL)/\(stage)"
        }
    }
}
#endif
