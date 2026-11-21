//
//  Edition.swift
//  matool-shared
//

public struct Edition: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    public let year: Int

    public init(id: String, festivalId: Festival.ID, year: Int) {
        self.id = id
        self.festivalId = festivalId
        self.year = year
    }
}

public struct ActiveEdition: Entity {
    public let festivalId: Festival.ID
    public let editionId: Edition.ID

    public init(festivalId: Festival.ID, editionId: Edition.ID) {
        self.festivalId = festivalId
        self.editionId = editionId
    }
}
