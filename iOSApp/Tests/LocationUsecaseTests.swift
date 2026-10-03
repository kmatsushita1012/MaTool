import CoreLocation
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LocationUsecaseTests {
    @Test("LocationUsecaseは権限状態とUD managerの保存値を返す")
    func 権限状態と保存値を返す() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: true
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        let state = await usecase.locationPermissionState()

        #expect(state.authorizationStatus == .authorizedWhenInUse)
        #expect(state.hasRequestedAlwaysLocationPermission)
    }

    @Test("常に許可要求の通知を受けた時だけUD managerへ保存する")
    func 常に許可要求の通知時だけ保存する() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        await usecase.requestPermission()
        #expect(userDefaults.hasRequestedAlwaysLocationPermission == false)

        await provider.notifyAlwaysAuthorizationRequest()

        #expect(userDefaults.hasRequestedAlwaysLocationPermission)
    }

    @Test("配信開始前に常に許可を再確認し、未許可なら開始しない")
    func 配信開始前に常に許可を再確認する() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        let result = await usecase.start(id: "district-a", interval: .sample)

        #expect(
            result == .permissionRequired(
                LocationPermissionState(
                    authorizationStatus: .authorizedWhenInUse,
                    hasRequestedAlwaysLocationPermission: false
                )
            )
        )
        #expect(await provider.startTrackingCallCount == 0)
    }

    @Test("停止後に遅れて届いた位置情報を配信しない")
    func 停止後の位置情報を配信しない() async {
        let provider = LocationProviderSpy(authorizationStatus: .authorizedAlways)
        let dataFetcher = LocationDataFetcherSpy()
        let usecase = makeUsecase(provider: provider, dataFetcher: dataFetcher)

        let startResult = await usecase.start(
            id: "district-a",
            interval: Interval(label: "test", value: 3_600)
        )
        #expect(startResult.isStarted)

        await usecase.stop(id: "district-a")
        await provider.emit(.success(CLLocation(latitude: 35, longitude: 139)))

        #expect(await dataFetcher.events == ["delete"])
        #expect(await usecase.getIsTracking() == false)
    }

    @Test("短時間に重複して届いた位置情報を二重送信しない")
    func 短時間の重複位置情報を二重送信しない() async {
        let provider = LocationProviderSpy(authorizationStatus: .authorizedAlways)
        let dataFetcher = LocationDataFetcherSpy(blockUpdates: true)
        let usecase = makeUsecase(provider: provider, dataFetcher: dataFetcher)

        let startResult = await usecase.start(
            id: "district-a",
            interval: Interval(label: "test", value: 3_600)
        )
        #expect(startResult.isStarted)

        let location = CLLocation(latitude: 35, longitude: 139)
        let firstUpdate = Task { await provider.emit(.success(location)) }
        await dataFetcher.waitForUpdateStart()

        let duplicateUpdate = Task { await provider.emit(.success(location)) }
        await duplicateUpdate.value
        #expect(await dataFetcher.events == ["update-start"])

        await dataFetcher.releaseUpdate()
        await firstUpdate.value
        #expect(await dataFetcher.events == ["update-start", "update-finish"])

        await usecase.stop(id: "district-a")
    }

    @Test("停止時は進行中の位置情報更新完了後に削除する")
    func 停止時は進行中の更新後に削除する() async {
        let provider = LocationProviderSpy(authorizationStatus: .authorizedAlways)
        let dataFetcher = LocationDataFetcherSpy(blockUpdates: true)
        let usecase = makeUsecase(provider: provider, dataFetcher: dataFetcher)

        let startResult = await usecase.start(
            id: "district-a",
            interval: Interval(label: "test", value: 3_600)
        )
        #expect(startResult.isStarted)

        let updateTask = Task {
            await provider.emit(.success(CLLocation(latitude: 35, longitude: 139)))
        }
        await dataFetcher.waitForUpdateStart()

        let stopTask = Task {
            await usecase.stop(id: "district-a")
        }
        await provider.waitForStopTracking()
        #expect(await dataFetcher.events == ["update-start"])

        await dataFetcher.releaseUpdate()
        await updateTask.value
        await stopTask.value

        #expect(await dataFetcher.events == ["update-start", "update-finish", "delete"])
    }

    @Test("DEBUGでは位置情報取得失敗の詳細を履歴に表示する")
    func DEBUGでは位置情報取得失敗の詳細を履歴に表示する() {
#if DEBUG
        let status = Status.locationError(Date(timeIntervalSince1970: 0), "詳細な取得エラー")

        #expect(status.text.contains("取得失敗"))
        #expect(status.text.contains("\n詳細な取得エラー"))
#endif
    }

    private func makeUsecase(
        provider: LocationProviderSpy,
        userDefaults: UserDefaultsManagerSpy = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: false
        ),
        dataFetcher: LocationDataFetcherProtocol = LocationDataFetcherSpy()
    ) -> LocationUsecase {
        withDependencies {
            $0[BroadcastLocationProviderKey.self] = provider
            $0[UserDefaltsManagerKey.self] = userDefaults
            $0[LocationDataFetcherKey.self] = dataFetcher
        } operation: {
            LocationUsecase()
        }
    }
}

private actor LocationProviderSpy: BroadcastLocationProviderProtocol {
    private let authorizationStatusValue: CLAuthorizationStatus
    private var onAlwaysAuthorizationRequest: (@Sendable () async -> Void)?
    private(set) var startTrackingCallCount = 0
    private(set) var stopTrackingCallCount = 0
    private var onUpdate: ((AsyncValue<CLLocation>) async -> Void)?
    private var stopTrackingWaiters: [CheckedContinuation<Void, Never>] = []

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func requestPermission(
        onAlwaysAuthorizationRequest: @escaping @Sendable () async -> Void
    ) async {
        self.onAlwaysAuthorizationRequest = onAlwaysAuthorizationRequest
    }

    func notifyAlwaysAuthorizationRequest() async {
        await onAlwaysAuthorizationRequest?()
    }

    func authorizationStatus() async -> CLAuthorizationStatus {
        authorizationStatusValue
    }

    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async {
        startTrackingCallCount += 1
        self.onUpdate = onUpdate
    }

    func stopTracking() async {
        stopTrackingCallCount += 1
        let waiters = stopTrackingWaiters
        stopTrackingWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func emit(_ result: AsyncValue<CLLocation>) async {
        await onUpdate?(result)
    }

    func waitForStopTracking() async {
        guard stopTrackingCallCount == 0 else { return }
        await withCheckedContinuation { stopTrackingWaiters.append($0) }
    }

    func getLocation() async -> AsyncValue<CLLocation> {
        .loading
    }

    func isAlwaysAuthorized() async -> Bool {
        authorizationStatusValue == .authorizedAlways
    }

    func isLocationServicesEnabled() async -> Bool {
        true
    }

    var isTracking: Bool {
        get async { false }
    }
}

private extension LocationTrackingStartResult {
    var isStarted: Bool {
        if case .started = self { return true }
        return false
    }
}

private actor LocationDataFetcherSpy: LocationDataFetcherProtocol {
    private let blockUpdates: Bool
    private var updateStarted = false
    private var updateGate: CheckedContinuation<Void, Never>?
    private var updateStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var events: [String] = []

    init(blockUpdates: Bool = false) {
        self.blockUpdates = blockUpdates
    }

    func fetchAll(festivalId: Festival.ID) async throws {}
    func fetch(districtId: District.ID) async throws {}

    func update(_ location: FloatLocation) async throws {
        events.append("update-start")
        if blockUpdates {
            await withCheckedContinuation { continuation in
                updateGate = continuation
                updateStarted = true
                let waiters = updateStartedWaiters
                updateStartedWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }
        events.append("update-finish")
    }

    func delete(districtId: District.ID) async throws {
        events.append("delete")
    }

    func waitForUpdateStart() async {
        guard !updateStarted else { return }
        await withCheckedContinuation { updateStartedWaiters.append($0) }
    }

    func releaseUpdate() {
        updateGate?.resume()
        updateGate = nil
    }
}

private final class UserDefaultsManagerSpy: UserDefalutsManagerProtocol, @unchecked Sendable {
    var defaultFestivalId: String?
    var defaultDistrictId: String?
    var hasRequestedAlwaysLocationPermission: Bool

    init(hasRequestedAlwaysLocationPermission: Bool) {
        self.hasRequestedAlwaysLocationPermission = hasRequestedAlwaysLocationPermission
    }

    func setHasRequestedAlwaysLocationPermission(_ value: Bool) {
        hasRequestedAlwaysLocationPermission = value
    }
}
