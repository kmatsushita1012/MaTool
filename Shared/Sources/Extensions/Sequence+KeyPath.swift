public extension Sequence {
    func first<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Element? {
        first { $0[keyPath: keyPath] == value }
    }

    func filter<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> [Element] {
        filter { $0[keyPath: keyPath] == value }
    }

    func contains<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Bool {
        contains { $0[keyPath: keyPath] == value }
    }

    func map<Value>(keyPath: KeyPath<Element, Value>) -> [Value] {
        map { $0[keyPath: keyPath] }
    }
}
