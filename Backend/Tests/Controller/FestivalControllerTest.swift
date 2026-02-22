import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalControllerTest {
    @Test
    func get_returnsPackFromUsecase() async throws {
        let expected = FestivalPack.mock(festival: .mock(id: "festival-1"))
        var capturedId: String?

        let mock = FestivalUsecaseMock(
            getHandler: { id in
                capturedId = id
                return expected
            }
        )
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-1",
            parameters: ["festivalId": "festival-1"]
        )
        let response = try await subject.get(request, next: next)
        let actual = try FestivalPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedId == "festival-1")
        #expect(mock.getCallCount == 1)
    }

    @Test
    func scan_returnsFestivals() async throws {
        let festivals = [Festival.mock(id: "festival-1")]
        let mock = FestivalUsecaseMock(scanHandler: { festivals })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/festivals")
        let response = try await subject.scan(request, next: next)
        let actual = try [Festival].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == festivals)
        #expect(mock.scanCallCount == 1)
    }

    @Test
    func put_usesGuestWhenUserIsNil() async throws {
        let expected = FestivalPack.mock(festival: .mock(id: "festival-2"))
        var capturedUser: UserRole?

        let mock = FestivalUsecaseMock(
            putHandler: { pack, user in
                capturedUser = user
                return pack
            }
        )
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .put,
            path: "/festivals/festival-2",
            parameters: ["festivalId": "festival-2"],
            body: try expected.toString()
        )
        let response = try await subject.put(request, next: next)
        let actual = try FestivalPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedUser == .guest)
        #expect(mock.putCallCount == 1)
    }

    @Test
    func get_missingFestivalId_throwsBadRequest() async {
        let subject = make(usecase: FestivalUsecaseMock())
        let request = Application.Request.make(method: .get, path: "/festivals")

        await #expect(throws: Error.badRequest("送信されたデータが不十分です。")) {
            _ = try await subject.get(request, next: next)
        }
    }
}

private extension FestivalControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: FestivalUsecaseMock) -> FestivalController {
        withDependencies {
            $0[FestivalUsecaseKey.self] = usecase
        } operation: {
            FestivalController()
        }
    }
}
