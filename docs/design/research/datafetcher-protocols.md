# DataFetcher Protocol Specifications

This document summarizes all `DataFetcher` protocol interfaces found in the codebase under `iOSApp/Sources/Data/DataFetcher`.

---

## `DataFetcher`

Base marker protocol:

```swift
protocol DataFetcher: Sendable {}
```

Common helper available to all fetchers:

```swift
func getToken() async throws -> String?
```

---

## `Query`

The `Query` enum is used by several fetchers to control list requests. Definition:

```swift
enum Query: Sendable, Equatable {
    case all
    case year(Int)
    case latest

    var queryItems: [String: Any] {
        switch self {
        case .all:
            return [:]
        case .year(let y):
            return ["year": y]
        case .latest:
            return ["year": "latest"]
        }
    }
}
```

Purpose: supply query parameters for endpoints (fetch all, fetch by year, or fetch latest year).


---

## `FestivalDataFetcherProtocol`

```swift
protocol FestivalDataFetcherProtocol: DataFetcher {
    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws
    func fetchAll() async throws
    func fetch(festivalID: Festival.ID) async throws
}
```

Purpose: fetch and sync festival-level data and update festival with checkpoints and hazard sections.

---

## `DistrictDataFetcherProtocol`

```swift
protocol DistrictDataFetcherProtocol: DataFetcher {
    func create(name: String, email: String, festivalId: String) async throws
    func update(district: District, performances: [Performance]) async throws
    func update(district: District) async throws
    func fetchAll(festivalID: Festival.ID) async throws
    func fetch(districtID: District.ID) async throws
}
```

Purpose: manage districts and their performances (create, update, fetch).

---

## `LocationDataFetcherProtocol`

```swift
protocol LocationDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalId: Festival.ID) async throws
    func fetch(districtId: District.ID) async throws
    func update(_ location: FloatLocation) async throws
    func delete(districtId: District.ID) async throws
}
```

Purpose: fetch and sync location data, update single location, and delete locations by district.

---

## `PeriodDataFetcherProtocol`

```swift
protocol PeriodDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalID: Festival.ID, query: Query) async throws
    func fetch(_ id: Period.ID) async throws
    func update(_ period: Period) async throws
    func create(_ period: Period) async throws
    func delete(_ id: Period.ID) async throws
}
```

Purpose: manage festival periods (list with query, fetch single, create/update/delete).

---

## `RouteDataFetcherProtocol`

```swift
protocol RouteDataFetcherProtocol: DataFetcher {
    func fetchAll(districtID: District.ID, query: Query) async throws
    func fetch(routeID: Route.ID) async throws
    func update(_ route: Route, points: [Point]) async throws
    func create(districtID: District.ID, route: Route, points: [Point]) async throws
    func delete(_ routeID: Route.ID) async throws
}
```

Purpose: manage routes and their points for districts (list, detail, create/update/delete).

---

## `SceneDataFetcherProtocol`

```swift
protocol SceneDataFetcherProtocol: DataFetcher {
    func launchFestival(festivalId: Festival.ID) async throws
    func launchFestival(districtId: District.ID) async throws -> Festival.ID
    func launchDistrict(districtId: District.ID) async throws -> Route.ID?
}
```

Purpose: orchestrate launching of festival or district scenes — clears and syncs application-wide stores.

---

Notes:
- The protocols live in `iOSApp/Sources/Data/DataFetcher`.
- Each concrete fetcher uses `HTTPClient`, local stores, and the database to sync remote results locally.

If you want, I can also add brief method-by-method descriptions or link to the implementation files.
