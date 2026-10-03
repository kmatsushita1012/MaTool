import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicMapFeatureTests {
    @Test("新しい地区選択で先行Effectをキャンセルし、新しい応答だけ採用する")
    @MainActor
    func 新しい地区選択で先行Effectをキャンセルし新しい応答だけ採用する() async {
        let festival = Festival(
            id: "festival",
            name: "祭典",
            subname: "",
            base: Coordinate(latitude: 0, longitude: 0)
        )
        let districtA = District(id: "district-a", name: "地区A", festivalId: "festival")
        let districtB = District(id: "district-b", name: "地区B", festivalId: "festival")
        let probe = DistrictLaunchProbe()
        let usecase = CancellablePublicMapUsecaseStub(probe: probe)
        let initialState = PublicMapFeature.State(
            userRole: .guest,
            contents: [.locations(festival), .route(districtA), .route(districtB)],
            selectedContent: .locations(festival),
            currentPeriodId: nil,
            isLoading: false,
            isDismissed: false,
            destination: nil,
            mapRegion: Shared(value: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )),
            toast: Shared(value: nil)
        )
        let store = TestStore(initialState: initialState) {
            PublicMapFeature()
        } withDependencies: {
            $0.publicMapAdUsecase = usecase
        }

        await store.send(.contentSelected(.route(districtA))) {
            $0.selectedContent = PublicMapFeature.Content.route(districtA)
            $0.isLoading = true
        }
        #expect(await probe.waitUntilStarted(districtA.id))

        await store.send(.contentSelected(.route(districtB))) {
            $0.selectedContent = PublicMapFeature.Content.route(districtB)
            $0.isLoading = true
        }
        #expect(await probe.waitUntilCancelled(districtA.id))
        #expect(await probe.waitUntilStarted(districtB.id))

        let error = AppError.be(.network("地区Bの取得失敗"))
        await store.receive(.districtLaunchReceived(districtB, .failure(error))) {
            $0.isLoading = false
            $0.$toast.withLock { $0 = .error(error, title: "地区情報を取得できませんでした") }
        }
        await store.finish()
    }

    @Test("古い地区応答は現在選択中の地区と一致しない")
    func 古い地区応答は現在選択中の地区と一致しない() {
        let districtA = District(id: "district-a", name: "地区A", festivalId: "festival")
        let districtB = District(id: "district-b", name: "地区B", festivalId: "festival")

        #expect(!PublicMapFeature.isSelected(districtA, by: .route(districtB)))
        #expect(PublicMapFeature.isSelected(districtB, by: .route(districtB)))
    }

    @Test("現在地一覧を選択中なら地区応答を採用しない")
    func 現在地一覧を選択中なら地区応答を採用しない() {
        let festival = Festival(
            id: "festival",
            name: "祭典",
            subname: "",
            base: Coordinate(latitude: 0, longitude: 0)
        )
        let district = District(id: "district-a", name: "地区A", festivalId: festival.id)

        #expect(!PublicMapFeature.isSelected(district, by: .locations(festival)))
    }
}

private actor DistrictLaunchProbe {
    private var startedDistrictIDs: Set<District.ID> = []
    private var cancelledDistrictIDs: Set<District.ID> = []

    func recordStarted(_ districtID: District.ID) {
        startedDistrictIDs.insert(districtID)
    }

    func recordCancelled(_ districtID: District.ID) {
        cancelledDistrictIDs.insert(districtID)
    }

    func waitUntilStarted(_ districtID: District.ID) async -> Bool {
        for _ in 0..<100 {
            if startedDistrictIDs.contains(districtID) { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return startedDistrictIDs.contains(districtID)
    }

    func waitUntilCancelled(_ districtID: District.ID) async -> Bool {
        for _ in 0..<100 {
            if cancelledDistrictIDs.contains(districtID) { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return cancelledDistrictIDs.contains(districtID)
    }
}

private struct CancellablePublicMapUsecaseStub: PublicMapAdUsecaseProtocol {
    let probe: DistrictLaunchProbe

    func prepareSession() async {}

    func handleDistrictSelection(
        districtId: District.ID,
        periodId: Period.ID?
    ) async throws -> Route.ID? {
        await probe.recordStarted(districtId)
        if districtId == "district-a" {
            return try await withTaskCancellationHandler {
                try await Task.sleep(for: .seconds(60))
                return "route-a"
            } onCancel: {
                Task { await probe.recordCancelled(districtId) }
            }
        }
        throw AppError.be(.network("地区Bの取得失敗"))
    }

    func handleDistrictSelectionResult(
        userRole: UserRole,
        districtId: District.ID,
        hasDisplayableContent: Bool
    ) async {}
}
