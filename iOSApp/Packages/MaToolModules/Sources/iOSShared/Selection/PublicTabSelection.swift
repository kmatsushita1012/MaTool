import Shared

/// 地図タブと紹介タブで共有する選択状態。
///
/// EntityそのものはSQLiteDataのインメモリキャッシュから解決し、ここでは
/// タブ間同期に必要なIDだけを保持する。
public enum PublicTabSelection: Equatable, Sendable {
    public enum LinkedSelection: Equatable, Sendable {
        case festival(Festival.ID, routeID: Route.ID?)
        case district(Festival.ID, District.ID, routeID: Route.ID?)
    }

    public enum Source: Equatable, Sendable {
        case map
        case info
    }

    case linked(LinkedSelection)
    case unlinked(map: PublicSelectionContext?, info: PublicSelectionContext?)

    public var isLinked: Bool {
        if case .linked = self { return true }
        return false
    }

    public static func initial(
        linked: Bool,
        context: PublicSelectionContext
    ) -> Self {
        guard linked, let selection = selection(for: context) else {
            return .unlinked(map: context, info: context)
        }
        return .linked(selection)
    }

    public func updating(
        _ context: PublicSelectionContext,
        from source: Source
    ) -> Self {
        switch self {
        case .linked:
            guard let selection = Self.selection(for: context) else { return self }
            return .linked(selection)
        case .unlinked(let map, let info):
            switch source {
            case .map:
                return .unlinked(map: context, info: info)
            case .info:
                return .unlinked(map: map, info: context)
            }
        }
    }

    public func context(for source: Source) -> PublicSelectionContext? {
        switch self {
        case .linked(let selection):
            switch selection {
            case .festival(let festivalID, let routeID):
                return .init(festivalID: festivalID, routeID: routeID)
            case .district(let festivalID, let districtID, let routeID):
                return .init(
                    festivalID: festivalID,
                    districtID: districtID,
                    routeID: routeID
                )
            }
        case .unlinked(let map, let info):
            return source == .map ? map : info
        }
    }

    public func settingLinking(
        _ enabled: Bool,
        mapContext: PublicSelectionContext?,
        infoContext: PublicSelectionContext?
    ) -> Self {
        guard enabled else {
            return .unlinked(map: mapContext, info: infoContext)
        }
        guard let context = mapContext ?? infoContext,
              let selection = Self.selection(for: context) else {
            return self
        }
        return .linked(selection)
    }

    private static func selection(for context: PublicSelectionContext) -> LinkedSelection? {
        if let districtID = context.districtID {
            guard let festivalID = context.festivalID else { return nil }
            return .district(festivalID, districtID, routeID: context.routeID)
        }
        guard let festivalID = context.festivalID else { return nil }
        return .festival(festivalID, routeID: context.routeID)
    }
}
