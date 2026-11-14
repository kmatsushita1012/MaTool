import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SettingsFeatureTests {
    @Test("町Pickerはorderの昇順で並ぶ")
    func districtsAreSortedForPicker() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let firstDistrict = District(
            id: "group-b-first",
            name: "B一町",
            festivalId: festival.id,
            order: 0,
            group: "B"
        )
        let laterDistrict = District(
            id: "group-a-later",
            name: "A二町",
            festivalId: festival.id,
            order: 2,
            group: "A"
        )
        let middleDistrict = District(
            id: "group-a-first",
            name: "A一町",
            festivalId: festival.id,
            order: 1,
            group: "A"
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [laterDistrict, firstDistrict, middleDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        ))

        let state = withDependencies {
            $0.installTestSpies()
            $0.values = ConstantValues(
                apiBaseUrl: "",
                appStatusUrl: "",
                defaultFestivalKey: "festival",
                defaultDistrictKey: "district",
                loginIdKey: "login",
                hasLaunchedBeforeKey: "launched",
                userGuideUrl: "https://example.com/guide",
                contactURL: "https://example.com/contact",
                isLiquidGlassEnabled: false,
                admobAppId: nil,
                publicMapInterstitialAdUnitId: nil,
                publicMapBannerAdUnitId: nil
            )
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: festival.id, districtId: nil),
                festivals: [festival],
                appState: appState
            )
        }

        #expect(state.districts.map(\.id) == [firstDistrict.id, middleDistrict.id, laterDistrict.id])
    }

    @Test("町PickerはMapの表示町ではなく保存済みの町を選択する")
    func selectedDistrictUsesSavedSceneSelection() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let savedDistrict = District(id: "saved", name: "保存済み", festivalId: festival.id)
        let mapDistrict = District(id: "map", name: "Map表示中", festivalId: festival.id)
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [savedDistrict, mapDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            districtPack: LaunchDistrictPack(
                performances: [],
                routes: [],
                points: [],
                passages: [],
                currentRouteId: nil
            ),
            districtId: mapDistrict.id
        ))

        let state = withDependencies {
            $0.installTestSpies()
            $0.values = ConstantValues(
                apiBaseUrl: "",
                appStatusUrl: "",
                defaultFestivalKey: "festival",
                defaultDistrictKey: "district",
                loginIdKey: "login",
                hasLaunchedBeforeKey: "launched",
                userGuideUrl: "https://example.com/guide",
                contactURL: "https://example.com/contact",
                isLiquidGlassEnabled: false,
                admobAppId: nil,
                publicMapInterstitialAdUnitId: nil,
                publicMapBannerAdUnitId: nil
            )
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: festival.id, districtId: savedDistrict.id),
                festivals: [festival],
                appState: appState
            )
        }

        #expect(state.selectedDistrict?.id == savedDistrict.id)
    }
    @Test("ライセンス画面の表示と閉じる操作は設定画面のナビゲーション状態を更新する")
    @MainActor
    func licenseNavigationRoundTrip() async {
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.licenseTapped) {
            $0.navigationDestination = .license
        }
        await store.send(.licenseDismissed) {
            $0.navigationDestination = nil
        }
        await store.finish()
    }

    @Test("サインアウト完了結果はローディングを解除し、失敗時は詳細エラーを表示する")
    @MainActor
    func signOutResultsPreserveFailureDetails() async {
        let error = AppError.be(.network("offline"))
        var state = makeState()
        state.isSignOutLoading = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.signOutReceived(.failure(error))) {
            $0.isSignOutLoading = false
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
            $0.pendingParticipationChange = nil
        }
        await store.send(.signOutReceived(.success(.onboarding)))
        await store.finish()
    }

    @Test("祭典変更の成功結果は地区選択をリセットし、変更された権限を親へ通知する")
    @MainActor
    func changedFestivalClearsDistrictAndNotifiesParent() async {
        var state = makeState()
        state.isParticipationLoading = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.festivalSelectReceived(.success(.changed(.guest)))) {
            $0.selectedDistrict = nil
            $0.confirmedDistrict = nil
            $0.isParticipationLoading = false
        }
        await store.receive(.delegate(.sceneSelectionChanged(.guest, nil)))
        await store.finish()
    }

    @Test("変更不要の祭典選択結果は親への通知を発生させない")
    @MainActor
    func unchangedFestivalDoesNotNotifyParent() async {
        var state = makeState()
        state.isParticipationLoading = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.festivalSelectReceived(.success(.unchanged))) {
            $0.isParticipationLoading = false
        }
        await store.finish()
    }

    @Test("地区選択の成功は現在のユーザー権限とRouteIDを親へ通知する")
    @MainActor
    func districtSelectionSuccessNotifiesParent() async {
        var state = makeState()
        state.isParticipationLoading = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.districtSelectReceived(.success("route-1"))) {
            $0.isParticipationLoading = false
        }
        await store.receive(.delegate(.sceneSelectionChanged(.guest, "route-1")))
        await store.finish()
    }

    @Test("ゲストの祭典切り替え失敗時は確定済み選択を復元する")
    @MainActor
    func guestFestivalChangeFailureRollsBackSelection() async {
        let error = AppError.be(.network("offline"))
        let spy = SelectFestivalUseCaseSpy(error: error)
        let next = Festival(
            id: "next-festival", name: "Next", subname: "Next",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.selectedFestival, next))) {
            $0.selectedFestival = next
            $0.isParticipationLoading = true
        }
        await store.receive(.festivalSelectReceived(.failure(error))) {
            $0.isParticipationLoading = false
            $0.selectedFestival = $0.confirmedFestival
            $0.selectedDistrict = $0.confirmedDistrict
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        #expect(await spy.festivalIDs == [next.id])
        await store.finish()
    }

    @Test("本部管理者の祭典切り替えはサインアウト確認まで選択を確定しない")
    @MainActor
    func adminFestivalChangeRequiresConfirmation() async {
        let next = Festival(
            id: "next-festival", name: "Next", subname: "Next",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let store = TestStore(initialState: makeState(userRole: .headquarter("festival"))) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.selectedFestival, next))) {
            $0.selectedFestival = $0.confirmedFestival
            $0.selectedDistrict = $0.confirmedDistrict
            $0.pendingParticipationChange = .festival(next.id)
            $0.alert = AlertFeature.participationChangeConfirmation()
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
            $0.pendingParticipationChange = nil
            $0.selectedFestival = $0.confirmedFestival
            $0.selectedDistrict = $0.confirmedDistrict
        }
        await store.finish()
    }


    @Test("参加設定の変更でサインアウトしなかった場合は権限を維持しエラーを示す")
    @MainActor
    func participationFailureWithoutSignOutPreservesAdminRole() async {
        let error = AppError.be(.network("offline"))
        var state = makeState(userRole: .headquarter("festival"))
        state.isParticipationLoading = true
        state.pendingParticipationChange = .festival("next-festival")
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.participationChangeReceived(.init(didSignOut: false, error: error))) {
            $0.isParticipationLoading = false
            $0.pendingParticipationChange = nil
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        #expect(store.state.userRole == .headquarter("festival"))
        await store.finish()
    }

    @Test("参加設定の変更とサインアウト成功はゲストに戻し選択状態を親へ送る")
    @MainActor
    func successfulParticipationChangeNotifiesParent() async {
        var state = makeState(userRole: .headquarter("festival"))
        state.isParticipationLoading = true
        state.pendingParticipationChange = .district("district")
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.participationChangeReceived(.init(didSignOut: true, error: nil))) {
            $0.isParticipationLoading = false
            $0.pendingParticipationChange = nil
            $0.userRole = .guest
        }
        await store.receive(.delegate(.participationChanged(.init(
            festivals: [AppStateFixture.festival()],
            selection: .init(festivalId: "festival", districtId: "district")
        ))))
        await store.finish()
    }

    @Test("サインアウト後に参加設定の再取得が失敗してもゲストに戻しエラーを通知する")
    @MainActor
    func failedReloadAfterSignOutKeepsGuestRole() async {
        let error = AppError.be(.network("offline"))
        var state = makeState(userRole: .headquarter("festival"))
        state.isParticipationLoading = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.participationChangeReceived(.init(didSignOut: true, error: error))) {
            $0.isParticipationLoading = false
            $0.userRole = .guest
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        await store.receive(.delegate(.participationChanged(.init(
            festivals: [AppStateFixture.festival()],
            selection: .init(festivalId: "festival", districtId: "district")
        ))))
        await store.finish()
    }

    private func makeState(userRole: UserRole = .guest) -> SettingsFeature.State {
        withDependencies {
            $0.installTestSpies()
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: "festival", districtId: "district"),
                festivals: [AppStateFixture.festival()],
                userRole: userRole,
                appState: Shared<AppState?>(value: AppStateFixture.state())
            )
        }
    }

}
