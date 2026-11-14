import Foundation
@preconcurrency import AWSDynamoDB
import Shared
import Testing
@testable import Backend

struct DynamoDBStoreTests {
    @Test("putはレコード全属性とテーブル名をDynamoDBへ渡す")
    func putSerializesRecord() async throws {
        let calls = DynamoDBStoreCallRecorder()
        let record = fixtureRecord()
        let store = makeStore(calls: calls)

        try await store.put(record)

        let input = try #require(await calls.putInputs.first)
        #expect(input.tableName == "unit-table")
        #expect(input.item?["pk"] == .s("PK#district"))
        #expect(input.item?["sk"] == .s("SK#district"))
        #expect(input.item?["content"] != nil)
    }

    @Test("getは複合キーを転送し、データが見つからないとnilを返す")
    func getReturnsNilWhenMissing() async throws {
        let calls = DynamoDBStoreCallRecorder()
        let store = makeStore(calls: calls)

        let result = try await store.get(
            keys: ["pk": "PK#missing", "sk": "SK#missing"],
            as: Record<District>.self
        )

        #expect(result == nil)
        let input = try #require(await calls.getInputs.first)
        #expect(input.tableName == "unit-table")
        #expect(input.key?["pk"] == .s("PK#missing"))
        #expect(input.key?["sk"] == .s("SK#missing"))
    }

    @Test("getはDynamoDB属性からレコードを復元する")
    func getDecodesRecord() async throws {
        let original = fixtureRecord()
        let attrs = try DynamoDBEncoder().encode(original)
        let calls = DynamoDBStoreCallRecorder(getResult: .init(item: attrs))
        let store = makeStore(calls: calls)

        let restored = try await store.get(
            keys: ["pk": original.pk, "sk": original.sk],
            as: Record<District>.self
        )

        #expect(restored?.pk == original.pk)
        #expect(restored?.sk == original.sk)
        #expect(restored?.content.id == original.content.id)
    }

    @Test("deleteは削除対象の複合キーとテーブル名を転送する")
    func deleteTransmitsKeys() async throws {
        let calls = DynamoDBStoreCallRecorder()
        let store = makeStore(calls: calls)

        try await store.delete(keys: ["pk": "PK#district", "sk": "SK#district"])

        let input = try #require(await calls.deleteInputs.first)
        #expect(input.tableName == "unit-table")
        #expect(input.key?["pk"] == .s("PK#district"))
    }

    @Test("scanはLastEvaluatedKeyのある全ページを取り込み順序を保持する")
    func scanTraversesPages() async throws {
        let first = try DynamoDBEncoder().encode(fixtureRecord(id: "a"))
        let second = try DynamoDBEncoder().encode(fixtureRecord(id: "b"))
        let calls = DynamoDBStoreCallRecorder(scanResults: [
            .init(items: [first], lastEvaluatedKey: ["pk": .s("cursor")]),
            .init(items: [second], lastEvaluatedKey: [:])
        ])
        let store = makeStore(calls: calls)

        let rows = try await store.scan(Record<District>.self, ignoreDecodeError: false)

        #expect(rows.map(\.content.id) == ["a", "b"])
        let inputs = await calls.scanInputs
        #expect(inputs.count == 2)
        #expect(inputs[0].exclusiveStartKey == nil)
        #expect(inputs[1].exclusiveStartKey?["pk"] == .s("cursor"))
    }

    @Test("scanのignoreDecodeErrorは壊れた行だけ除外し、有効行を残す")
    func scanCanIgnoreCorruptedRows() async throws {
        let valid = try DynamoDBEncoder().encode(fixtureRecord())
        let calls = DynamoDBStoreCallRecorder(scanResults: [
            .init(items: [[:], valid])
        ])
        let store = makeStore(calls: calls)

        let rows = try await store.scan(Record<District>.self, ignoreDecodeError: true)

        #expect(rows.map(\.content.id) == ["district"])
        #expect(await calls.scanInputs.count == 1)
    }

    @Test("scanの厳格モードは復号エラーを握りつぶさない")
    func scanStrictModePropagatesDecodingError() async {
        let calls = DynamoDBStoreCallRecorder(scanResults: [.init(items: [[:]])])
        let store = makeStore(calls: calls)

        await #expect(throws: Error.self) {
            _ = try await store.scan(Record<District>.self, ignoreDecodeError: false)
        }
    }

    @Test("queryのlimit=0はDynamoDBへリクエストせず空配列を返す")
    func queryZeroLimitSkipsNetwork() async throws {
        let calls = DynamoDBStoreCallRecorder()
        let store = makeStore(calls: calls)

        let rows = try await store.query(
            keyConditions: [.equals("pk", "district")],
            limit: 0,
            as: Record<District>.self
        )

        #expect(rows.isEmpty)
        #expect(await calls.queryInputs.isEmpty)
    }

    @Test("queryは複数条件とフィルター、インデックス、降順、limitを転送する")
    func queryBuildsExpressionsAndHonorsLimit() async throws {
        let record = try DynamoDBEncoder().encode(fixtureRecord())
        let calls = DynamoDBStoreCallRecorder(queryResults: [
            .init(items: [record], lastEvaluatedKey: ["pk": .s("cursor")])
        ])
        let store = makeStore(calls: calls)

        let rows = try await store.query(
            indexName: "index-one",
            keyConditions: [.equals("pk", "district"), .beginsWith("sk", "SK#")],
            filterConditions: [.contains("name", "祭")],
            limit: 1,
            ascending: false,
            as: Record<District>.self
        )

        #expect(rows.count == 1)
        let input = try #require(await calls.queryInputs.first)
        #expect(input.indexName == "index-one")
        #expect(input.keyConditionExpression?.contains("#pk = :pk") == true)
        #expect(input.keyConditionExpression?.contains("begins_with(#sk, :sk)") == true)
        #expect(input.filterExpression?.contains("contains(#name, :name)") == true)
        #expect(input.scanIndexForward == false)
        #expect(input.limit == 1)
        #expect(input.expressionAttributeValues?[":pk"] == .s("district"))
        #expect(await calls.queryInputs.count == 1)
    }

    @Test("queryの複数ページはlimitまで取得し、カーソルと残り件数を更新する")
    func queryPaginatesUntilLimit() async throws {
        let first = try DynamoDBEncoder().encode(fixtureRecord(id: "a"))
        let second = try DynamoDBEncoder().encode(fixtureRecord(id: "b"))
        let calls = DynamoDBStoreCallRecorder(queryResults: [
            .init(items: [first], lastEvaluatedKey: ["pk": .s("cursor")]),
            .init(items: [second], lastEvaluatedKey: nil)
        ])
        let store = makeStore(calls: calls)

        let rows = try await store.query(
            keyConditions: [.between("sk", "a", "z")],
            filterConditions: [.equals("status", true), .beginsWith("name", "a")],
            limit: 3,
            as: Record<District>.self
        )

        #expect(rows.map(\.content.id) == ["a", "b"])
        let inputs = await calls.queryInputs
        #expect(inputs.count == 2)
        #expect(inputs[0].limit == 3)
        #expect(inputs[1].limit == 2)
        #expect(inputs[1].exclusiveStartKey?["pk"] == .s("cursor"))
        #expect(inputs[0].keyConditionExpression?.contains("BETWEEN") == true)
        #expect(inputs[0].filterExpression?.contains("begins_with") == true)
    }

    private func fixtureRecord(id: String = "district") -> Record<District> {
        Record(pk: "PK#district", sk: "SK#district", content: District(
            id: id, name: id, festivalId: "festival"
        ))
    }

    private func makeStore(calls: DynamoDBStoreCallRecorder) -> DynamoDBStore {
        DynamoDBStore(tableName: "unit-table", service: .init(
            put: { input in await calls.recordPut(input); return .init() },
            get: { input in await calls.recordGet(input) },
            delete: { input in await calls.recordDelete(input); return .init() },
            scan: { input in await calls.recordScan(input) },
            query: { input in await calls.recordQuery(input) }
        ))
    }
}

private actor DynamoDBStoreCallRecorder {
    private(set) var putInputs: [PutItemInput] = []
    private(set) var getInputs: [GetItemInput] = []
    private(set) var deleteInputs: [DeleteItemInput] = []
    private(set) var scanInputs: [ScanInput] = []
    private(set) var queryInputs: [QueryInput] = []

    private var getResult: GetItemOutput
    private var scanResults: [ScanOutput]
    private var queryResults: [QueryOutput]

    init(
        getResult: GetItemOutput = .init(),
        scanResults: [ScanOutput] = [.init()],
        queryResults: [QueryOutput] = [.init()]
    ) {
        self.getResult = getResult
        self.scanResults = scanResults
        self.queryResults = queryResults
    }

    func recordPut(_ input: PutItemInput) { putInputs.append(input) }
    func recordDelete(_ input: DeleteItemInput) { deleteInputs.append(input) }

    func recordGet(_ input: GetItemInput) -> GetItemOutput {
        getInputs.append(input)
        return getResult
    }

    func recordScan(_ input: ScanInput) -> ScanOutput {
        scanInputs.append(input)
        return scanResults.removeFirst()
    }

    func recordQuery(_ input: QueryInput) -> QueryOutput {
        queryInputs.append(input)
        return queryResults.removeFirst()
    }
}
