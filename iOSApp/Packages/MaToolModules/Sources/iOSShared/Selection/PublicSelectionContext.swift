import Shared

/// 地図・紹介タブ間で共有する、公開コンテンツの選択状態。
/// EntityそのものはSQLiteDataのキャッシュから再取得し、ここではIDだけを保持する。
public struct PublicSelectionContext: Equatable, Sendable {
    public var festivalID: Festival.ID?
    public var districtID: District.ID?
    public var routeID: Route.ID?

    public init(
        festivalID: Festival.ID? = nil,
        districtID: District.ID? = nil,
        routeID: Route.ID? = nil
    ) {
        self.festivalID = festivalID
        self.districtID = districtID
        self.routeID = routeID
    }
}
