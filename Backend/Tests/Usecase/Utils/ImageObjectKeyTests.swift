import Shared
import Testing
@testable import Backend

struct ImageObjectKeyTests {
    @Test("対象種別とvariantに応じたキーを生成する")
    func createsTargetSpecificKeys() throws {
        let key = try ImageObjectKey(target: .init(type: .district, id: "district-1", variant: .dark), festivalId: "festival-1")
        #expect(key.temporary == "temporary/festivals/festival-1/districts/district-1/dark.jpg")
        #expect(key.permanent == "festivals/festival-1/districts/district-1/dark.jpg")
    }

    @Test("ID内のパス区切りと日本語をエンコードする")
    func encodesPathSeparatorsAndUnicode() throws {
        let key = try ImageObjectKey(target: .init(type: .festival, id: "../祭", variant: .light))
        #expect(key.temporary == "temporary/festivals/%2E%2E%2F%E7%A5%AD/light.jpg")
    }

    @Test("未対応の組み合わせと空IDを拒否する")
    func rejectsInvalidCombinationsAndMissingIDs() {
        #expect(throws: Error.self) {
            try ImageObjectKey(target: .init(type: .store, id: "store", variant: .light))
        }
        #expect(throws: Error.self) {
            try ImageObjectKey(target: .init(type: .district, id: "district", variant: .light))
        }
        #expect(throws: Error.self) {
            try ImageObjectKey(target: .init(type: .festival, id: "", variant: .light))
        }
    }
}
