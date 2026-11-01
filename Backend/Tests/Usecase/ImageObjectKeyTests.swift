import Shared
import Testing
@testable import Backend

struct ImageObjectKeyTests {
    @Test func createsTargetSpecificKeys() throws {
        let key = try ImageObjectKey(target: .init(type: .district, id: "district-1", variant: .dark), festivalId: "festival-1")
        #expect(key.temporary == "temporary/festivals/festival-1/districts/district-1/dark.jpg")
        #expect(key.permanent == "festivals/festival-1/districts/district-1/dark.jpg")
    }

    @Test func encodesPathSeparatorsAndUnicode() throws {
        let key = try ImageObjectKey(target: .init(type: .festival, id: "../祭", variant: .light))
        #expect(key.temporary == "temporary/festivals/%2E%2E%2F%E7%A5%AD/light.jpg")
    }

    @Test func rejectsInvalidCombinationsAndMissingIDs() {
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
