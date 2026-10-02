import Testing
@testable import iOSApp

struct PublicMapFeatureTests {
    @Test("地区の連続選択では最新リクエストだけを受理する")
    func 地区の連続選択では最新リクエストだけを受理する() {
        var gate = PublicMapDistrictLaunchRequestGate()
        let requestA = gate.begin()
        let requestB = gate.begin()

        #expect(!gate.accepts(requestA))
        #expect(gate.accepts(requestB))
    }

    @Test("現在地一覧へ切り替えると進行中の地区取得を無効にする")
    func 現在地一覧へ切り替えると進行中の地区取得を無効にする() {
        var gate = PublicMapDistrictLaunchRequestGate()
        let request = gate.begin()

        gate.invalidate()

        #expect(!gate.accepts(request))
    }
}
