import Shared

/// 地図・紹介タブ間で共有する、公開コンテンツの選択状態。
/// EntityそのものはSQLiteDataのキャッシュから再取得し、ここではIDだけを保持する。
struct PublicSelectionContext: Equatable, Sendable {
    var festivalID: Festival.ID?
    var districtID: District.ID?
    var routeID: Route.ID?

    init(
        festivalID: Festival.ID? = nil,
        districtID: District.ID? = nil,
        routeID: Route.ID? = nil
    ) {
        self.festivalID = festivalID
        self.districtID = districtID
        self.routeID = routeID
    }
}
