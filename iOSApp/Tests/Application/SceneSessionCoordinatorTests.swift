import Foundation
import Testing
@testable import iOSApp

struct SceneSessionCoordinatorTests {
    @Test("新しいセッションを開始すると古いセッションを無効化する")
    func invalidatesPreviousSession() async {
        let coordinator = SceneSessionCoordinator()
        let first = await coordinator.beginSession()

        #expect(await coordinator.isCurrent(first))

        let second = await coordinator.beginSession()

        #expect(first != second)
        #expect(!(await coordinator.isCurrent(first)))
        #expect(await coordinator.isCurrent(second))
    }

    @Test("開始していない任意のセッションIDは常に無効")
    func rejectsUnknownSession() async {
        let coordinator = SceneSessionCoordinator()

        #expect(!(await coordinator.isCurrent(UUID())))
    }
}
