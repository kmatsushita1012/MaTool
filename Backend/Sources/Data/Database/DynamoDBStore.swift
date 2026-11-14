//
//  DynamoDBStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/13.
//

@preconcurrency import AWSDynamoDB

fileprivate typealias AttributeValue = DynamoDBClientTypes.AttributeValue


/// Separates DynamoDB's transport from encoding, pagination and query semantics.
struct DynamoDBService: Sendable {
    let put: @Sendable (PutItemInput) async throws -> PutItemOutput
    let get: @Sendable (GetItemInput) async throws -> GetItemOutput
    let delete: @Sendable (DeleteItemInput) async throws -> DeleteItemOutput
    let scan: @Sendable (ScanInput) async throws -> ScanOutput
    let query: @Sendable (QueryInput) async throws -> QueryOutput

    init(
        put: @escaping @Sendable (PutItemInput) async throws -> PutItemOutput,
        get: @escaping @Sendable (GetItemInput) async throws -> GetItemOutput,
        delete: @escaping @Sendable (DeleteItemInput) async throws -> DeleteItemOutput,
        scan: @escaping @Sendable (ScanInput) async throws -> ScanOutput,
        query: @escaping @Sendable (QueryInput) async throws -> QueryOutput
    ) {
        self.put = put
        self.get = get
        self.delete = delete
        self.scan = scan
        self.query = query
    }

    init(client: DynamoDBClient) {
        self.init(
            put: { try await client.putItem(input: $0) },
            get: { try await client.getItem(input: $0) },
            delete: { try await client.deleteItem(input: $0) },
            scan: { try await client.scan(input: $0) },
            query: { try await client.query(input: $0) }
        )
    }
}


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

    private let service: DynamoDBService
    private let tableName: String
    private let encoder = DynamoDBEncoder()
    private let decoder = DynamoDBDecoder()

    init(region: String = Self.defaultRegion, tableName: String) throws {
        let client: DynamoDBClient
        if region == Self.defaultRegion {
            client = Self.sharedClient
        } else {
            client = try DynamoDBClient(region: region)
        }
        self.init(tableName: tableName, service: DynamoDBService(client: client))
    }

    /// Unit tests can inject deterministic responses without contacting AWS.
    init(tableName: String, service: DynamoDBService) {
        self.service = service
        self.tableName = tableName
    }
    
    // MARK: put
    func put<R: RecordProtocol>(_ record: R) async throws {
        let attrs = try encoder.encode(record)
        let input = PutItemInput(item: attrs, tableName: tableName)
        let _ = try await service.put(input)
    }

    // MARK: get
    func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T? {
        let key = try keys.toExpression()
        let input = GetItemInput(key: key, tableName: tableName)
        
        let output = try await service.get(input)
        guard let item = output.item else { return nil }
        return try decoder.decode(item, as: T.self)
    }
    
    // MARK: delete
    func delete(keys: [String: Codable]) async throws {
        let key = try keys.toExpression()
        let input = DeleteItemInput(key: key, tableName: tableName)
        let _ = try await service.delete(input)
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
            let output = try await service.scan(input)
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
            if let limit {
                input.limit = limit - records.count
            }

            let output = try await service.query(input)
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
