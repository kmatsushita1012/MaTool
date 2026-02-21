public extension Collection where Element: Identifiable {
    func first(matching id: Element.ID) -> Element? {
        first(where: \.id, equals: id)
    }
}
