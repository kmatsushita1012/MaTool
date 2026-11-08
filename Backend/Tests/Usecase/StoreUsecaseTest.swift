import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct StoreUsecaseTest {
    @Test("店舗作成 API は住所と座標のnullを受け入れ、所有店舗APIから読み戻せる")
    func createEndpointRoundTripsMissingLocation() async throws {
        let repository = StoreRepositorySpy()
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let festivalRepository = FestivalRepositorySpy(festivals: [festival])
        let requestBody = #"{"name":"Cafe","address":null,"coordinate":null,"businessHours":""}"#

        let (response, ownedStoresResponse) = await withDependencies {
            $0[StoreControllerKey.self] = StoreController()
            $0[StoreUsecaseKey.self] = StoreUsecase()
            $0[StoreRepositoryKey.self] = repository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [:])
        } operation: {
            let app = Application { StoreRouter() }
            var request = Application.Request.make(
                method: .post,
                path: "/festivals/festival-1/stores",
                body: requestBody
            )
            request.user = .advertiser("owner-1")
            let createdResponse = await app.handle(request)

            var ownedRequest = Application.Request.make(
                method: .get,
                path: "/advertisers/me/stores"
            )
            ownedRequest.user = .advertiser("owner-1")
            let ownedStoresResponse = await app.handle(ownedRequest)
            return (createdResponse, ownedStoresResponse)
        }

        #expect(response.statusCode == 200)
        let responseObject = try #require(JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [String: Any])
        #expect(responseObject["address"] is NSNull)
        #expect(responseObject["coordinate"] is NSNull)

        let responseStore = try decodeStoreResponse(response.body)
        #expect(responseStore.address == nil)
        #expect(responseStore.coordinate == nil)
        #expect(ownedStoresResponse.statusCode == 200)
        let ownedStores = try decodeStoresResponse(ownedStoresResponse.body)
        #expect(ownedStores.count == 1)
        #expect(ownedStores.first?.id == responseStore.id)
        #expect(ownedStores.first?.address == nil)
        #expect(ownedStores.first?.coordinate == nil)
        let storedStore = try #require(await repository.snapshot())
        #expect(storedStore.id == responseStore.id)
        #expect(storedStore.address == nil)
        #expect(storedStore.coordinate == nil)
    }

    @Test("店舗作成 API の通常エラーは Shared ErrorResponse 形式で返す")
    func createEndpointReturnsSharedErrorResponse() async throws {
        let repository = StoreRepositorySpy()
        let festivalRepository = FestivalRepositorySpy()
        let response = await withDependencies {
            $0[StoreControllerKey.self] = StoreController()
            $0[StoreUsecaseKey.self] = StoreUsecase()
            $0[StoreRepositoryKey.self] = repository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [:])
        } operation: {
            let app = Application { StoreRouter() }
            var request = Application.Request.make(
                method: .post,
                path: "/festivals/missing-festival/stores",
                body: #"{"name":"Cafe","address":null,"coordinate":null,"businessHours":""}"#
            )
            request.user = .advertiser("owner-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 404)
        #expect(response.headers["Content-Type"] == "application/json")
        let error = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))
        #expect(error.message == "指定された祭典が見つかりません。")
        #expect(error.localizedDescription == "指定された祭典が見つかりません。")
        #expect(await repository.snapshot() == nil)
    }

    @Test("店舗更新 API は欠落した住所・座標をnilとして保存して返す")
    func updateEndpointClearsMissingLocation() async throws {
        let existing = Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cafe",
            address: "Address",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            businessHours: ""
        )
        let repository = StoreRepositorySpy(store: existing)
        var requestObject = try #require(JSONSerialization.jsonObject(with: Data(existing.toString().utf8)) as? [String: Any])
        requestObject.removeValue(forKey: "address")
        requestObject.removeValue(forKey: "coordinate")
        let requestData = try JSONSerialization.data(withJSONObject: requestObject)
        let requestBody = try #require(String(data: requestData, encoding: .utf8))

        let response = await withDependencies {
            $0[StoreControllerKey.self] = StoreController()
            $0[StoreUsecaseKey.self] = StoreUsecase()
            $0[StoreRepositoryKey.self] = repository
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [:])
            $0[ImageStorageClientKey.self] = ImageStorageClientSpy()
        } operation: {
            let app = Application { StoreRouter() }
            var request = Application.Request.make(
                method: .put,
                path: "/stores/store-1",
                body: requestBody
            )
            request.user = .advertiser("owner-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        let responseObject = try #require(JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [String: Any])
        #expect(responseObject["address"] is NSNull)
        #expect(responseObject["coordinate"] is NSNull)

        let responseStore = try decodeStoreResponse(response.body)
        #expect(responseStore.address == nil)
        #expect(responseStore.coordinate == nil)
        let storedStore = try #require(await repository.snapshot())
        #expect(storedStore.id == responseStore.id)
        #expect(storedStore.address == nil)
        #expect(storedStore.coordinate == nil)
    }

    private func decodeStoreResponse(_ body: String) throws -> Store {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(Store.self, from: Data(body.utf8))
    }

    private func decodeStoresResponse(_ body: String) throws -> [Store] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode([Store].self, from: Data(body.utf8))
    }
}
