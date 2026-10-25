import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SignInUseCaseTests {
    @Test("認証成功後に管理者データを取得してからログイン結果を返す")
    func loadsAdminSessionBeforeReturningSuccess() async throws {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let festivalPack = LaunchFestivalPack(
            festival: festival,
            districts: [district],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        let districtPack = LaunchDistrictPack(
            performances: [],
            routes: [],
            points: [],
            passages: [],
            currentRouteId: nil
        )
        var provider = AuthProvider.noop
        provider.signOut = {}
        provider.signIn = { _, _ in .success }
        provider.getUserRole = { .district(district.id) }
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack,
            districtPack: districtPack
        )
        let appState = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.authProvider = provider
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = SignInUserDefaultsManager()
        } operation: {
            SignInUseCase()
        }

        let result = try await useCase(username: "admin", password: "secret", appState: appState)

        #expect(result == .signedIn(.district(district.id)))
        #expect(appState.wrappedValue?.festivalState.festival.id == festival.id)
        #expect(appState.wrappedValue?.selectedDistrict?.id == district.id)
        #expect(await fetcher.requestedResources().sorted() == ["district", "festival"])
    }
}

private actor SignInSceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let festivalPack: LaunchFestivalPack
    private let districtPack: LaunchDistrictPack
    private var requests: [String] = []

    init(festivalPack: LaunchFestivalPack, districtPack: LaunchDistrictPack) {
        self.festivalPack = festivalPack
        self.districtPack = districtPack
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        requests.append("district")
        return districtPack
    }

    func requestedResources() -> [String] {
        requests
    }
}

private struct SignInUserDefaultsManager: UserDefalutsManagerProtocol {
    var defaultFestivalId: String? { nil }
    var defaultDistrictId: String? { nil }
    var hasRequestedAlwaysLocationPermission: Bool { false }

    func saveDefaultFestivalId(_ value: String?) {}
    func saveDefaultDistrictId(_ value: String?) {}
    func saveHasRequestedAlwaysLocationPermission(_ value: Bool) {}
}
