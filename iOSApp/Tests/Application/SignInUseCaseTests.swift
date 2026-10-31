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
        var provider = AuthProviderSpy().client
        provider.signOut = {}
        provider.signIn = { _, _ in .success }
        provider.getUserRole = { .district(district.id) }
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack,
            districtPack: districtPack
        )
        let appState = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
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

    @Test("認証後のロール取得に失敗したらサインアウトしてエラーを返す")
    func roleLookupFailureSignsOutAndPropagatesError() async {
        let signOutSpy = SignInSignOutSpy()
        var provider = AuthProviderSpy().client
        provider.signOut = { await signOutSpy.record() }
        provider.signIn = { _, _ in .success }
        provider.getUserRole = { throw SignInTestError.roleLookup }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = provider
            $0[UserDefaltsManagerKey.self] = SignInUserDefaultsManager()
        } operation: {
            SignInUseCase()
        }

        do {
            _ = try await useCase(username: "admin", password: "secret", appState: Shared(value: nil))
            Issue.record("Role取得エラーを返していません")
        } catch let error as SignInTestError {
            #expect(error == .roleLookup)
        } catch {
            Issue.record("想定外のエラー: \(error)")
        }

        #expect(await signOutSpy.count() == 2)
    }
}

private enum SignInTestError: Error, Equatable {
    case roleLookup
}
