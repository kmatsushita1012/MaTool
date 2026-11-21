import Shared

func fetchEditionConsistentLaunchPacks(
    districtID: District.ID,
    periodID: Period.ID? = nil,
    using dataFetcher: any SceneDataFetcherProtocol
) async throws -> (festival: LaunchFestivalPack, district: LaunchDistrictPack) {
    let firstPair = try await fetchLaunchPair(
        districtID: districtID,
        periodID: periodID,
        using: dataFetcher
    )
    guard !hasMatchingEdition(firstPair) else { return firstPair }

    let retriedPair = try await fetchLaunchPair(
        districtID: districtID,
        periodID: periodID,
        using: dataFetcher
    )
    guard hasMatchingEdition(retriedPair) else {
        throw AppError.be(.conflict("祭典と地区の起動データで有効な年度が一致しません。再度お試しください。"))
    }
    return retriedPair
}

private func fetchLaunchPair(
    districtID: District.ID,
    periodID: Period.ID?,
    using dataFetcher: any SceneDataFetcherProtocol
) async throws -> (festival: LaunchFestivalPack, district: LaunchDistrictPack) {
    async let festival = dataFetcher.launchFestival(districtId: districtID)
    async let district = dataFetcher.launchDistrict(districtId: districtID, periodId: periodID)
    return try await (festival, district)
}

private func hasMatchingEdition(
    _ pair: (festival: LaunchFestivalPack, district: LaunchDistrictPack)
) -> Bool {
    pair.festival.edition?.id == pair.district.editionId
}
