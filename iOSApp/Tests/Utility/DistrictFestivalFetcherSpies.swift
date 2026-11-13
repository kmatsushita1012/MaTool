import Shared
@testable import iOSApp

actor DistrictDataFetcherSpy: DistrictDataFetcherProtocol {
    let response: DistrictPack
    let shouldFail: Bool
    private var operations: [String] = []

    init(response: DistrictPack, shouldFail: Bool = false) {
        self.response = response
        self.shouldFail = shouldFail
    }

    func recordedCalls() -> [String] { operations }

    private func checked() throws {
        if shouldFail { throw FetcherTestError.failed }
    }

    func create(name: String, email: String, festivalId: String) async throws -> DistrictPack {
        operations.append("create:\(name):\(email):\(festivalId)")
        try checked()
        return response
    }

    func reissue(districtId: District.ID, email: String) async throws -> DistrictPack {
        operations.append("reissue:\(districtId):\(email)")
        try checked()
        return response
    }

    func update(district: District, performances: [Performance]) async throws -> DistrictPack {
        operations.append("updatePack:\(district.id):\(performances.count)")
        try checked()
        return response
    }

    func update(district: District) async throws -> District {
        operations.append("updateCore:\(district.id)")
        try checked()
        return response.district
    }

    func fetchAll(festivalID: Festival.ID) async throws -> [District] {
        operations.append("fetchAll:\(festivalID)")
        try checked()
        return [response.district]
    }

    func fetch(districtID: District.ID) async throws -> DistrictPack {
        operations.append("fetch:\(districtID)")
        try checked()
        return response
    }
}

actor FestivalDataFetcherSpy: FestivalDataFetcherProtocol {
    let response: FestivalPack
    let festivalList: [Festival]
    let shouldFail: Bool
    private var operations: [String] = []

    init(response: FestivalPack, festivalList: [Festival] = [], shouldFail: Bool = false) {
        self.response = response
        self.festivalList = festivalList
        self.shouldFail = shouldFail
    }

    func recordedCalls() -> [String] { operations }

    func update(
        festival: Festival,
        checkPoints: [Checkpoint],
        hazardSections: [HazardSection]
    ) async throws -> FestivalPack {
        operations.append("update:\(festival.id):\(checkPoints.count):\(hazardSections.count)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func fetchAll() async throws -> [Festival] {
        operations.append("fetchAll")
        if shouldFail { throw FetcherTestError.failed }
        return festivalList
    }

    func fetch(festivalID: Festival.ID) async throws -> FestivalPack {
        operations.append("fetch:\(festivalID)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }
}
