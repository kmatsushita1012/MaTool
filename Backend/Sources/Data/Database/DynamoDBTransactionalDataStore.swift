import AWSDynamoDB

typealias DynamoDBAttribute = DynamoDBClientTypes.AttributeValue

enum DynamoDBTransactionOperation: Sendable {
    case put(
        item: [String: DynamoDBAttribute],
        conditionExpression: String?,
        expressionAttributeNames: [String: String],
        expressionAttributeValues: [String: DynamoDBAttribute]
    )
    case update(
        keys: [String: DynamoDBAttribute],
        updateExpression: String,
        conditionExpression: String?,
        expressionAttributeNames: [String: String],
        expressionAttributeValues: [String: DynamoDBAttribute]
    )
}

protocol DynamoDBTransactionalDataStore: DataStore {
    func updateItem(
        keys: [String: DynamoDBAttribute],
        updateExpression: String,
        conditionExpression: String?,
        expressionAttributeNames: [String: String],
        expressionAttributeValues: [String: DynamoDBAttribute],
        returnAllNew: Bool
    ) async throws -> [String: DynamoDBAttribute]?

    func transactWrite(_ operations: [DynamoDBTransactionOperation]) async throws
}
