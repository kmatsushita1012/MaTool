import Shared
import Testing
@testable import iOSApp

struct LaunchEditionConsistencyTests {
    @Test("Edition未設定かつPeriod 0件のFestival/Districtパックは一致する")
    func missingEditionsMatch() async throws {
        let festivalPack = festivalPack(edition: nil, periods: [])
        let districtPack = districtPack(editionID: nil)
        let spy = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack],
            districtResponses: [districtPack]
        )

        let result = try await fetchEditionConsistentLaunchPacks(
            districtID: "district",
            using: spy
        )

        #expect(result.festival.edition == nil)
        #expect(result.festival.periods.isEmpty)
        #expect(result.district.editionId == nil)
        #expect(await spy.callCounts().festival == 1)
        #expect(await spy.callCounts().district == 1)
    }

    @Test("Edition IDが不一致なら両方再取得し、新しい一致ペアを使う")
    func retriesBothLaunchRequestsAfterMismatch() async throws {
        let firstEdition = Edition(id: "first", festivalId: "festival", year: 2026)
        let currentEdition = Edition(id: "current", festivalId: "festival", year: 2027)
        let spy = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [
                festivalPack(edition: firstEdition),
                festivalPack(edition: currentEdition)
            ],
            districtResponses: [
                districtPack(editionID: "current"),
                districtPack(editionID: "current")
            ]
        )

        let result = try await fetchEditionConsistentLaunchPacks(
            districtID: "district",
            periodID: "period",
            using: spy
        )

        #expect(result.festival.edition?.id == "current")
        #expect(result.district.editionId == "current")
        #expect(await spy.callCounts().festival == 2)
        #expect(await spy.callCounts().district == 2)
        #expect(await spy.requestedDistrictPeriods() == ["period", "period"])
    }

    @Test("再取得後もEdition IDが一致しない場合はエラーにする")
    func persistentMismatchDoesNotReturnMixedPacks() async {
        let spy = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack(edition: Edition(id: "festival-edition", festivalId: "festival", year: 2026))],
            districtResponses: [districtPack(editionID: "district-edition")]
        )

        await #expect(throws: AppError.self) {
            try await fetchEditionConsistentLaunchPacks(districtID: "district", using: spy)
        }
        #expect(await spy.callCounts().festival == 2)
        #expect(await spy.callCounts().district == 2)
    }

    private func festivalPack(edition: Edition?, periods: [Period] = []) -> LaunchFestivalPack {
        LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            edition: edition,
            districts: [AppStateFixture.district()],
            periods: periods,
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
    }

    private func districtPack(editionID: Edition.ID?) -> LaunchDistrictPack {
        LaunchDistrictPack(
            editionId: editionID,
            performances: [],
            routes: [],
            points: [],
            passages: [],
            currentRouteId: nil
        )
    }
}
