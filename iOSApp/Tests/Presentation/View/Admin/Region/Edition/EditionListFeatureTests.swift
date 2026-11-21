import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct EditionListFeatureTests {
    @Test("一覧でEditionと有効年度を取得して新しい順に表示する")
    @MainActor
    func loadsEditionsAndActiveEdition() async {
        let current = edition(id: "current", year: 2026)
        let archive = edition(id: "archive", year: 2025)
        let response = EditionListResponse(editions: [archive, current], activeEditionId: current.id)
        let spy = makeSpy(list: response, pack: EditionPack(edition: current, periods: []))
        let store = TestStore(initialState: EditionListFeature.State(festivalID: "festival")) {
            EditionListFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(.listReceived(.success(response))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.editions = [current, archive]
            $0.activeEditionID = current.id
        }
        #expect(await spy.calls() == [.fetchList("festival")])
        await store.finish()
    }

    @Test("年度を選ぶとEditionEditを開き有効状態を渡す")
    @MainActor
    func selectsEditionForEditing() async {
        let current = edition(id: "current", year: 2026)
        let archive = edition(id: "archive", year: 2025)
        var state = EditionListFeature.State(festivalID: "festival")
        state.editions = [current, archive]
        state.activeEditionID = current.id
        let spy = makeSpy(list: .init(editions: state.editions, activeEditionId: current.id), pack: EditionPack(edition: archive, periods: []))
        let store = TestStore(initialState: state) {
            EditionListFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.editionTapped(archive))
        #expect(store.state.destination?.edit?.edition == archive)
        #expect(store.state.destination?.edit?.activeEditionID == current.id)
        await store.finish()
    }

    @Test("年度作成後は有効化せずEditionEditを開く")
    @MainActor
    func creationOpensEditorWithoutActivatingEdition() async {
        let currentEdition = edition(id: "current", year: 2026)
        let newEdition = edition(id: "new", year: 2027)
        let pack = EditionPack(edition: newEdition, periods: [])
        var initialState = EditionListFeature.State(festivalID: "festival")
        initialState.editions = [currentEdition]
        initialState.hasLoaded = true
        let spy = makeSpy(list: .init(editions: [currentEdition], activeEditionId: nil), pack: pack)
        let store = TestStore(initialState: initialState) {
            EditionListFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.addEditionTapped) {
            $0.isCreationAlertPresented = true
            $0.newEditionYearText = "2027"
        }
        await store.send(.createConfirmed) {
            $0.isCreationAlertPresented = false
            $0.isCreating = true
        }
        await store.receive(.creationReceived(.success(pack)))
        #expect(store.state.destination?.edit?.edition == newEdition)
        #expect(store.state.activeEditionID == nil)
        #expect(await spy.calls() == [.create("festival", 2027)])
        await store.finish()
    }

    @Test("年度入力が整数でない場合は作成APIを呼ばない")
    @MainActor
    func invalidYearDoesNotCreateEdition() async {
        let pack = EditionPack(edition: edition(id: "new", year: 2027), periods: [])
        let spy = makeSpy(list: .init(editions: [], activeEditionId: nil), pack: pack)
        var initialState = EditionListFeature.State(festivalID: "festival")
        initialState.isCreationAlertPresented = true
        initialState.newEditionYearText = "20,26"
        let store = TestStore(initialState: initialState) {
            EditionListFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.createConfirmed) {
            $0.isCreationAlertPresented = false
            $0.alert = AlertFeature.error("年度は1以上の整数で入力してください。")
        }
        #expect(await spy.calls().isEmpty)
        await store.finish()
    }

    private func makeSpy(list: EditionListResponse, pack: EditionPack) -> EditionDataFetcherSpy {
        EditionDataFetcherSpy(
            list: list,
            pack: pack,
            activeEdition: ActiveEdition(festivalId: "festival", editionId: pack.edition.id)
        )
    }

    private func edition(id: Edition.ID, year: Int) -> Edition {
        Edition(id: id, festivalId: "festival", year: year)
    }
}
