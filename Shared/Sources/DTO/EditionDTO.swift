public struct EditionListResponse: DTO {
    public let editions: [Edition]
    @NullEncodable public var activeEditionId: Edition.ID?

    public init(editions: [Edition], activeEditionId: Edition.ID?) {
        self.editions = editions
        self.activeEditionId = activeEditionId
    }
}

public struct EditionCreateForm: DTO {
    public let year: Int

    public init(year: Int) {
        self.year = year
    }
}

public struct ActiveEditionUpdateForm: DTO {
    public let editionId: Edition.ID

    public init(editionId: Edition.ID) {
        self.editionId = editionId
    }
}
