import Foundation
import Shared
import Testing
@testable import iOSApp

@Suite(.serialized)
@MainActor
struct ReplayControllerTests {
    private let beginning = Coordinate(latitude: 35.0, longitude: 139.0)
    private let ending = Coordinate(latitude: 35.001, longitude: 139.0)

    @Test("座標が空の場合は再生操作で状態を変更しない")
    func emptyCoordinatesCannotStartOrSeek() {
        let subject = ReplayController(name: "empty", coords: [], interval: 3600)

        subject.start()
        subject.seek(to: 0.5)

        #expect(subject.state == .paused)
        #expect(subject.annotation == nil)
        #expect(subject.seekValue == 0)
    }

    @Test("単一座標でのSeekはNaNにならず再生開始できる")
    func singleCoordinateHasValidProgress() {
        let subject = ReplayController(
            name: "single", coords: [beginning], interval: 3600
        )
        defer { subject.stop() }

        subject.start()
        subject.seek(to: 0.5)

        #expect(subject.annotation?.coordinate.latitude == beginning.latitude)
        #expect(subject.seekValue.isFinite)
        #expect(subject.seekValue == 0)
    }

    @Test("開始と一時停止は位置マーカーを維持したまま状態だけ変更する")
    func startAndPauseMaintainLocationMarker() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 1_000, interval: 3600
        )
        defer { subject.stop() }

        subject.start()
        #expect(subject.state == .playing(0))
        #expect(subject.annotation?.coordinate.latitude == beginning.latitude)

        subject.pause()
        #expect(subject.state == .paused)
        #expect(subject.annotation?.coordinate.latitude == beginning.latitude)
    }

    @Test("停止操作はマーカーとシーク位置を初期化する")
    func stopResetsPositionAndAnnotation() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 1_000, interval: 3600
        )
        subject.start()
        subject.seek(to: 1)
        #expect(subject.seekValue == 1)

        subject.stop()

        #expect(subject.state == .paused)
        #expect(subject.annotation == nil)
        #expect(subject.seekValue == 0)
    }

    @Test("シーク位置は0から1にクランプし地理座標も更新する")
    func seekClampsToAvailableRange() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 1_000, interval: 3600
        )
        defer { subject.stop() }
        subject.start()

        subject.seek(to: -2)
        #expect(subject.seekValue == 0)
        #expect(subject.annotation?.coordinate.latitude == beginning.latitude)
        #expect(subject.state == .playing(0))

        subject.seek(to: 4)
        #expect(subject.seekValue == 1)
        #expect(subject.annotation?.coordinate.latitude == ending.latitude)
        #expect(subject.state == .playing(1))
    }

    @Test("再生中の座標変更は旧タイマーとマーカーを破棄し新しい座標から準備する")
    func preparingNewRouteStopsCurrentPlayback() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 1_000, interval: 3600
        )
        subject.start()
        subject.prepare(coordinates: [ending, beginning])

        #expect(subject.state == .paused)
        #expect(subject.annotation == nil)
        #expect(subject.seekValue == 0)

        subject.start()
        #expect(subject.annotation?.coordinate.latitude == ending.latitude)
        subject.stop()
    }

    @Test("座標をnilにすると再生を始めても旧ルートが使われない")
    func clearingCoordinatesRemovesOldRoute() {
        let subject = ReplayController(name: "district", coords: [beginning])
        subject.start()
        subject.prepare(coordinates: nil)
        subject.start()

        #expect(subject.annotation == nil)
        #expect(subject.state == .paused)
    }

    @Test("更新ごとのTickは始点から終点へ進み、進捗が1を超えない")
    func ticksAdvanceAndClampProgress() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 50, interval: 3600
        )
        defer { subject.stop() }
        subject.start()

        subject.tick()
        #expect(subject.state == .playing(0.5))
        #expect(subject.seekValue == 0.5)
        subject.tick()
        #expect(subject.state == .playing(1))
        #expect(subject.seekValue == 1)
    }

    @Test("最後のTickで再生を停止し終了コールバックを一度呼ぶ")
    func endCallbackRunsWhenPlaybackCompletes() {
        var ended = 0
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 1_000, interval: 3600,
            onEnd: { ended += 1 }
        )
        subject.start()
        subject.tick()
        subject.tick()
        subject.tick()

        #expect(subject.state == .paused)
        #expect(subject.annotation == nil)
        #expect(ended == 1)
    }

    @Test("座標間を指定距離ごとに線形補間しシーク位置を一致させる")
    func interpolatesIntermediateCoordinates() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 50, interval: 3600
        )
        defer { subject.stop() }
        subject.start()
        subject.seek(to: 0.5)

        let latitude = subject.annotation?.coordinate.latitude ?? 0
        #expect(latitude > beginning.latitude)
        #expect(latitude < ending.latitude)
        #expect(abs(latitude - 35.0005) < 0.0002)
    }

    @Test("不正な補間間隔でも既存の経路が破棄されない")
    func invalidInterpolationStepUsesOriginalPoints() {
        let subject = ReplayController(
            name: "district", coords: [beginning, ending],
            stepDistance: 0, interval: 3600
        )
        defer { subject.stop() }
        subject.start()
        subject.seek(to: 1)

        #expect(subject.annotation?.coordinate.latitude == ending.latitude)
        #expect(subject.seekValue == 1)
    }
}
