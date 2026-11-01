import Shared

/// S3 keys are derived from persisted IDs, never from a client-supplied path.
struct ImageObjectKey: Sendable, Equatable {
    let temporary: String
    let permanent: String

    init(target: ImageUploadTarget, festivalId: String? = nil) throws {
        let id = try Self.component(target.id)
        let base: String
        switch (target.type, target.variant) {
        case (.store, .banner), (.store, .interstitial):
            base = "stores/\(id)"
        case (.festival, .light), (.festival, .dark):
            base = "festivals/\(id)"
        case (.district, .light), (.district, .dark):
            guard let festivalId else { throw Error.badRequest("祭典IDが必要です。") }
            base = "festivals/\(try Self.component(festivalId))/districts/\(id)"
        default:
            throw Error.badRequest("画像の対象と種類が一致しません。")
        }
        let permanent = "\(base)/\(target.variant.rawValue).jpg"
        let temporary = "temporary/\(permanent)"
        guard temporary.utf8.count <= 1_024 else {
            throw Error.badRequest("画像のキーが長すぎます。")
        }
        self.permanent = permanent
        self.temporary = temporary
    }

    private static func component(_ value: String) throws -> String {
        guard !value.isEmpty else { throw Error.badRequest("IDが空です。") }
        let hex = Array("0123456789ABCDEF".utf8)
        var result: [UInt8] = []
        for byte in value.utf8 {
            if (65...90).contains(byte) || (97...122).contains(byte) ||
                (48...57).contains(byte) || byte == 45 || byte == 95 {
                result.append(byte)
            } else {
                result.append(contentsOf: [37, hex[Int(byte >> 4)], hex[Int(byte & 15)]])
            }
        }
        return String(decoding: result, as: UTF8.self)
    }
}
