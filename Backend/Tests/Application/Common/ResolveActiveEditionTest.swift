import Shared
import Testing
@testable import Backend

struct ResolveActiveEditionTest {
    @Test
    func resolveActiveEdition_有効Editionを返す() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2028)
        let activeRepository = ActiveEditionRepositorySpy(getHandler: { festivalId in
            ActiveEdition(festivalId: festivalId, editionId: edition.id)
        })
        let editionRepository = EditionRepositorySpy(getHandler: { _ in edition })

        let result = try await resolveActiveEdition(
            festivalId: "festival-1",
            activeEditionRepository: activeRepository,
            editionRepository: editionRepository
        )

        #expect(result == edition)
        #expect(activeRepository.getCallCount == 1)
        #expect(editionRepository.getCallCount == 1)
    }

    @Test
    func resolveActiveEdition_未設定ならEdition検索をしない() async throws {
        let editionRepository = EditionRepositorySpy(getHandler: { _ in
            Issue.record("Edition lookup should not run without an active Edition")
            return nil
        })

        let result = try await resolveActiveEdition(
            festivalId: "festival-1",
            activeEditionRepository: ActiveEditionRepositorySpy(),
            editionRepository: editionRepository
        )

        #expect(result == nil)
        #expect(editionRepository.getCallCount == 0)
    }

    @Test
    func resolveActiveEdition_別FestivalのEditionは返さない() async throws {
        let editionRepository = EditionRepositorySpy(getHandler: { id in
            Edition(id: id, festivalId: "festival-other", year: 2028)
        })

        let result = try await resolveActiveEdition(
            festivalId: "festival-1",
            activeEditionRepository: ActiveEditionRepositorySpy(getHandler: { festivalId in
                ActiveEdition(festivalId: festivalId, editionId: "edition-foreign")
            }),
            editionRepository: editionRepository
        )

        #expect(result == nil)
    }
}
