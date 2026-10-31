import Combine
import Shared
import Testing
@testable import iOSApp

@MainActor
struct ReplayControllerTests {
    @Test("再生位置の変更を値として通知する")
    func seekPublishesNewFrame() {
        let start = Coordinate(latitude: 35, longitude: 139)
        let end = Coordinate(latitude: 35.01, longitude: 139)
        let controller = ReplayController(name: "屋台", coords: [start, end], interval: 60)
        var frames: [ReplayController.Frame] = []
        let subscription = controller.$frame.sink { frames.append($0) }

        controller.start()
        let initial = controller.frame
        controller.seek(to: 1)

        #expect(initial.annotation?.coordinate == start)
        #expect(initial.progress == 0)
        #expect(controller.frame.annotation?.coordinate == end)
        #expect(controller.frame.progress == 1)
        #expect(initial != controller.frame)
        #expect(frames.count == 3)
        #expect(frames.last == controller.frame)
        controller.stop()
        #expect(controller.frame.annotation == nil)
        withExtendedLifetime(subscription) {}
    }

    @Test("地点が一つでも進捗は有限値になる")
    func singleCoordinateHasFiniteProgress() {
        let coordinate = Coordinate(latitude: 35, longitude: 139)
        let controller = ReplayController(name: "屋台", coords: [coordinate], interval: 60)

        controller.start()
        #expect(controller.frame.annotation?.coordinate == coordinate)
        #expect(controller.frame.progress == 0)
        controller.stop()
    }
}
