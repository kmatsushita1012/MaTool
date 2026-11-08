import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicLocationsFeatureTests {
    @Test("初回表示では配信中の位置全体に地図をfitする")
    func initialStateFitsAllFloatLocations() {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 35, longitude: 139)),
            FloatLocation(id: "second", districtId: "second", coordinate: .init(latitude: 36, longitude: 141))
        ])

        let state = fixture.makeState()
        let region = state.$mapRegion.wrappedValue

        #expect(region.center.latitude == 35.5)
        #expect(region.center.longitude == 140)
        #expect(abs(region.span.latitudeDelta - 1.1) < 0.000001)
        #expect(abs(region.span.longitudeDelta - 2.2) < 0.000001)
    }

    @Test("位置がない場合は祭典基点を表示する")
    func emptyLocationsUseFestivalBase() {
        let fixture = LocationMapFixture(locations: [])

        let state = fixture.makeState()
        let region = state.$mapRegion.wrappedValue

        #expect(region.center.latitude == fixture.festival.base.latitude)
        #expect(region.center.longitude == fixture.festival.base.longitude)
        #expect(region.span.latitudeDelta == spanDelta)
        #expect(region.span.longitudeDelta == spanDelta)
    }

    @Test("再読込成功後は更新されたAppStateの位置全体に地図をfitする")
    @MainActor
    func reloadSuccessFitsUpdatedFloatLocations() async {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 35, longitude: 139))
        ])
        let state = fixture.makeState()
        let store = TestStore(initialState: state) {
            PublicLocationsFeature()
        }
        store.exhaustivity = .off

        fixture.appState.withLock { appState in
            appState?.festivalState.replaceFloatLocations(with: [
                FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 34, longitude: 138)),
                FloatLocation(id: "second", districtId: "second", coordinate: .init(latitude: 37, longitude: 142))
            ])
        }

        await store.send(.reloadReceived(.success([])))

        let region = state.$mapRegion.wrappedValue
        #expect(region.center.latitude == 35.5)
        #expect(region.center.longitude == 140)
        #expect(abs(region.span.latitudeDelta - 3.3) < 0.000001)
        #expect(abs(region.span.longitudeDelta - 4.4) < 0.000001)
        await store.finish()
    }
}

private struct LocationMapFixture {
    let festival: Festival
    let appState: Shared<AppState?>

    init(locations: [FloatLocation]) {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: .init(latitude: 35.2, longitude: 139.2)
        )
        self.festival = festival
        let districts = ["first", "second"].map { districtId in
            District(id: districtId, name: districtId, festivalId: festival.id)
        }
        appState = Shared(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: districts,
                periods: [],
                locations: locations,
                checkpoints: [],
                hazardSections: []
            )
        ))
    }

    func makeState() -> PublicLocationsFeature.State {
        PublicLocationsFeature.State(
            festivalId: festival.id,
            festival: festival,
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
    }
}
