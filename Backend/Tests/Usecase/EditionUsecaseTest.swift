import Dependencies
import Shared
import Testing
@testable import Backend

struct EditionUsecaseTest {
    @Test
    func query_有効Edition未設定時はnilを返す() async throws {
        let festival = Festival.mock(id: "festival-1")
        let editions = [
            Edition(id: "edition-2027", festivalId: festival.id, year: 2027),
            Edition(id: "edition-2026", festivalId: festival.id, year: 2026)
        ]
        let activeRepository = ActiveEditionRepositorySpy()
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(queryHandler: { _ in editions }),
            activeEditionRepository: activeRepository
        )

        let response = try await subject.query(festivalId: festival.id, user: .headquarter(festival.id))

        #expect(response.editions.map(\.year) == [2026, 2027])
        #expect(response.activeEditionId == nil)
        #expect(activeRepository.putCallCount == 0)
    }

    @Test
    func create_空のEditionを作成し自動有効化しない() async throws {
        let festival = Festival.mock(id: "festival-1")
        var created: Edition?
        let activeRepository = ActiveEditionRepositorySpy()
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(postHandler: { edition in
                created = edition
                return edition
            }),
            activeEditionRepository: activeRepository
        )

        let pack = try await subject.create(festivalId: festival.id, year: 2027, user: .headquarter(festival.id))

        #expect(pack.edition.festivalId == festival.id)
        #expect(pack.edition.year == 2027)
        #expect(!pack.edition.id.isEmpty)
        #expect(pack.periods.isEmpty)
        #expect(created == pack.edition)
        #expect(activeRepository.putCallCount == 0)
    }

    @Test
    func create_同一年が存在すれば409にする() async {
        let festival = Festival.mock(id: "festival-1")
        let existingEdition = Edition(id: "edition-2027", festivalId: festival.id, year: 2027)
        let editionRepository = EditionRepositorySpy(
            getByYearHandler: { _, _ in existingEdition }
        )
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: editionRepository
        )

        await #expect(throws: Error.conflict("この祭典には同じ年度のEditionがすでに存在します。")) {
            _ = try await subject.create(festivalId: festival.id, year: 2027, user: .headquarter(festival.id))
        }
        #expect(editionRepository.postCallCount == 0)
    }

    @Test
    func put_差分削除でRouteと子要素を削除し再試行できる() async throws {
        let festival = Festival.mock(id: "festival-1")
        let edition = Edition(id: "edition-2026", festivalId: festival.id, year: 2026)
        let existing = period(id: "period-1", edition: edition)
        let removed = period(id: "period-2", edition: edition)
        var updated = existing
        updated.title = "更新済み"
        let added = period(id: "period-3", edition: edition, start: .init(hour: 10, minute: 0))
        let firstDistrict = District.mock(id: "district-1", festivalId: festival.id)
        let secondDistrict = District.mock(id: "district-2", festivalId: festival.id)
        let route1 = Route.mock(id: "route-1", districtId: firstDistrict.id, periodId: removed.id)
        let unrelatedRoute = Route.mock(id: "route-other", districtId: firstDistrict.id, periodId: "another-period")
        let route2 = Route.mock(id: "route-2", districtId: secondDistrict.id, periodId: removed.id)
        var storedPeriods: [Period] = [existing, removed]
        var failedOnce = false
        let periodRepository = PeriodRepositorySpy(
            getHandler: { id in storedPeriods.first(where: { $0.id == id }) },
            queryByEditionHandler: { _ in storedPeriods },
            putHandler: { item in
                if item.id == added.id && !failedOnce {
                    failedOnce = true
                    throw TestError.intentional
                }
                storedPeriods.removeAll(where: { $0.id == item.id })
                storedPeriods.append(item)
                return item
            },
            deleteHandler: { id in storedPeriods.removeAll(where: { $0.id == id }) }
        )
        let routeRepository = RouteManagementRepositorySpy(queryHandler: { districtId in
            districtId == firstDistrict.id ? [route1, unrelatedRoute] : [route2]
        })
        let pointRepository = PointManagementRepositorySpy()
        let passageRepository = PassageManagementRepositorySpy()
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(getByYearHandler: { _, _ in edition }),
            periodRepository: periodRepository,
            districtRepository: DistrictManagementRepositorySpy(queryHandler: { _ in [firstDistrict, secondDistrict] }),
            routeRepository: routeRepository,
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )
        let pack = EditionPack(edition: edition, periods: [updated, added])

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(festivalId: festival.id, year: edition.year, pack: pack, user: .headquarter(festival.id))
        }
        let savedPack = try await subject.put(festivalId: festival.id, year: edition.year, pack: pack, user: .headquarter(festival.id))

        #expect(periodRepository.deletedIDs == [removed.id])
        #expect(routeRepository.deletedIDs == [route1.id, route2.id])
        #expect(pointRepository.deletedRouteIDs == [route1.id, route2.id])
        #expect(passageRepository.deletedRouteIDs == [route1.id, route2.id])
        #expect(savedPack.periods == [updated, added])
    }

    @Test
    func put_重複日時や別EditionのPeriodを拒否する() async {
        let festival = Festival.mock(id: "festival-1")
        let edition = Edition(id: "edition-2026", festivalId: festival.id, year: 2026)
        let first = period(id: "period-1", edition: edition)
        let duplicateStart = period(id: "period-2", edition: edition)
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(getByYearHandler: { _, _ in edition })
        )

        await #expect(throws: Error.badRequest("同じ日時の開始時刻を持つ日程は登録できません。")) {
            _ = try await subject.put(
                festivalId: festival.id,
                year: edition.year,
                pack: EditionPack(edition: edition, periods: [first, duplicateStart]),
                user: .headquarter(festival.id)
            )
        }

        let foreignEditionPeriod = period(id: "period-foreign", edition: edition)
        let storedForeignEditionPeriod = period(id: foreignEditionPeriod.id, edition: edition, storedEditionId: "edition-other")
        let foreignPeriodRepository = PeriodRepositorySpy(getHandler: { id in id == storedForeignEditionPeriod.id ? storedForeignEditionPeriod : nil })
        let foreignSubject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(getByYearHandler: { _, _ in edition }),
            periodRepository: foreignPeriodRepository
        )

        await #expect(throws: Error.badRequest("別のEditionに所属する日程は移動できません。")) {
            _ = try await foreignSubject.put(
                festivalId: festival.id,
                year: edition.year,
                pack: EditionPack(edition: edition, periods: [foreignEditionPeriod]),
                user: .headquarter(festival.id)
            )
        }
        #expect(foreignPeriodRepository.putCallCount == 0)
    }

    @Test
    func putActive_過去Editionへの切り戻しを許可する() async throws {
        let festival = Festival.mock(id: "festival-1")
        let previousEdition = Edition(id: "edition-2024", festivalId: festival.id, year: 2024)
        var current: ActiveEdition?
        let activeRepository = ActiveEditionRepositorySpy(putHandler: { current = $0; return $0 })
        let subject = make(
            festivalRepository: FestivalRepositorySpy(festivals: [festival]),
            editionRepository: EditionRepositorySpy(getHandler: { id in id == previousEdition.id ? previousEdition : nil }),
            activeEditionRepository: activeRepository
        )

        let result = try await subject.putActive(festivalId: festival.id, editionId: previousEdition.id, user: .headquarter(festival.id))
        let repeated = try await subject.putActive(festivalId: festival.id, editionId: previousEdition.id, user: .headquarter(festival.id))

        #expect(result == ActiveEdition(festivalId: festival.id, editionId: previousEdition.id))
        #expect(repeated == result)
        #expect(current == result)
        #expect(activeRepository.putCallCount == 2)
    }

    @Test
    func query_権限不一致を401と403で分ける() async {
        let festival = Festival.mock(id: "festival-1")
        let subject = make(festivalRepository: FestivalRepositorySpy(festivals: [festival]))

        await #expect(throws: Error.unauthorized("ログインしてください。")) {
            _ = try await subject.query(festivalId: festival.id, user: .guest)
        }
        await #expect(throws: Error.forbidden("対象祭典の本部ユーザーのみ操作できます。")) {
            _ = try await subject.query(festivalId: festival.id, user: .headquarter("festival-other"))
        }
    }
}

private extension EditionUsecaseTest {
    func make(
        festivalRepository: FestivalRepositorySpy = .init(),
        editionRepository: EditionRepositorySpy = .init(),
        activeEditionRepository: ActiveEditionRepositorySpy = .init(),
        periodRepository: PeriodRepositorySpy = .init(),
        districtRepository: DistrictManagementRepositorySpy = .init(),
        routeRepository: RouteManagementRepositorySpy = .init(),
        pointRepository: PointManagementRepositorySpy = .init(),
        passageRepository: PassageManagementRepositorySpy = .init()
    ) -> EditionUsecase {
        withDependencies {
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[EditionRepositoryKey.self] = editionRepository
            $0[ActiveEditionRepositoryKey.self] = activeEditionRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
        } operation: {
            EditionUsecase()
        }
    }

    func period(
        id: Period.ID,
        edition: Edition,
        storedEditionId: Edition.ID? = nil,
        date: SimpleDate = .init(year: 2026, month: 2, day: 22),
        start: SimpleTime = .init(hour: 9, minute: 0)
    ) -> Period {
        Period(
            id: id,
            editionId: storedEditionId ?? edition.id,
            festivalId: edition.festivalId,
            date: date,
            start: start,
            end: .init(hour: 18, minute: 0)
        )
    }
}
