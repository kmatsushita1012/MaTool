import Dependencies
import Shared
import Testing
@testable import iOSApp

struct PublicMapAdUsecaseTests {
    @Test("本部の地区選択では表示カウンタを増やさない")
    func headquarterSelectionsNeverCount() {
        for count in [0, 2, 5, 9] {
            let before = PublicMapAdCounter(districtSelectionCount: count)
            let result = PublicMapAdPolicy.evaluate(
                userRole: .headquarter("festival"),
                targetDistrictId: "district",
                defaultDistrictId: nil,
                counter: before
            )
            #expect(result.counter == before)
            #expect(!result.shouldShowInterstitial)
        }
    }

    @Test("既定地区と自身の地区は表示回数に数えない")
    func excludedDistrictsDoNotCount() {
        let before = PublicMapAdCounter(districtSelectionCount: 5)
        let own = PublicMapAdPolicy.evaluate(
            userRole: .district("mine"), targetDistrictId: "mine",
            defaultDistrictId: "other", counter: before
        )
        let defaultDistrict = PublicMapAdPolicy.evaluate(
            userRole: .guest, targetDistrictId: "other",
            defaultDistrictId: "other", counter: before
        )
        #expect(own.counter == before)
        #expect(defaultDistrict.counter == before)
        #expect(!own.shouldShowInterstitial)
        #expect(!defaultDistrict.shouldShowInterstitial)
    }

    @Test("既定地区がないゲストは初回5回の猶予後、3の倍数で表示する")
    func gracePeriodAndFrequency() {
        var counter = PublicMapAdCounter()
        var actualShowingCounts: [Int] = []
        for count in 1...12 {
            let decision = PublicMapAdPolicy.evaluate(
                userRole: .guest, targetDistrictId: "any",
                defaultDistrictId: nil, counter: counter
            )
            counter = decision.counter
            #expect(counter.districtSelectionCount == count)
            if decision.shouldShowInterstitial {
                actualShowingCounts.append(count)
            }
        }
        #expect(actualShowingCounts == [6, 9, 12])
    }

    @Test("既定地区が指定されていれば猶予期間は設けず3回ごとに表示する")
    func defaultDistrictDisablesGraceForOtherSelections() {
        var counter = PublicMapAdCounter()
        var showing: [Int] = []
        for count in 1...6 {
            let decision = PublicMapAdPolicy.evaluate(
                userRole: .guest, targetDistrictId: "other",
                defaultDistrictId: "default", counter: counter
            )
            counter = decision.counter
            if decision.shouldShowInterstitial { showing.append(count) }
        }
        #expect(showing == [3, 6])
    }

    @Test("地区アカウントの他地区選択も既定地区なしでは猶予されない")
    func districtAccountExcludesOnlyOwnDistrict() {
        let counter = PublicMapAdCounter(districtSelectionCount: 2)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .district("mine"), targetDistrictId: "other",
            defaultDistrictId: nil, counter: counter
        )
        #expect(decision.counter.districtSelectionCount == 3)
        #expect(decision.shouldShowInterstitial)
    }

    @Test("セッション開始は広告SDK初期化と全画面広告の先読みを行う")
    func prepareSessionPreloads() async {
        let spy = AdManagerSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.adManager = spy
        } operation: { PublicMapAdUsecase() }

        await useCase.prepareSession()

        #expect(await spy.calls == ["configure", "preload"])
    }

    @Test("表示する内容がない地区の選択では表示判定せず先読みする")
    func emptyDistrictPreloadsWithoutShowing() async {
        let spy = AdManagerSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.adManager = spy
        } operation: { PublicMapAdUsecase() }

        await useCase.handleDistrictSelectionResult(
            userRole: .guest, districtId: "empty", hasDisplayableContent: false
        )
        #expect(await spy.calls == ["preload"])
    }

    @Test("対象地区の選択が6回目になったら全画面広告の表示を要求する")
    func requestsPresentationOnSixthEligibleGuestSelection() async {
        let spy = AdManagerSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.adManager = spy
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        } operation: { PublicMapAdUsecase() }

        await useCase.prepareSession()
        for _ in 0..<6 {
            await useCase.handleDistrictSelectionResult(
                userRole: .guest, districtId: "other", hasDisplayableContent: true
            )
        }
        #expect(await spy.calls == [
            "configure", "preload",
            "preload", "preload", "preload", "preload", "preload", "present"
        ])
    }

    @Test("セッション準備をし直すと全画面広告の表示回数がリセットされる")
    func newSessionResetsSelectionCount() async {
        let spy = AdManagerSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.adManager = spy
        } operation: { PublicMapAdUsecase() }

        for _ in 0..<5 {
            await useCase.handleDistrictSelectionResult(
                userRole: .guest, districtId: "other", hasDisplayableContent: true
            )
        }
        await useCase.prepareSession()
        await useCase.handleDistrictSelectionResult(
            userRole: .guest, districtId: "other", hasDisplayableContent: true
        )

        #expect(await spy.calls.filter { $0 == "present" }.isEmpty)
    }
}
