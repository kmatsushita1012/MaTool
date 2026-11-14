import Shared
@testable import iOSApp

enum StoreAdImpressionOutcome: Sendable {
    case success
    case failure(AppError)
}

actor StoreAdDataFetcherSpy: StoreAdDataFetcherProtocol {
    private let candidate: AdCandidate?
    private let candidateError: AppError?
    private let impressionOutcomes: [StoreAdImpressionOutcome]
    private let reportDelay: Duration?

    private(set) var requestedFestivalIDs: [Festival.ID] = []
    private(set) var reportedImpressions: [ImpressionReportRequest] = []
    private(set) var maximumConcurrentReports = 0

    private var activeReports = 0
    private var reportWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(
        candidate: AdCandidate? = nil,
        candidateError: AppError? = nil,
        impressionOutcomes: [StoreAdImpressionOutcome] = [],
        reportDelay: Duration? = nil
    ) {
        self.candidate = candidate
        self.candidateError = candidateError
        self.impressionOutcomes = impressionOutcomes
        self.reportDelay = reportDelay
    }

    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate? {
        requestedFestivalIDs.append(festivalId)
        if let candidateError { throw candidateError }
        return candidate
    }

    func reportImpression(_ request: ImpressionReportRequest) async throws {
        activeReports += 1
        maximumConcurrentReports = max(maximumConcurrentReports, activeReports)
        defer { activeReports -= 1 }

        reportedImpressions.append(request)
        resumeSatisfiedWaiters()
        let responseIndex = reportedImpressions.count - 1
        if let reportDelay {
            try? await Task.sleep(for: reportDelay)
        }

        guard impressionOutcomes.indices.contains(responseIndex) else { return }
        if case .failure(let error) = impressionOutcomes[responseIndex] {
            throw error
        }
    }

    func waitForReportCount(_ count: Int) async {
        guard reportedImpressions.count < count else { return }
        await withCheckedContinuation { continuation in
            reportWaiters.append((count, continuation))
        }
    }

    func reportCount() -> Int { reportedImpressions.count }

    private func resumeSatisfiedWaiters() {
        let ready = reportWaiters.filter { $0.0 <= reportedImpressions.count }
        reportWaiters.removeAll { $0.0 <= reportedImpressions.count }
        ready.forEach { $0.1.resume() }
    }
}

actor SceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let response: LaunchDistrictPack
    private var districtLaunchCalls = 0

    init(response: LaunchDistrictPack) { self.response = response }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        districtLaunchCalls += 1
        return response
    }

    func districtLaunchCallCount() -> Int { districtLaunchCalls }
}

actor SignInSceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let festivalPack: LaunchFestivalPack
    private let districtPack: LaunchDistrictPack
    private var requests: [String] = []

    init(festivalPack: LaunchFestivalPack, districtPack: LaunchDistrictPack) {
        self.festivalPack = festivalPack
        self.districtPack = districtPack
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        requests.append("district")
        return districtPack
    }

    func requestedResources() -> [String] { requests }
}

actor SelectFestivalDataFetcherSpy: SceneDataFetcherProtocol {
    private let responses: [Result<LaunchFestivalPack, Error>]
    private(set) var festivalRequests: [Festival.ID] = []

    init(responses: [Result<LaunchFestivalPack, Error>]) {
        self.responses = responses
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        festivalRequests.append(festivalId)
        let response = responses[min(festivalRequests.count - 1, responses.count - 1)]
        return try response.get()
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw SpyInvocationError.unexpected("launchFestival(districtId:)")
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        throw SpyInvocationError.unexpected("launchDistrict")
    }
}

actor SignOutSceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let festivalPack: LaunchFestivalPack
    private let districtPack: LaunchDistrictPack
    private let failsDistrictLaunch: Bool
    private(set) var requests: [String] = []

    init(
        festivalPack: LaunchFestivalPack,
        districtPack: LaunchDistrictPack,
        failsDistrictLaunch: Bool = false
    ) {
        self.festivalPack = festivalPack
        self.districtPack = districtPack
        self.failsDistrictLaunch = failsDistrictLaunch
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        requests.append("festival:\(festivalId)")
        return festivalPack
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        requests.append("festivalFromDistrict:\(districtId)")
        return festivalPack
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        requests.append("district:\(districtId):period:\(periodId ?? "nil")")
        if failsDistrictLaunch {
            throw AppError.be(.network("offline"))
        }
        return districtPack
    }
}

actor SignInSignOutSpy {
    private var calls = 0

    func record() { calls += 1 }
    func count() -> Int { calls }
}


// Used only when a test needs a safe default; explicit fixture spies replace this.
actor UnconfiguredSceneDataFetcherSpy: SceneDataFetcherProtocol {
    private(set) var requests: [String] = []

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        requests.append("festival: \(festivalId)")
        throw SpyInvocationError.unexpected("launchFestival")
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        requests.append("festival from district: \(districtId)")
        throw SpyInvocationError.unexpected("launchFestival(districtId:)")
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        requests.append("district: \(districtId)")
        throw SpyInvocationError.unexpected("launchDistrict")
    }
}
