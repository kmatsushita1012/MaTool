import Foundation
import Testing
@testable import Shared

struct RouteDTOTests {
    @Test("履歴はEdition・Period・Routeの関係を保ってJSON往復できる")
    func roundTrip() throws {
        let edition = Edition(id: "edition", festivalId: "festival", year: 2025)
        let period = Period(id: "period", editionId: edition.id, festivalId: edition.festivalId, date: .init(year: 2026, month: 1, day: 1))
        let route = Route(id: "route", districtId: "district", periodId: period.id)
        let history = RouteHistoryResponse(editions: [.init(edition: edition, entries: [.init(period: period, route: route)])])
        let data = try JSONEncoder().encode(history)
        #expect(try JSONDecoder().decode(RouteHistoryResponse.self, from: data) == history)
    }
}
