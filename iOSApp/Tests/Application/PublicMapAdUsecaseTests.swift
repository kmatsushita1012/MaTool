import Testing
@testable import iOSApp

struct PublicMapAdUsecaseTests {
    @Test
    func 本部権限では広告表示しない() {
        let counter = PublicMapAdCounter(districtSelectionCount: 2)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .headquarter("festival"),
            targetDistrictId: "district-b",
            defaultDistrictId: "district-a",
            counter: counter
        )

        #expect(decision.counter == counter)
        #expect(!decision.shouldShowInterstitial)
    }

    @Test
    func 自町defaultDistrictではカウントしない() {
        let counter = PublicMapAdCounter(districtSelectionCount: 2)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            defaultDistrictId: "district-a",
            counter: counter
        )

        #expect(decision.counter == counter)
        #expect(!decision.shouldShowInterstitial)
    }

    @Test
    func お気に入り外の町では3回に1回表示する() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-b",
            defaultDistrictId: "district-a",
            counter: .init(districtSelectionCount: 2)
        )

        #expect(decision.counter.districtSelectionCount == 3)
        #expect(decision.shouldShowInterstitial)
    }

    @Test
    func お気に入りも権限もない場合は最初の5回をスキップする() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            defaultDistrictId: nil,
            counter: .init(districtSelectionCount: 4)
        )

        #expect(decision.counter.districtSelectionCount == 5)
        #expect(!decision.shouldShowInterstitial)
    }

    @Test
    func お気に入りも権限もない場合は6回目で表示する() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            defaultDistrictId: nil,
            counter: .init(districtSelectionCount: 5)
        )

        #expect(decision.counter.districtSelectionCount == 6)
        #expect(decision.shouldShowInterstitial)
    }

    @Test
    func 各町権限の自町は除外する() {
        let counter = PublicMapAdCounter(districtSelectionCount: 1)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .district("district-a"),
            targetDistrictId: "district-a",
            defaultDistrictId: nil,
            counter: counter
        )

        #expect(decision.counter == counter)
        #expect(!decision.shouldShowInterstitial)
    }
}
