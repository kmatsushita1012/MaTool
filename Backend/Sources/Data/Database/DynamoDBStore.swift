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
    func get<T: Codable, K: Codable>(key: K, keyName: String, as type: T.Type) async throws -> T? {
        let keyAttr = try encoder.encodeKey(key)
        let input = GetItemInput(
            key: [ keyName: keyAttr ],
            tableName: tableName
        )
        let output = try await client.getItem(input: input)
        guard let item = output.item else { return nil }
        return try decoder.decode(item, as: T.self)
    }
    
    // MARK: delete
    func delete<K: Codable>(key: K, keyName: String) async throws {
        let keyAttrs = try encoder.encode(["\(keyName)": key])
        let input = DeleteItemInput(key: keyAttrs, tableName: tableName)
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
        keyCondition: QueryCondition,
        filter: FilterCondition? = nil,
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        
        let (keyExpr, keyValues) = try keyCondition.toExpression()
        var expressionValues = keyValues
        var filterExpression: String? = nil
        
        if let filter = filter {
            let (filterExpr, filterValues) = try filter.toExpression()
            filterExpression = filterExpr
            expressionValues.merge(filterValues) { $1 }
        }
        
        // 名前プレースホルダ
        var expressionNames: [String: String] = [:]
        for key in expressionValues.keys {
            let name = key.replacingOccurrences(of: ":", with: "")
            expressionNames["#\(name)"] = name
        }
        
        var input = QueryInput(
            expressionAttributeNames: expressionNames,
            expressionAttributeValues: expressionValues,
            keyConditionExpression: keyExpr,
            tableName: tableName
        )
        input.indexName = indexName
        input.filterExpression = filterExpression
        input.limit = limit
        input.scanIndexForward = ascending
        
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
    func toExpression() throws -> (String, [String: AttributeValue]) {
        let encoder = DynamoDBEncoder()
        switch self {
        case .equals(let field, let value):
            return ("#\(field) = :\(field)", [":\(field)": try encoder.encodeKey(value)])
        case .beginsWith(let field, let prefix):
            return ("begins_with(#\(field), :\(field))", [":\(field)": try encoder.encodeKey(prefix)])
        case .between(let field, let lower, let upper):
            return ("#\(field) BETWEEN :lower AND :upper",
                    [":lower": try encoder.encodeKey(lower), ":upper": try encoder.encodeKey(upper)])
        }
    }
}

// MARK: - FilterCondition +
fileprivate extension FilterCondition {
    func toExpression() throws -> (String, [String: AttributeValue]) {
        let encoder = DynamoDBEncoder()
        switch self {
        case .equals(let field, let value):
            return ("#\(field) = :\(field)", [":\(field)": try encoder.encodeKey(value)])
        case .beginsWith(let field, let prefix):
            return ("begins_with(#\(field), :\(field))", [":\(field)": try encoder.encodeKey(prefix)])
        case .contains(let field, let substring):
            return ("contains(#\(field), :\(field))", [":\(field)": try encoder.encodeKey(substring)])
        }
    }
}
