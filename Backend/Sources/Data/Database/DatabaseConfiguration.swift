enum DatabaseConfiguration {
    static let tableName: String = {
        let variables = Environment.resolvedVariables()
        let databaseEnvironment = variables["DATABASE_ENVIRONMENT"]?.uppercased() ?? "DEV"

        let databaseNameVariable: String
        switch databaseEnvironment {
        case "PROD":
            databaseNameVariable = "DATABASE_NAME_PROD"
        case "DEV":
            databaseNameVariable = "DATABASE_NAME_DEV"
        default:
            fatalError("DATABASE_ENVIRONMENT は PROD または DEV を指定してください。")
        }

        guard let tableName = variables[databaseNameVariable], !tableName.isEmpty else {
            fatalError("環境変数 \(databaseNameVariable) を設定してください。")
        }
        return tableName
    }()
}
