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
    private let client: DynamoDBClient
    private let tableName: String
    private let encoder = DynamoDBEncoder()
    private let decoder = DynamoDBDecoder()
    
    init(region: String = "ap-northeast-1", tableName: String) throws {
        self.client = try DynamoDBClient(region: region)
        self.tableName = tableName
    }
    
    // MARK: put
    func put<T: Codable>(_ item: T) async throws {
        let attrs = try encoder.encode(item)
        let input = PutItemInput(item: attrs, tableName: tableName)
        let _ = try await client.putItem(input: input)
    }
    
    // MARK: get
    func get<T: Codable>(keys: [String: Codable], as type: T.Type) async throws -> T? {
        let key = try keys.toExpression()
        let input = GetItemInput(
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
    func scan<T: Codable>(_ type: T.Type) async throws -> [T] {
        let input = ScanInput(tableName: tableName)
        let output = try await client.scan(input: input)
        guard let items = output.items else { return [] }
        return try items.map { try decoder.decode($0, as: T.self) }
    }
    
    // MARK: query
    func query<T: Codable>(
        indexName: String? = nil,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition] = [],
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        
        precondition(!keyConditions.isEmpty, "KeyCondition must not be empty")
        
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
        let filterExspression = filterExprs.isEmpty ? nil : filterExprs.joined(separator: " AND ")
        
        var input = QueryInput(
            expressionAttributeNames: expressionNames,
            expressionAttributeValues: expressionValues,
            filterExpression: filterExspression,
            indexName: indexName,
            keyConditionExpression: keyConditionExpression,
            tableName: tableName
        )
        
        input.scanIndexForward = ascending
        input.limit = limit
        
        let output = try await client.query(input: input)
        guard let items = output.items else { return [] }
        
        return try items.map { try decoder.decode($0, as: T.self) }
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
