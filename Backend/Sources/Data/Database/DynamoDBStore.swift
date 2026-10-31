//
//  DynamoDBStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/13.
//

@preconcurrency import AWSDynamoDB
import Shared

fileprivate typealias AttributeValue = DynamoDBClientTypes.AttributeValue

// MARK: - DynamoDBStore
struct DynamoDBStore: DataStore {
    private static let defaultRegion = "ap-northeast-1"
    private static let sharedClient: DynamoDBClient = {
        do {
            return try DynamoDBClient(region: defaultRegion)
        } catch {
            fatalError("DynamoDBClient could not be initialized: \(error)")
        }
    }()

    private let client: DynamoDBClient
    private let tableName: String
    private let encoder = DynamoDBEncoder()
    private let decoder = DynamoDBDecoder()
    
    init(region: String = Self.defaultRegion, tableName: String) throws {
        self.client = region == Self.defaultRegion
            ? Self.sharedClient
            : try DynamoDBClient(region: region)
        self.tableName = tableName
    }
    
    // MARK: put
    func put<R: RecordProtocol>(_ record: R) async throws {
        let attrs = try encoder.encode(record)
        let input = PutItemInput(item: attrs, tableName: tableName)
        let _ = try await client.putItem(input: input)
    }

    func transactRoute(_ record: RouteRecord, replacing oldRoute: Route?) async throws {
        let route = record.content
        let newUniqueRecord = RouteUniqueRecord(route)
        var items = [
            DynamoDBClientTypes.TransactWriteItem(
                put: DynamoDBClientTypes.Put(
                    conditionExpression: "attribute_not_exists(pk) OR #route_id = :route_id",
                    expressionAttributeNames: ["#route_id": "route_id"],
                    expressionAttributeValues: [":route_id": AttributeValue.s(route.id)],
                    item: try encoder.encode(newUniqueRecord),
                    tableName: tableName
                )
            )
        ]

        let newRouteKeys = RouteRecord.makeKeys(route.id, districtId: route.districtId)
        let sameRouteKey = oldRoute.map {
            RouteRecord.makeKeys($0.id, districtId: $0.districtId).pk == newRouteKeys.pk
                && RouteRecord.makeKeys($0.id, districtId: $0.districtId).sk == newRouteKeys.sk
        } ?? false
        let routeWriteCondition: (String?, [String: String]?, [String: AttributeValue]?)
        if let oldRoute, sameRouteKey {
            let condition = routeContentCondition(oldRoute)
            routeWriteCondition = (condition.expression, condition.names, condition.values)
        } else {
            routeWriteCondition = ("attribute_not_exists(pk)", nil, nil)
        }

        items.append(
            DynamoDBClientTypes.TransactWriteItem(
                put: DynamoDBClientTypes.Put(
                    conditionExpression: routeWriteCondition.0,
                    expressionAttributeNames: routeWriteCondition.1,
                    expressionAttributeValues: routeWriteCondition.2,
                    item: try encoder.encode(record),
                    tableName: tableName
                )
            )
        )

        if let oldRoute {
            let oldKeys = RouteRecord.makeKeys(oldRoute.id, districtId: oldRoute.districtId)
            if oldKeys.pk != newRouteKeys.pk || oldKeys.sk != newRouteKeys.sk {
                let condition = routeContentCondition(oldRoute)
                items.append(
                    DynamoDBClientTypes.TransactWriteItem(
                        delete: DynamoDBClientTypes.Delete(
                            conditionExpression: condition.expression,
                            expressionAttributeNames: condition.names,
                            expressionAttributeValues: condition.values,
                            key: try ["pk": encoder.encodeKey(oldKeys.pk), "sk": encoder.encodeKey(oldKeys.sk)],
                            tableName: tableName
                        )
                    )
                )
            }

            let oldUniqueRecord = RouteUniqueRecord(oldRoute)
            if oldUniqueRecord.pk != newUniqueRecord.pk || oldUniqueRecord.sk != newUniqueRecord.sk {
                let storedMarker = try await getConsistent(
                    pk: oldUniqueRecord.pk,
                    sk: oldUniqueRecord.sk,
                    as: RouteUniqueRecord.self
                )
                if storedMarker == nil || storedMarker?.routeId == oldRoute.id {
                    items.append(try uniqueDelete(oldUniqueRecord))
                }
            }
        }

        try await transactWrite(items)
    }

    func transactDeleteRoute(_ route: Route) async throws {
        let keys = RouteRecord.makeKeys(route.id, districtId: route.districtId)
        let condition = routeContentCondition(route)
        var items = [
            DynamoDBClientTypes.TransactWriteItem(
                delete: DynamoDBClientTypes.Delete(
                    conditionExpression: condition.expression,
                    expressionAttributeNames: condition.names,
                    expressionAttributeValues: condition.values,
                    key: try ["pk": encoder.encodeKey(keys.pk), "sk": encoder.encodeKey(keys.sk)],
                    tableName: tableName
                )
            )
        ]
        let uniqueRecord = RouteUniqueRecord(route)
        let storedMarker = try await getConsistent(pk: uniqueRecord.pk, sk: uniqueRecord.sk, as: RouteUniqueRecord.self)
        if storedMarker == nil || storedMarker?.routeId == route.id {
            items.append(try uniqueDelete(uniqueRecord))
        }
        try await transactWrite(items)
    }

    private func uniqueDelete(_ record: RouteUniqueRecord) throws -> DynamoDBClientTypes.TransactWriteItem {
        DynamoDBClientTypes.TransactWriteItem(
            delete: DynamoDBClientTypes.Delete(
                conditionExpression: "attribute_not_exists(#route_id) OR #route_id = :route_id",
                expressionAttributeNames: ["#route_id": "route_id"],
                expressionAttributeValues: [":route_id": AttributeValue.s(record.routeId)],
                key: try ["pk": encoder.encodeKey(record.pk), "sk": encoder.encodeKey(record.sk)],
                tableName: tableName
            )
        )
    }

    private func routeContentCondition(_ route: Route) -> (
        expression: String,
        names: [String: String],
        values: [String: AttributeValue]
    ) {
        (
            "attribute_exists(pk) AND #content.#district_id = :district_id AND #content.#period_id = :period_id",
            ["#content": "content", "#district_id": "district_id", "#period_id": "period_id"],
            [":district_id": .s(route.districtId), ":period_id": .s(route.periodId)]
        )
    }

    private func transactWrite(_ items: [DynamoDBClientTypes.TransactWriteItem]) async throws {
        do {
            _ = try await client.transactWriteItems(input: .init(transactItems: items))
        } catch let error as TransactionCanceledException {
            let conflictCodes: Set<String> = ["ConditionalCheckFailed", "TransactionConflict"]
            if error.properties.cancellationReasons?.contains(where: { conflictCodes.contains($0.code ?? "") }) == true {
                throw Error.conflict("この地区・日程には既にルートが登録されているか、更新対象が変更されています。")
            }
            throw error
        }
    }
    
    // MARK: get
    func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T? {
        let key = try keys.toExpression()
        let input = GetItemInput(
            key: key,
            tableName: tableName
        )
        
        let output = try await client.getItem(input: input)
        guard let item = output.item else { return nil }
        return try decoder.decode(item, as: T.self)
    }

    func getConsistent<T: RecordProtocol>(pk: String, sk: String, as type: T.Type) async throws -> T? {
        let key = try ["pk": encoder.encodeKey(pk), "sk": encoder.encodeKey(sk)]
        let input = GetItemInput(consistentRead: true, key: key, tableName: tableName)
        let output = try await client.getItem(input: input)
        guard let item = output.item else { return nil }
        return try decoder.decode(item, as: T.self)
    }
    
    // MARK: delete
    func delete(keys: [String: Codable]) async throws {
        let key = try keys.toExpression()
        let input = DeleteItemInput(key: key, tableName: tableName)
        let _ = try await client.deleteItem(input: input)
    }
    
    // MARK: scan
    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T] {
        var records: [T] = []
        var exclusiveStartKey: [String: AttributeValue]?

        repeat {
            let input = ScanInput(
                exclusiveStartKey: exclusiveStartKey,
                tableName: tableName
            )
            let output = try await client.scan(input: input)
            let items = output.items ?? []

            if ignoreDecodeError {
                records.append(contentsOf: items.compactMap { try? decoder.decode($0, as: T.self) })
            } else {
                records.append(contentsOf: try items.map { try decoder.decode($0, as: T.self) })
            }

            exclusiveStartKey = output.lastEvaluatedKey
        } while !(exclusiveStartKey?.isEmpty ?? true)

        return records
    }
    
    // MARK: query
    func query<T: RecordProtocol>(
        indexName: String? = nil,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition] = [],
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        try await queryRows(
            indexName: indexName,
            keyConditions: keyConditions,
            filterConditions: filterConditions,
            limit: limit,
            ascending: ascending,
            consistentRead: false,
            as: type
        )
    }

    func queryConsistent<T: RecordProtocol>(
        queryConditions: [QueryCondition],
        as type: T.Type
    ) async throws -> [T] {
        try await queryRows(
            keyConditions: queryConditions,
            consistentRead: true,
            as: type
        )
    }

    private func queryRows<T: RecordProtocol>(
        indexName: String? = nil,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition] = [],
        limit: Int? = nil,
        ascending: Bool = true,
        consistentRead: Bool,
        as type: T.Type
    ) async throws -> [T] {
        
        precondition(!keyConditions.isEmpty, "KeyCondition must not be empty")
        guard limit != 0 else { return [] }
        
        var keyExprs: [String] = []
        var filterExprs: [String] = []
        
        var expressionNames: [String: String] = [:]
        var expressionValues: [String: AttributeValue] = [:]
        
        // KeyConditionExpression
        for condition in keyConditions {
            let (expr, names, values) = try condition.toExpression()
            keyExprs.append(expr)
            expressionNames.merge(names) { $1 }
            expressionValues.merge(values) { $1 }
        }
        
        let keyConditionExpression = keyExprs.joined(separator: " AND ")
        
        // FilterExpression
        if !filterConditions.isEmpty {
            for filter in filterConditions {
                let (expr, names, values) = try filter.toExpression()
                filterExprs.append(expr)
                expressionNames.merge(names) { $1 }
                expressionValues.merge(values) { $1 }
            }
        }
        let filterExpression = filterExprs.isEmpty ? nil : filterExprs.joined(separator: " AND ")
        var records: [T] = []
        var exclusiveStartKey: [String: AttributeValue]?

        repeat {
            var input = QueryInput(
                consistentRead: consistentRead,
                exclusiveStartKey: exclusiveStartKey,
                expressionAttributeNames: expressionNames,
                expressionAttributeValues: expressionValues,
                filterExpression: filterExpression,
                indexName: indexName,
                keyConditionExpression: keyConditionExpression,
                tableName: tableName
            )

            input.scanIndexForward = ascending
            if let limit {
                input.limit = limit - records.count
            }

            let output = try await client.query(input: input)
            records.append(contentsOf: try (output.items ?? []).map { try decoder.decode($0, as: T.self) })

            if let limit, records.count >= limit {
                return Array(records.prefix(limit))
            }

            exclusiveStartKey = output.lastEvaluatedKey
        } while !(exclusiveStartKey?.isEmpty ?? true)

        return records
    }

    static func make(tableName: String) -> DynamoDBStore {
        guard let store = try? DynamoDBStore(tableName: tableName) else {
            fatalError("DynamoDBStore could not be initialized.")
        }
        return store
    }
}


// MARK: - QueryCondition +
fileprivate extension QueryCondition {
    func toExpression() throws -> (
        expr: String,
        names: [String: String],
        values: [String: AttributeValue]
    ) {
        let encoder = DynamoDBEncoder()
        
        switch self {
        case .equals(let field, let value):
            return (
                "#\(field) = :\(field)",
                ["#\(field)": field],
                [":\(field)": try encoder.encodeKey(value)]
            )
            
        case .beginsWith(let field, let prefix):
            return (
                "begins_with(#\(field), :\(field))",
                ["#\(field)": field],
                [":\(field)": try encoder.encodeKey(prefix)]
            )
            
        case .between(let field, let lower, let upper):
            return (
                "#\(field) BETWEEN :\(field)_l AND :\(field)_u",
                ["#\(field)": field],
                [
                    ":\(field)_l": try encoder.encodeKey(lower),
                    ":\(field)_u": try encoder.encodeKey(upper)
                ]
            )
        }
    }
}

// MARK: - FilterCondition +
fileprivate extension FilterCondition {
    func toExpression() throws -> (
        expr: String,
        names: [String: String],
        values: [String: AttributeValue]
    ) {
        let encoder = DynamoDBEncoder()
        
        switch self {
        case .equals(let field, let value):
            return (
                "#\(field) = :\(field)",
                ["#\(field)": field],
                [":\(field)": try encoder.encodeKey(value)]
            )
            
        case .beginsWith(let field, let prefix):
            return (
                "begins_with(#\(field), :\(field))",
                ["#\(field)": field],
                [":\(field)": try encoder.encodeKey(prefix)]
            )
            
        case .contains(let field, let substring):
            return (
                "contains(#\(field), :\(field))",
                ["#\(field)": field],
                [":\(field)": try encoder.encodeKey(substring)]
            )
        }
    }
}
fileprivate extension Dictionary where Key == String, Value == Codable {
    func toExpression() throws -> [String: AttributeValue] {
        let encoder = DynamoDBEncoder()
        var keyDict: [String: DynamoDBClientTypes.AttributeValue] = [:]
        for (key, value) in self {
            let encoded = try encoder.encodeKey(value)
            keyDict[key] = encoded
        }
        
        return keyDict
    }
}
