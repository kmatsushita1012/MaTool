//
//  DynamoDBStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/13.
//

@preconcurrency import AWSDynamoDB

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
    
    // MARK: get
    func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T? {
        try await get(keys: keys, consistentRead: false, as: type)
    }

    func get<T: RecordProtocol>(keys: [String: Codable], consistentRead: Bool, as type: T.Type) async throws -> T? {
        let key = try keys.toExpression()
        let input = GetItemInput(
            consistentRead: consistentRead,
            key: key,
            tableName: tableName
        )
        
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
        try await query(
            indexName: indexName,
            keyConditions: keyConditions,
            filterConditions: filterConditions,
            limit: limit,
            ascending: ascending,
            consistentRead: false,
            as: type
        )
    }

    func query<T: RecordProtocol>(
        indexName: String? = nil,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition] = [],
        limit: Int? = nil,
        ascending: Bool = true,
        consistentRead: Bool,
        as type: T.Type
    ) async throws -> [T] {
        guard indexName == nil || !consistentRead else {
            throw Error.internalServerError("GSI Query では ConsistentRead を利用できません。")
        }
        
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
                exclusiveStartKey: exclusiveStartKey,
                expressionAttributeNames: expressionNames,
                expressionAttributeValues: expressionValues,
                filterExpression: filterExpression,
                indexName: indexName,
                keyConditionExpression: keyConditionExpression,
                tableName: tableName
            )

            input.scanIndexForward = ascending
            input.consistentRead = consistentRead
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

    func updateItem(
        keys: [String: DynamoDBAttribute],
        updateExpression: String,
        conditionExpression: String?,
        expressionAttributeNames: [String: String],
        expressionAttributeValues: [String: DynamoDBAttribute],
        returnAllNew: Bool
    ) async throws -> [String: DynamoDBAttribute]? {
        let input = UpdateItemInput(
            conditionExpression: conditionExpression,
            expressionAttributeNames: expressionAttributeNames,
            expressionAttributeValues: expressionAttributeValues,
            key: keys,
            returnValues: returnAllNew ? .allNew : DynamoDBClientTypes.ReturnValue.none,
            tableName: tableName,
            updateExpression: updateExpression
        )
        return try await client.updateItem(input: input).attributes
    }

    func transactWrite(_ operations: [DynamoDBTransactionOperation]) async throws {
        let items = operations.map { operation -> DynamoDBClientTypes.TransactWriteItem in
            switch operation {
            case let .put(item, condition, names, values):
                var transactionItem = DynamoDBClientTypes.TransactWriteItem()
                transactionItem.put = .init(
                    conditionExpression: condition,
                    expressionAttributeNames: names.isEmpty ? nil : names,
                    expressionAttributeValues: values.isEmpty ? nil : values,
                    item: item,
                    tableName: tableName
                )
                return transactionItem
            case let .update(keys, updateExpression, condition, names, values):
                var transactionItem = DynamoDBClientTypes.TransactWriteItem()
                transactionItem.update = .init(
                    conditionExpression: condition,
                    expressionAttributeNames: names.isEmpty ? nil : names,
                    expressionAttributeValues: values.isEmpty ? nil : values,
                    key: keys,
                    tableName: tableName,
                    updateExpression: updateExpression
                )
                return transactionItem
            }
        }
        _ = try await client.transactWriteItems(input: .init(transactItems: items))
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
