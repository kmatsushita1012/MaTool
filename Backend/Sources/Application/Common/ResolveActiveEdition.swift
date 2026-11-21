import Shared

func resolveActiveEdition(
    festivalId: Festival.ID,
    activeEditionRepository: ActiveEditionRepositoryProtocol,
    editionRepository: EditionRepositoryProtocol
) async throws -> Edition? {
    guard let activeEdition = try await activeEditionRepository.get(festivalId: festivalId),
          let edition = try await editionRepository.get(id: activeEdition.editionId),
          edition.festivalId == festivalId else {
        return nil
    }
    return edition
}
