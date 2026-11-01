import Shared
@testable import Backend

actor FestivalRepositorySpy: FestivalRepositoryProtocol {
    private var festivals: [String: Festival]
    private(set) var getIDs: [String] = []
    private(set) var putItems: [Festival] = []

    init(festivals: [Festival] = []) {
        self.festivals = Dictionary(uniqueKeysWithValues: festivals.map { ($0.id, $0) })
    }

    func get(id: String) async throws -> Festival? {
        getIDs.append(id)
        return festivals[id]
    }

    func scan() async throws -> [Festival] {
        Array(festivals.values)
    }

    func put(_ item: Festival) async throws -> Festival {
        putItems.append(item)
        festivals[item.id] = item
        return item
    }

    func storedFestival(id: String) -> Festival? {
        festivals[id]
    }
}

actor DistrictRepositorySpy: DistrictRepositoryProtocol {
    private var districts: [String: District]
    private(set) var getIDs: [String] = []
    private(set) var putItems: [(String, District)] = []
    private(set) var postItems: [District] = []

    init(districts: [District] = []) {
        self.districts = Dictionary(uniqueKeysWithValues: districts.map { ($0.id, $0) })
    }

    func get(id: String) async throws -> District? {
        getIDs.append(id)
        return districts[id]
    }

    func query(by festivalId: String) async throws -> [District] {
        districts.values.filter { $0.festivalId == festivalId }
    }

    func put(id: String, item: District) async throws -> District {
        putItems.append((id, item))
        districts[id] = item
        return item
    }

    func post(item: District) async throws -> District {
        postItems.append(item)
        districts[item.id] = item
        return item
    }

    func storedDistrict(id: String) -> District? {
        districts[id]
    }
}
