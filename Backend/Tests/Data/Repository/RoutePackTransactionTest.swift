import Dependencies
import Shared
import Testing
@testable import Backend

struct RoutePackTransactionTest {
    @Test
    func putPack_正常_RouteとPointとPassageを一括transactionに渡す() async throws {
        let route = Route.mock(id: "route-pack", districtId: "district-1", periodId: "period-1")
        let unchangedPoint = Point.mock(id: "point-unchanged", routeId: route.id, index: 0)
        let removedPoint = Point.mock(id: "point-removed", routeId: route.id, index: 1)
        var updatedPoint = unchangedPoint
        updatedPoint.index = 1
        let addedPoint = Point.mock(id: "point-added", routeId: route.id, index: 0)
        let removedPassage = RoutePassage.mock(id: "passage-removed", routeId: route.id, districtId: route.districtId)
        let addedPassage = RoutePassage.mock(id: "passage-added", routeId: route.id, districtId: route.districtId)
        let pack = RoutePack(route: route, points: [updatedPoint, addedPoint], passages: [addedPassage])
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in .mock(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 3, day: 1)) }
        )
        var receivedMutations: [DataStoreMutation] = []
        let dataStore = DataStoreMock(
            transactionWriteHandler: { mutations in receivedMutations = mutations }
        )
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        let result = try await subject.put(
            pack,
            oldPoints: [unchangedPoint, removedPoint],
            oldPassages: [removedPassage]
        )

        #expect(result == pack)
        #expect(dataStore.transactionWriteCallCount == 1)
        #expect(dataStore.putCallCount == 0)
        #expect(dataStore.deleteCallCount == 0)
        #expect(receivedMutations.count == 6)
        #expect(Set(receivedMutations.map(\.key)) == Set([
            .init(pk: "DISTRICT#district-1", sk: "ROUTE#route-pack"),
            .init(pk: "ROUTE#route-pack", sk: "POINT#point-removed"),
            .init(pk: "ROUTE#route-pack", sk: "POINT#point-unchanged"),
            .init(pk: "ROUTE#route-pack", sk: "POINT#point-added"),
            .init(pk: "ROUTE#route-pack", sk: "PASSAGE#passage-removed"),
            .init(pk: "ROUTE#route-pack", sk: "PASSAGE#passage-added")
        ]))
        let putCount = receivedMutations.reduce(into: 0) { count, mutation in
            if case .put = mutation.operation { count += 1 }
        }
        let deleteCount = receivedMutations.reduce(into: 0) { count, mutation in
            if case .delete = mutation.operation { count += 1 }
        }
        #expect(putCount == 4)
        #expect(deleteCount == 2)
    }

    @Test
    func putPack_異常_transaction失敗時に個別書き込みへfallbackしない() async {
        let route = Route.mock(id: "route-pack", districtId: "district-1", periodId: "period-1")
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in .mock(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 3, day: 1)) }
        )
        let dataStore = DataStoreMock(
            transactionWriteHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.init(route: route, points: [], passages: []), oldPoints: [], oldPassages: [])
        }

        #expect(dataStore.transactionWriteCallCount == 1)
        #expect(dataStore.putCallCount == 0)
        #expect(dataStore.deleteCallCount == 0)
    }

    @Test
    func putPack_異常_Repository境界でも重複IDを拒否する() async {
        let route = Route.mock(id: "route-pack", districtId: "district-1", periodId: "period-1")
        let point = Point.mock(id: "point-duplicate", routeId: route.id)
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in .mock(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 3, day: 1)) }
        )
        let dataStore = DataStoreMock()
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        await #expect(throws: Error.badRequest("RoutePackの子要素IDが重複しています。")) {
            _ = try await subject.put(
                .init(route: route, points: [point, point], passages: []),
                oldPoints: [],
                oldPassages: []
            )
        }

        #expect(dataStore.transactionWriteCallCount == 0)
        #expect(dataStore.putCallCount == 0)
        #expect(dataStore.deleteCallCount == 0)
    }

    @Test
    func transactionMutation_異常_101件は書き込み前に拒否する() throws {
        let mutations = try (0..<101).map { index in
            try DataStoreMutation.put(Record(
                pk: "ROUTE#route-\(index)",
                sk: "POINT#point-\(index)",
                content: Point.mock(id: "point-\(index)", routeId: "route-\(index)")
            ))
        }

        #expect(throws: Error.badRequest("一度に更新できるデータ数の上限を超えています。")) {
            try DataStoreMutation.validate(mutations)
        }
    }

    @Test
    func transactionMutation_異常_同一キー重複は書き込み前に拒否する() throws {
        let item = Point.mock(id: "point-1", routeId: "route-1")
        let mutations = [
            try DataStoreMutation.put(Record(pk: "ROUTE#route-1", sk: "POINT#point-1", content: item)),
            DataStoreMutation.delete(pk: "ROUTE#route-1", sk: "POINT#point-1")
        ]

        #expect(throws: Error.badRequest("一度に同じデータを複数回更新できません。")) {
            try DataStoreMutation.validate(mutations)
        }
    }
}

private extension RoutePackTransactionTest {
    func make(
        dataStore: DataStoreMock,
        districtRepository: DistrictRepositoryMock = .init(
            queryHandler: { festivalId in [.mock(id: "district-1", festivalId: festivalId)] }
        ),
        periodRepository: PeriodRepositoryMock
    ) -> RouteRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
        } operation: {
            RouteRepository()
        }
    }
}
