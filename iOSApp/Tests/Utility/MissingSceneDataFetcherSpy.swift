import Shared
@testable import iOSApp

/// 外部通信せずにNot Foundを返す、削除済み祭典のユニットテスト用Spy。
struct MissingSceneDataFetcherSpy: SceneDataFetcherProtocol {
    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        throw AppError.be(.notFound("festival not found"))
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw AppError.be(.notFound("festival not found"))
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        throw AppError.be(.notFound("district not found"))
    }
}
