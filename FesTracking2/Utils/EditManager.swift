struct EditManager<T: Equatable>: Equatable {
    private(set) var value: T
    private var undoStack: [T] = []
    private var redoStack: [T] = []

    init(_ initial: T) {
        self.value = initial
    }

    mutating func apply(_ update: (inout T) -> Void) {
        undoStack.append(value)
        redoStack.removeAll()
        var newValue = value
        update(&newValue)
        value = newValue
    }

    mutating func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(value)
        value = last
    }

    mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(value)
        value = next
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}
