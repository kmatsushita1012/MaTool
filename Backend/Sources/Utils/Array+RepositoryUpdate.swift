import Shared

extension Array where Element: Equatable & Identifiable {
    func update<R: Repository>(
        with new: [Element],
        separateDeleteAndUpdate: Bool = false,
        repository: R
    ) async throws -> [Element] where R.Content == Element {
        let oldItems = self

        return try await oldItems.diff(
            with: new,
            separateDeleteAndUpdate: separateDeleteAndUpdate,
            onAdd: { try await repository.post($0) },
            onUpdate: { try await repository.put($0) },
            onDelete: { try await repository.delete($0) }
        )
    }
}
