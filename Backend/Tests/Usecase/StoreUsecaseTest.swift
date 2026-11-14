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
        requestObject["createdAt"] = existing.createdAt.timeIntervalSince1970 + 1
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
        #expect(abs(responseStore.createdAt.timeIntervalSince(existing.createdAt)) < 0.000_001)
        let storedStore = try #require(await repository.snapshot())
        #expect(storedStore.id == responseStore.id)
        #expect(storedStore.address == nil)
        #expect(storedStore.coordinate == nil)
        #expect(storedStore.createdAt == existing.createdAt)
    }

    @Test("広告主以外のユーザーは店舗の取得と作成を実行できない")
    func nonAdvertisersCannotAccessStoreOperations() async {
        for user in [UserRole.guest, .district("district-1")] {
            do {
                _ = try await StoreUsecase().storesOwned(by: user)
                Issue.record("非広告主が所有店舗を取得できた")
            } catch {
                #expect((error as? Application.Error)?.localizedDescription == "広告主としてログインしてください。")
            }
        }
    }

    @Test("登録フォームの入力は前後空白を除去して保存し、広告主IDはログイン情報から決定する")
    func createsSanitizedStore() async throws {
        let repository = StoreRepositorySpy()
        let festival = Festival(
            id: "festival-1", name: "Festival", subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let created = try await withDependencies {
            $0[StoreRepositoryKey.self] = repository
            $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [:])
        } operation: {
            try await StoreUsecase().create(
                festivalId: festival.id,
                request: StoreCreateRequest(
                    name: "  Cafe  ", address: "  ", businessHours: "  9-17  ", description: "  "
                ),
                user: .advertiser("owner-1")
            )
        }

        #expect(created.name == "Cafe")
        #expect(created.ownerId == "owner-1")
        #expect(created.address == nil)
        #expect(created.description == nil)
        #expect(created.businessHours == "9-17")
        #expect(await repository.snapshot()?.id == created.id)
    }

    @Test("店舗名が空白だけの場合はRepoへ新規保存せず入力エラーを返す")
    func invalidStoreNameIsRejectedBeforePersisting() async {
        let repo = StoreRepositorySpy()
        do {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = repo
            } operation: {
                _ = try await StoreUsecase().create(
                    festivalId: "festival-1",
                    request: StoreCreateRequest(name: "  ", businessHours: ""),
                    user: .advertiser("owner-1")
                )
            }
            Issue.record("空の店舗名が保存された")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "店舗情報が不正です。")
        }
        #expect(await repo.snapshot() == nil)
    }

    @Test("広告主あたりの店舗数上限を超える新規作成を拒否する")
    func maximumStoreCountIsEnforced() async {
        let existing = Store(
            id: "store-existing",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(),
            name: "Existing",
            businessHours: ""
        )
        let repo = StoreRepositorySpy(store: existing)
        let festival = Festival(
            id: "festival-1", name: "Festival", subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        do {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = repo
                $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                    "ADVERTISEMENT_MAX_STORES_PER_OWNER": "1"
                ])
            } operation: {
                _ = try await StoreUsecase().create(
                    festivalId: "festival-1",
                    request: StoreCreateRequest(name: "New", businessHours: "10-18"),
                    user: .advertiser("owner-1")
                )
            }
            Issue.record("上限超過の店舗登録が許可された")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "登録できる店舗数の上限に達しています。")
        }
        #expect(await repo.snapshot()?.id == existing.id)
    }

    @Test("店舗更新URLと送信した店舗IDが異なる場合はデータを更新しない")
    func putRejectsMismatchedStoreID() async {
        let stored = Store(
            id: "store-1", festivalId: "festival-1", ownerId: "owner-1",
            purchaseAccountToken: UUID(), name: "Cafe", businessHours: ""
        )
        let repo = StoreRepositorySpy(store: stored)
        do {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = repo
            } operation: {
                _ = try await StoreUsecase().put(
                    id: "other-store", request: stored, user: .advertiser("owner-1")
                )
            }
            Issue.record("URLとデータの店舗ID不一致が受け入れられた")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "URLの店舗IDと送信データの店舗IDが一致しません。")
        }
        #expect(await repo.snapshot()?.id == stored.id)
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
