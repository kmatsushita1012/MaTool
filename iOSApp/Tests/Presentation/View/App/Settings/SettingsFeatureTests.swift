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
                publicMapBannerAdUnitId: nil,
                storeCreditProductId500: nil,
                storeCreditProductId1000: nil
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
                publicMapBannerAdUnitId: nil,
                storeCreditProductId500: nil,
                storeCreditProductId1000: nil
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

    @Test("ゲストの町切替が失敗したら確認済みの町に選択を戻して再試行可能にする")
    @MainActor
    func guestDistrictChangeFailureRestoresConfirmedSelection() async {
        let error = AppError.be(.network("offline"))
        let spy = SelectDistrictUseCaseSpy(error: error)
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.selectedDistrict, nil))) {
            $0.selectedDistrict = nil
            $0.isParticipationLoading = true
        }
        await store.receive(.districtSelectReceived(.failure(error))) {
            $0.isParticipationLoading = false
            $0.selectedDistrict = $0.confirmedDistrict
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        #expect(store.state.selectedDistrict?.id == "district")
        #expect(await spy.districtIDs == [nil])
        await store.finish()
    }

    @Test("ログインボタンは現在のAppStateを使う認証画面へ遷移する")
    @MainActor
    func loginButtonOpensLoginFeature() async {
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.loginTapped)
        #expect(store.state.destination?.login != nil)
        await store.finish()
    }

    @Test("サインアウトボタンはUseCaseに委譲し成功後はLoadingだけ解除する")
    @MainActor
    func signOutTappedCallsUseCase() async {
        let spy = SettingsSignOutUseCaseSpy()
        let store = TestStore(initialState: makeState(userRole: .headquarter("festival"))) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
        }
        await store.send(.signOutTapped) {
            $0.isSignOutLoading = true
        }
        await store.receive(.signOutReceived(.success(.onboarding))) {
            $0.isSignOutLoading = false
        }
        #expect(await spy.calls == 1)
        await store.finish()
    }

    @Test("管理者が祭典変更を確認した場合は現在のユーザーを明示して切替UseCaseを呼ぶ")
    @MainActor
    func confirmedFestivalChangePassesSignOutFlag() async {
        let error = AppError.be(.network("offline"))
        let spy = SelectFestivalUseCaseSpy(error: error)
        var state = makeState(userRole: .headquarter("festival"))
        state.pendingParticipationChange = .festival("next-festival")
        state.alert = AlertFeature.participationChangeConfirmation()
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }

        await store.send(.alert(.presented(.confirmTapped))) {
            $0.alert = nil
            $0.isParticipationLoading = true
        }
        await store.receive(.participationChangeReceived(.init(
            didSignOut: false, error: error
        ))) {
            $0.isParticipationLoading = false
            $0.pendingParticipationChange = nil
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        #expect(store.state.userRole == .headquarter("festival"))
        #expect(await spy.festivalIDs == ["next-festival"])
        await store.finish()
    }

    @Test("管理者の町変更でサインアウト後に選択失敗してもゲストへ移行する")
    @MainActor
    func districtChangeFailureAfterSignOutStillNotifiesParent() async {
        let error = AppError.be(.network("offline"))
        let districtSpy = SelectDistrictUseCaseSpy(error: error)
        let signOutSpy = SettingsSignOutUseCaseSpy()
        var state = makeState(userRole: .headquarter("festival"))
        state.pendingParticipationChange = .district(nil)
        state.alert = AlertFeature.participationChangeConfirmation()
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = districtSpy
            $0[SignOutUseCaseKey.self] = signOutSpy
        }

        await store.send(.alert(.presented(.confirmTapped))) {
            $0.alert = nil
            $0.isParticipationLoading = true
        }
        await store.receive(.participationChangeReceived(.init(
            didSignOut: true, error: error
        ))) {
            $0.isParticipationLoading = false
            $0.pendingParticipationChange = nil
            $0.userRole = .guest
            $0.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
        }
        await store.receive(.delegate(.participationChanged(.init(
            festivals: [AppStateFixture.festival()],
            selection: .init(festivalId: "festival", districtId: "district")
        ))))
        #expect(await signOutSpy.calls == 1)
        #expect(await districtSpy.districtIDs == [nil])
        await store.finish()
    }

    @Test("確認対象が無いときの確認タップは処理を起動しない")
    @MainActor
    func confirmWithoutPendingChangeOnlyDismissesAlert() async {
        var state = makeState(userRole: .headquarter("festival"))
        state.alert = AlertFeature.participationChangeConfirmation()
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.alert(.presented(.confirmTapped))) {
            $0.alert = nil
        }
        #expect(!store.state.isParticipationLoading)
        await store.finish()
    }


    @Test("確定済みと同じ祭典や未選択の祭典は切替UseCaseを呼ばない")
    @MainActor
    func duplicateOrNilFestivalSelectionIsIgnored() async {
        let spy = SelectFestivalUseCaseSpy(error: .be(.network("unexpected")))
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.selectedFestival, AppStateFixture.festival())))
        await store.send(.binding(.set(\.selectedFestival, nil)))
        #expect(!store.state.isParticipationLoading)
        #expect(await spy.festivalIDs.isEmpty)
        await store.finish()
    }

    @Test("管理者の町参加変更をキャンセルすると選択を確定済みに戻しサインアウトしない")
    @MainActor
    func cancelAdminDistrictChangeRestoresConfirmedSelection() async {
        let spy = SettingsSignOutUseCaseSpy()
        let store = TestStore(initialState: makeState(userRole: .headquarter("festival"))) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.selectedDistrict, nil)))
        #expect(store.state.pendingParticipationChange == .district(nil))
        #expect(store.state.selectedDistrict?.id == "district")
        #expect(store.state.alert != nil)
        await store.send(.alert(.presented(.cancelTapped)))
        #expect(store.state.pendingParticipationChange == nil)
        #expect(store.state.selectedDistrict?.id == "district")
        #expect(store.state.alert == nil)
        #expect(await spy.calls == 0)
        await store.finish()
    }



    @Test("管理者が祭典変更を承認した場合はUseCaseへログアウト要求を明示しゲストの参加設定に戻る")
    @MainActor
    func approvedFestivalChangeSignsOutBeforeSwitchingParticipation() async {
        let spy = SuccessfulSelectFestivalUseCaseSpy(result: .changed(.guest))
        var initial = makeState(userRole: .headquarter("festival"))
        initial.pendingParticipationChange = .festival("other-festival")
        initial.alert = AlertFeature.participationChangeConfirmation()
        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.alert(.presented(.confirmTapped)))
        await store.receive(.participationChangeReceived(.init(didSignOut: true, error: nil)))
        await store.receive(.delegate(.participationChanged(.init(
            festivals: [AppStateFixture.festival()],
            selection: .init(festivalId: "festival", districtId: "district")
        ))))
        #expect(await spy.festivalIDs == ["other-festival"])
        #expect(await spy.signOutFlags == [true])
        #expect(store.state.userRole == .guest)
        #expect(store.state.pendingParticipationChange == nil)
        await store.finish()
    }

    @Test("ゲストによる祭典の切替え成功時はUseCaseの結果で選択を確定し親画面へ新しい権限を通知する")
    @MainActor
    func guestFestivalSelectionInvokesUseCaseAndUpdatesScene() async {
        let next = Festival(
            id: "other-festival",
            name: "新しい祭典",
            subname: "本部",
            base: Coordinate(latitude: 34.7, longitude: 138.1)
        )
        let spy = SuccessfulSelectFestivalUseCaseSpy(result: .changed(.guest))
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
        await store.receive(.festivalSelectReceived(.success(.changed(.guest)))) {
            $0.isParticipationLoading = false
            $0.selectedDistrict = nil
            $0.confirmedFestival = next
            $0.confirmedDistrict = nil
        }
        await store.receive(.delegate(.sceneSelectionChanged(.guest, nil)))
        #expect(store.state.confirmedFestival?.id == next.id)
        #expect(await spy.festivalIDs == [next.id])
        #expect(await spy.signOutFlags == [true])
        await store.finish()
    }

    @Test("ゲストの町選択成功ではUseCaseの経路IDを親へ通知し選択内容を確定する")
    @MainActor
    func guestDistrictSelectionInvokesUseCaseAndConfirmsSelection() async {
        let spy = SuccessfulSelectDistrictUseCaseSpy(routeId: "new-route")
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.selectedDistrict, nil))) {
            $0.selectedDistrict = nil
            $0.isParticipationLoading = true
        }
        await store.receive(.districtSelectReceived(.success("new-route"))) {
            $0.isParticipationLoading = false
            $0.confirmedDistrict = nil
        }
        await store.receive(.delegate(.sceneSelectionChanged(.guest, "new-route")))
        #expect(await spy.districtIDs == [nil])
        #expect(store.state.confirmedDistrict == nil)
        await store.finish()
    }

    @Test("設定画面のライセンス遷移先Bindingを戻すとメニューの表示状態だけが初期化される")
    @MainActor
    func navigationBindingDismissesLicenseWithoutChangingParticipation() async {
        let store = TestStore(initialState: makeState()) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.navigationDestination, .license)))
        #expect(store.state.navigationDestination == .license)
        await store.send(.binding(.set(\.navigationDestination, nil)))
        #expect(store.state.navigationDestination == nil)
        #expect(store.state.selectedFestival?.id == "festival")
        await store.finish()
    }

    @Test("参加設定変更のエラーダイアログでOKを押すと警告だけを閉じて選択中の町を保持する")
    @MainActor
    func participationErrorAcknowledgementPreservesSelection() async {
        var initial = makeState()
        initial.alert = .error("変更に失敗しました")
        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.alert(.presented(.okTapped)))
        #expect(store.state.alert == nil)
        #expect(store.state.selectedDistrict?.id == "district")
        await store.finish()
    }

    @Test("町Pickerは並び順が同じ場合に町名で安定して比較し、祭典未読込時は空にする")
    func pickerUsesNameAsTieBreakerAndHandlesMissingState() {
        let festival = AppStateFixture.festival()
        let later = District(id: "later", name: "B町", festivalId: festival.id, order: 1)
        let earlier = District(id: "earlier", name: "A町", festivalId: festival.id, order: 1)
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [later, earlier],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            )
        ))
        let populated = withDependencies {
            $0.installTestSpies()
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: festival.id, districtId: nil),
                appState: appState
            )
        }
        #expect(populated.districts.map(\.id) == [earlier.id, later.id])

        let empty = withDependencies {
            $0.installTestSpies()
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: nil, districtId: nil),
                appState: Shared<AppState?>(value: nil)
            )
        }
        #expect(empty.districts.isEmpty)
    }

    @Test("管理者が町変更を承認した場合はログアウト後に町選択成功を確認してゲストへ戻す")
    @MainActor
    func approvedDistrictChangeInvokesSignOutAndSelection() async {
        let districtSpy = SuccessfulSelectDistrictUseCaseSpy(routeId: "new-route")
        let signOutSpy = SettingsSignOutUseCaseSpy()
        var state = makeState(userRole: .headquarter("festival"))
        state.pendingParticipationChange = .district(nil)
        state.alert = AlertFeature.participationChangeConfirmation()
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = districtSpy
            $0[SignOutUseCaseKey.self] = signOutSpy
        }

        await store.send(.alert(.presented(.confirmTapped))) {
            $0.alert = nil
            $0.isParticipationLoading = true
        }
        await store.receive(.participationChangeReceived(.init(
            didSignOut: true, error: nil
        ))) {
            $0.isParticipationLoading = false
            $0.pendingParticipationChange = nil
            $0.userRole = .guest
        }
        await store.receive(.delegate(.participationChanged(.init(
            festivals: [AppStateFixture.festival()],
            selection: .init(festivalId: "festival", districtId: "district")
        ))))
        #expect(await signOutSpy.calls == 1)
        #expect(await districtSpy.districtIDs == [nil])
        #expect(store.state.userRole == .guest)
        await store.finish()
    }

}



private actor SuccessfulSelectFestivalUseCaseSpy: SelectFestivalUseCaseProtocol {
    let result: FestivalSelectionResult
    private(set) var festivalIDs: [Festival.ID] = []
    private(set) var signOutFlags: [Bool] = []

    init(result: FestivalSelectionResult) { self.result = result }

    func callAsFunction(
        festivalId: Festival.ID,
        appState: Shared<AppState?>?,
        signOutCurrentUser: Bool
    ) async throws -> FestivalSelectionResult {
        festivalIDs.append(festivalId)
        signOutFlags.append(signOutCurrentUser)
        return result
    }
}

private actor SuccessfulSelectDistrictUseCaseSpy: SelectDistrictUseCaseProtocol {
    private(set) var districtIDs: [District.ID?] = []
    private let routeId: Route.ID?

    init(routeId: Route.ID?) { self.routeId = routeId }

    func callAsFunction(
        districtId: District.ID?, appState: Shared<AppState?>?
    ) async throws -> Route.ID? {
        districtIDs.append(districtId)
        return routeId
    }
}

private actor SettingsSignOutUseCaseSpy: SignOutUseCaseProtocol {
    private(set) var calls = 0

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        calls += 1
        return .onboarding
    }

}
