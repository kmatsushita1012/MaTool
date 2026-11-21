public struct EditionPack: Pack {
    public let edition: Edition
    public let periods: [Period]

    public init(edition: Edition, periods: [Period]) {
        self.edition = edition
        self.periods = periods
    }
}
