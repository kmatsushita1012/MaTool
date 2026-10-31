import ComposableArchitecture
import Dependencies
import Foundation

protocol SceneSessionCoordinatorProtocol: Sendable {
    func beginSession() async -> UUID
    func isCurrent(_ id: UUID) async -> Bool
}

actor SceneSessionCoordinator: SceneSessionCoordinatorProtocol {
    private var currentId = UUID()

    func beginSession() -> UUID {
        let id = UUID()
        currentId = id
        return id
    }

    func isCurrent(_ id: UUID) -> Bool {
        currentId == id
    }
}

enum SceneSessionCoordinatorKey: DependencyKey {
    static let liveValue: any SceneSessionCoordinatorProtocol = SceneSessionCoordinator()
}
