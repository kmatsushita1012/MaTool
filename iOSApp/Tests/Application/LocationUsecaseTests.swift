import CoreLocation
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct LocationUsecaseTests {
    private func subject(
        status: CLAuthorizationStatus = .notDetermined,
        permissionRequested: Bool = false
    ) -> (LocationUsecase, BroadcastLocationProviderSpy, DefaultUserDefaultsSpy) {
        let provider = BroadcastLocationProviderSpy(authorizationStatus: status)
        let defaults = DefaultUserDefaultsSpy(
            hasRequestedAlwaysLocationPermission: permissionRequested
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.broadcastLocationProvider = provider
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { LocationUsecase() }
        return (useCase, provider, defaults)
    }

    @Test("許可状態はWhenInUse・Alwaysを区別し未確認フラグを反映する")
    func tracksAuthorizationLevels() async {
        let (undetermined, _, _) = subject()
        let a = await undetermined.locationPermissionState()
        #expect(!a.isLocationAuthorized)
        #expect(!a.isAlwaysAuthorized)
        #expect(!a.hasRequestedAlwaysLocationPermission)

        let (inUse, _, _) = subject(status: .authorizedWhenInUse)
        let b = await inUse.locationPermissionState()
        #expect(b.isLocationAuthorized)
        #expect(!b.isAlwaysAuthorized)

        let (always, _, _) = subject(status: .authorizedAlways, permissionRequested: true)
        let c = await always.locationPermissionState()
        #expect(c.isLocationAuthorized)
        #expect(c.isAlwaysAuthorized)
        #expect(c.hasRequestedAlwaysLocationPermission)

        let (denied, _, _) = subject(status: .denied)
        let d = await denied.locationPermissionState()
        #expect(!d.isLocationAuthorized)
    }

    @Test("初期状態の準備結果は未追跡とnilの間隔を報告する")
    func preparingTrackingReturnsInitialSnapshot() async {
        let (useCase, _, _) = subject(status: .authorizedAlways)

        let result = await useCase.prepareTracking()

        #expect(!result.isTracking)
        #expect(result.interval == nil)
        #expect(result.permissionState.isAlwaysAuthorized)
    }

    @Test("権限要求でAlways要求完了通知を受信した場合は保存フラグを立てる")
    func requestPermissionRecordsAlwaysPrompt() async {
        let (useCase, provider, defaults) = subject()

        await useCase.requestPermission()
        #expect(!defaults.hasRequestedAlwaysLocationPermission)

        await provider.notifyAlwaysAuthorizationRequest()

        #expect(defaults.hasRequestedAlwaysLocationPermission)
        #expect(await provider.permissionRequests == 1)
    }

    @Test("Always権限がない場合は追跡せず必要権限を返す")
    func deniedAuthorizationPreventsTracking() async {
        let (useCase, provider, _) = subject(status: .authorizedWhenInUse)
        let interval = Interval(label: "1分", value: 60)

        let result = await useCase.start(id: "district", interval: interval)

        guard case .permissionRequired(let state) = result else {
            Issue.record("権限不足なのに追跡を開始しました")
            return
        }
        #expect(state.isLocationAuthorized)
        #expect(!state.isAlwaysAuthorized)
        #expect(await provider.trackingStarts == 0)
        #expect(!(await useCase.prepareTracking()).isTracking)
    }

    @Test("Always権限があっても位置情報サービス停止中は追跡しない")
    func disabledServicesPreventTrackingAndRecordError() async {
        let (useCase, provider, _) = subject(status: .authorizedAlways)

        let result = await useCase.start(id: "district", interval: .sample)

        #expect(result == .locationServicesDisabled)
        #expect(await provider.trackingStarts == 0)
        #expect(!(await useCase.prepareTracking()).isTracking)
        let history = await useCase.getLocationHistory()
        #expect(history.count == 1)
        if case .locationError = history.first {
            // Correctly reported as a location failure rather than a completed location.
        } else {
            Issue.record("位置情報サービス無効の履歴がありません")
        }
    }

    @Test("開始・二重開始・停止ではトラッキングが一度だけ開始される")
    func startStopAreIdempotent() async {
        let (useCase, provider, _) = subject(status: .authorizedAlways)
        await provider.setServicesEnabled(true)
        let interval = Interval(label: "1時間", value: 3600)

        let first = await useCase.start(id: "district", interval: interval)
        let second = await useCase.start(id: "district", interval: interval)
        let running = await useCase.prepareTracking()

        #expect(first == .started(running.permissionState))
        #expect(second == .started(running.permissionState))
        #expect(running.isTracking)
        #expect(running.interval == interval)
        #expect(await provider.trackingStarts == 1)

        await useCase.stop(id: "district")

        #expect(!(await useCase.prepareTracking()).isTracking)
        #expect(await provider.trackingStops == 1)
    }

    @Test("位置情報の現在値取得はProviderの結果をそのまま委譲する")
    func retrievesCurrentProviderLocation() async {
        let (useCase, _, _) = subject()

        let result = await useCase.getLocation()

        if case .loading = result {
            // The spy has no sampled location.
        } else {
            Issue.record("未測位の位置情報を成功扱いにしました")
        }
    }

    @Test("位置情報の成功更新は地区と座標が合うFloatLocationをStreamで配信する")
    func emitsLocationUpdatesWithDistrictId() async {
        let (useCase, provider, _) = subject(status: .authorizedAlways)
        await provider.setServicesEnabled(true)
        let stream = await useCase.locationUpdateStream()
        var iterator = stream.makeAsyncIterator()
        let interval = Interval(label: "1時間", value: 3600)
        _ = await useCase.start(id: "district", interval: interval)
        let clLocation = CLLocation(latitude: 35.25, longitude: 139.5)

        await provider.emitTrackingUpdate(.success(clLocation))
        let sent = await iterator.next()

        #expect(sent?.districtId == "district")
        #expect(sent?.coordinate.latitude == 35.25)
        #expect(sent?.coordinate.longitude == 139.5)
        await useCase.stop(id: "district")
    }

    @Test("短い間隔で二度受信した成功位置は二度目を配信しない")
    func throttlesConsecutiveSuccessUpdates() async {
        let (useCase, provider, _) = subject(status: .authorizedAlways)
        await provider.setServicesEnabled(true)
        let stream = await useCase.locationUpdateStream()
        var iterator = stream.makeAsyncIterator()
        _ = await useCase.start(id: "district", interval: Interval(label: "1時間", value: 3600))
        let location = CLLocation(latitude: 35, longitude: 139)

        await provider.emitTrackingUpdate(.success(location))
        _ = await iterator.next()
        await provider.emitTrackingUpdate(.success(location))

        let history = await useCase.getLocationHistory()
        #expect(history.filter {
            if case .update = $0 { return true }
            return false
        }.isEmpty)
        await useCase.stop(id: "district")
    }

    @Test("位置追跡履歴は初回空配列を流し、成功更新を履歴に記録する")
    func historyStreamEmitsInitialAndUpdatedValues() async {
        let (useCase, _, _) = subject()
        let stream = await useCase.historyStream()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == [])
        let location = FloatLocation(
            id: "location", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )

        await useCase.recordLocationUpdate(location)

        #expect(await iterator.next() == [.update(location)])
        #expect(await useCase.getLocationHistory() == [.update(location)])
    }

    @Test("削除イベントとAPIエラーは元の順序で履歴に残る")
    func deletionAndAPIErrorAppendHistory() async {
        let (useCase, _, _) = subject()
        let error = AppError.be(.network("offline"))

        await useCase.recordLocationDelete()
        await useCase.recordLocationError(error)

        let history = await useCase.getLocationHistory()
        #expect(history.count == 2)
        if case .delete = history[0] {
        } else {
            Issue.record("削除が履歴に記録されていません")
        }
        if case .apiError(_, let recorded) = history[1] {
            #expect(recorded == error)
        } else {
            Issue.record("APIのエラーが履歴に記録されていません")
        }
    }

    @Test("位置取得エラーを受信すると履歴にエラーを記録する")
    func trackingErrorIsRecorded() async {
        let (useCase, provider, _) = subject(status: .authorizedAlways)
        await provider.setServicesEnabled(true)
        _ = await useCase.start(id: "district", interval: .sample)

        await provider.emitTrackingUpdate(.failure(CLError(.locationUnknown)))

        let history = await useCase.getLocationHistory()
        #expect(history.contains {
            if case .locationError = $0 { return true }
            return false
        })
        await useCase.stop(id: "district")
    }
}
