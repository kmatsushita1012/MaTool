import Foundation

public enum DependencyConfiguration {
    @inline(__always)
    public static func missing<Value>(_ name: String, as: Value.Type = Value.self) -> Value {
        fatalError("依存 (name) が InfrastructureResolver で構成されていません。")
    }
}
