public struct EditManager<T: Equatable>: Equatable {
    public private(set) var value: T
    private var undoStack: [T] = []
    private var redoStack: [T] = []

    public init(_ initial: T) {
        self.value = initial
    }

    public mutating func apply(_ update: (inout T) -> Void) {
        undoStack.append(value)
        redoStack.removeAll()
        var newValue = value
        update(&newValue)
        value = newValue
    }

    public mutating func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(value)
        value = last
    }

    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(value)
        value = next
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
}
