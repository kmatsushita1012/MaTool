import ComposableArchitecture
import Shared
@testable import iOSApp

actor EditionDataFetcherSpy: EditionDataFetcherProtocol {
    enum Operation: Hashable, Sendable {
        case fetchList
        case create
        case fetch
        case update
        case activate
    }

    enum Call: Equatable, Sendable {
        case fetchList(Festival.ID)
        case create(Festival.ID, Int)
        case fetch(Festival.ID, Int)
        case update(Int, [Period.ID])
        case activate(Festival.ID, Edition.ID)
    }

    private(set) var list: EditionListResponse
    let pack: EditionPack
    let activeEdition: ActiveEdition
    let failures: [Operation: AppError]
    let updatedPack: EditionPack
    private var recorded: [Call] = []

    init(
        list: EditionListResponse,
        pack: EditionPack,
        activeEdition: ActiveEdition,
        failures: [Operation: AppError] = [:],
        updatedPack: EditionPack? = nil
    ) {
        self.list = list
        self.pack = pack
        self.activeEdition = activeEdition
        self.failures = failures
        self.updatedPack = updatedPack ?? pack
    }

    func calls() -> [Call] { recorded }

    func fetchList(festivalID: Festival.ID) async throws -> EditionListResponse {
        recorded.append(.fetchList(festivalID))
        try checkFailure(.fetchList)
        return list
    }

    func create(festivalID: Festival.ID, year: Int) async throws -> EditionPack {
        recorded.append(.create(festivalID, year))
        try checkFailure(.create)
        return pack
    }

    func fetch(festivalID: Festival.ID, year: Int) async throws -> EditionPack {
        recorded.append(.fetch(festivalID, year))
        try checkFailure(.fetch)
        return pack
    }

    func update(_ pack: EditionPack) async throws -> EditionPack {
        recorded.append(.update(pack.edition.year, pack.periods.map(\.id)))
        try checkFailure(.update)
        return updatedPack
    }

    func activate(festivalID: Festival.ID, editionID: Edition.ID) async throws -> ActiveEdition {
        recorded.append(.activate(festivalID, editionID))
        try checkFailure(.activate)
        list = EditionListResponse(editions: list.editions, activeEditionId: editionID)
        return ActiveEdition(festivalId: festivalID, editionId: editionID)
    }

    private func checkFailure(_ operation: Operation) throws {
        if let error = failures[operation] { throw error }
    }
}

actor ReloadAppStateUseCaseSpy: ReloadAppStateUseCaseProtocol {
    private let failure: AppError?
    private(set) var calls = 0

    init(failure: AppError? = nil) {
        self.failure = failure
    }

    func callAsFunction(appState: Shared<AppState?>) async throws {
        calls += 1
        if let failure { throw failure }
    }
}
