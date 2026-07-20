extension Result {
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }

    func asyncFlatMap<T>(_ transform: @escaping (Success) async -> Result<T, Failure>) async -> Result<T, Failure> {
        switch self {
        case .success(let value):
            return await transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension Result {
    func mapVoid() -> VoidResult<Failure> {
        self.map { _ in .init() }
    }
}
