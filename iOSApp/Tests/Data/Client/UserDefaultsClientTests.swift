import Foundation
import Testing
@testable import iOSApp

struct UserDefaultsClientTests {
    @Test("文字列・真偽値・数値・データの保存と削除が独立して動く")
    func liveClientPersistsAndRemovesAllPrimitiveTypes() async {
        let client = UserDefaultsClient.liveValue
        let prefix = "MaToolUnitTest-" + UUID().uuidString
        let stringKey = prefix + "-string"
        let boolKey = prefix + "-bool"
        let dataKey = prefix + "-data"
        let doubleKey = prefix + "-double"
        let integerKey = prefix + "-integer"
        let data = Data([0x00, 0xEF, 0xFA])

        client.setString("掛川祭", stringKey)
        client.setBool(true, boolKey)
        client.setData(data, dataKey)
        client.setDouble(3.14159, doubleKey)
        client.setInteger(-12, integerKey)

        #expect(client.string(stringKey) == "掛川祭")
        #expect(client.bool(boolKey))
        #expect(client.data(dataKey) == data)
        #expect(client.double(doubleKey) == 3.14159)
        #expect(client.integer(integerKey) == -12)

        await client.remove(stringKey)
        await client.remove(boolKey)
        await client.remove(dataKey)
        await client.remove(doubleKey)
        await client.remove(integerKey)

        #expect(client.string(stringKey) == nil)
        #expect(!client.bool(boolKey))
        #expect(client.data(dataKey) == nil)
        #expect(client.double(doubleKey) == 0)
        #expect(client.integer(integerKey) == 0)
    }

    @Test("Optionalでnilを保存した場合はデータを削除する")
    func nilClearsStoredValues() async {
        let client = UserDefaultsClient.liveValue
        let prefix = "MaToolUnitTest-" + UUID().uuidString
        let k1 = prefix + "-string"
        let k2 = prefix + "-data"

        client.setString("before", k1)
        client.setData(Data([1, 2]), k2)
        #expect(client.string(k1) == "before")
        #expect(client.data(k2) == Data([1, 2]))

        client.setString(nil, k1)
        client.setData(nil, k2)

        #expect(client.string(k1) == nil)
        #expect(client.data(k2) == nil)

        await client.remove(k1)
        await client.remove(k2)
    }

    @Test("UserDefaultsManagerは専用Suiteへ各選択項目と許可フラグを保存する")
    func managerPersistsAllSelectionsInAnIsolatedSuite() {
        let suiteName = "MaToolUnitTest-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = UserDefaltsManager(defaults: defaults)

        #expect(manager.defaultFestivalId == nil)
        #expect(manager.defaultDistrictId == nil)
        #expect(!manager.hasRequestedAlwaysLocationPermission)

        manager.saveDefaultFestivalId("festival-1")
        manager.saveDefaultDistrictId("district-1")
        manager.saveHasRequestedAlwaysLocationPermission(true)

        #expect(manager.defaultFestivalId == "festival-1")
        #expect(manager.defaultDistrictId == "district-1")
        #expect(manager.hasRequestedAlwaysLocationPermission)

        let reloaded = UserDefaltsManager(defaults: defaults)
        #expect(reloaded.defaultFestivalId == "festival-1")
        #expect(reloaded.defaultDistrictId == "district-1")
        #expect(reloaded.hasRequestedAlwaysLocationPermission)

        manager.saveDefaultFestivalId(nil)
        manager.saveDefaultDistrictId(nil)
        manager.saveHasRequestedAlwaysLocationPermission(false)
        #expect(reloaded.defaultFestivalId == nil)
        #expect(reloaded.defaultDistrictId == nil)
        #expect(!reloaded.hasRequestedAlwaysLocationPermission)
    }

    @Test("Managerで扱うキーは既存の保存形式を維持する")
    func managerKeepsExistingStorageKeys() {
        #expect(UserDefaltsManager.Key.defaultFestivalId.rawValue == "region")
        #expect(UserDefaltsManager.Key.defaultDistrictId.rawValue == "district")
        #expect(UserDefaltsManager.Key.hasRequestedAlwaysLocationPermission.rawValue ==
                "hasRequestedAlwaysLocationPermission")
    }
}
