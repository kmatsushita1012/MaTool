import Dependencies
import Shared
import Testing
@testable import Backend

struct ImagePathFinalizerTests {
    @Test func replacesOnlyTheSelectedVariantAfterPublish() async throws {
        let spy = S3ImageClientSpy()
        let incoming = ImagePath(light: "temporary/festivals/festival-1/light.jpg", dark: "https://legacy.example/dark.jpg")
        let current = ImagePath(light: "https://cdn.example/old.jpg?v=4", dark: "https://legacy.example/dark.jpg")

        let result = try await withDependencies {
            $0[S3ImageClientKey.self] = spy
        } operation: {
            try await ImagePathFinalizer().finalize(incoming: incoming, current: current, type: .festival, id: "festival-1")
        }

        #expect(result.light == "https://cdn.example.test/image.jpg?v=1")
        #expect(result.dark == current.dark)
        let calls = await spy.publishCalls
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "temporary/festivals/festival-1/light.jpg")
        #expect(calls.first?.1 == "festivals/festival-1/light.jpg")
        #expect(calls.first?.2 == current.light)
    }

    @Test func rejectsMismatchedTemporaryKeyWithoutPublishing() async {
        let spy = S3ImageClientSpy()
        await #expect(throws: Error.self) {
            try await withDependencies {
                $0[S3ImageClientKey.self] = spy
            } operation: {
                try await ImagePathFinalizer().finalize(
                    incoming: .init(light: "temporary/festivals/another/light.jpg"),
                    current: .init(), type: .festival, id: "festival-1"
                )
            }
        }
        let calls = await spy.publishCalls
        #expect(calls.isEmpty)
    }
}
