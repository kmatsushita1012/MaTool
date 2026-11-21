import Dependencies
import Shared
import Testing
@testable import Backend

struct EditionControllerTest {
    @Test
    func query_祭典IDとユーザーを渡す() async throws {
        let expected = EditionListResponse(editions: [], activeEditionId: nil)
        var receivedFestivalId: Festival.ID?
        var receivedUser: UserRole?
        let usecase = EditionUsecaseSpy(queryHandler: { festivalId, user in
            receivedFestivalId = festivalId
            receivedUser = user
            return expected
        })
        let subject = make(usecase: usecase)
        var request = Application.Request.make(
            method: .get,
            path: "/v1/festivals/festival-1/editions",
            parameters: ["festivalId": "festival-1"]
        )
        request.user = .headquarter("festival-1")

        let response = try await subject.query(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(try EditionListResponse.from(response.body) == expected)
        #expect(receivedFestivalId == "festival-1")
        #expect(receivedUser == .headquarter("festival-1"))
    }

    @Test
    func create_Formの年度をUsecaseへ渡す() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2027)
        let expected = EditionPack(edition: edition, periods: [])
        var receivedYear: Int?
        let usecase = EditionUsecaseSpy(createHandler: { _, year, _ in
            receivedYear = year
            return expected
        })
        let subject = make(usecase: usecase)
        var request = Application.Request.make(
            method: .post,
            path: "/v1/festivals/festival-1/editions",
            parameters: ["festivalId": "festival-1"],
            body: try EditionCreateForm(year: 2027).toString()
        )
        request.user = .headquarter("festival-1")

        let response = try await subject.create(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(try EditionPack.from(response.body) == expected)
        #expect(receivedYear == 2027)
    }

    @Test
    func get_URLの年度をUsecaseへ渡す() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        let expected = EditionPack(edition: edition, periods: [])
        var receivedYear: Int?
        let subject = make(usecase: EditionUsecaseSpy(getHandler: { _, year, _ in
            receivedYear = year
            return expected
        }))
        var request = Application.Request.make(
            method: .get,
            path: "/v1/festivals/festival-1/editions/2026",
            parameters: ["festivalId": "festival-1", "year": "2026"]
        )
        request.user = .headquarter("festival-1")

        let response = try await subject.get(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(try EditionPack.from(response.body) == expected)
        #expect(receivedYear == 2026)
    }

    @Test
    func put_EditionPackをUsecaseへ渡す() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        let pack = EditionPack(edition: edition, periods: [])
        var receivedYear: Int?
        var receivedPack: EditionPack?
        let subject = make(usecase: EditionUsecaseSpy(putHandler: { _, year, body, _ in
            receivedYear = year
            receivedPack = body
            return body
        }))
        var request = Application.Request.make(
            method: .put,
            path: "/v1/festivals/festival-1/editions/2026",
            parameters: ["festivalId": "festival-1", "year": "2026"],
            body: try pack.toString()
        )
        request.user = .headquarter("festival-1")

        let response = try await subject.put(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(try EditionPack.from(response.body) == pack)
        #expect(receivedYear == 2026)
        #expect(receivedPack == pack)
    }

    @Test
    func putActive_FormのEditionIDをUsecaseへ渡す() async throws {
        let expected = ActiveEdition(festivalId: "festival-1", editionId: "edition-2024")
        var receivedEditionId: Edition.ID?
        let subject = make(usecase: EditionUsecaseSpy(putActiveHandler: { _, editionId, _ in
            receivedEditionId = editionId
            return expected
        }))
        var request = Application.Request.make(
            method: .put,
            path: "/v1/festivals/festival-1/active-edition",
            parameters: ["festivalId": "festival-1"],
            body: try ActiveEditionUpdateForm(editionId: "edition-2024").toString()
        )
        request.user = .headquarter("festival-1")

        let response = try await subject.putActive(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(try ActiveEdition.from(response.body) == expected)
        #expect(receivedEditionId == "edition-2024")
    }
}

private extension EditionControllerTest {
    var next: Handler { { _ in throw TestError.intentional } }

    func make(usecase: EditionUsecaseSpy) -> EditionController {
        withDependencies {
            $0[EditionUsecaseKey.self] = usecase
        } operation: {
            EditionController()
        }
    }
}
