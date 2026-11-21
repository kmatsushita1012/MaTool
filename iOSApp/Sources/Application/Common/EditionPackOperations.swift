import Shared

func fetchEditionPack(
    festivalID: Festival.ID,
    editionID: Edition.ID,
    using dataFetcher: any EditionDataFetcherProtocol
) async throws -> EditionPack {
    let list = try await dataFetcher.fetchList(festivalID: festivalID)
    guard let edition = list.editions.first(where: { $0.id == editionID }) else {
        throw AppError.be(.notFound("対象の年度が見つかりません。"))
    }
    let pack = try await dataFetcher.fetch(festivalID: festivalID, year: edition.year)
    guard pack.edition.id == editionID else {
        throw AppError.be(.conflict("年度情報が更新されました。再度お試しください。"))
    }
    return pack
}
