import Dependencies
import Foundation
import Testing
@testable import iOSApp

struct LastMainScreenUseCaseTests {
    @Test("前回の主要画面を保存して読み込める")
    func savesAndLoadsMainScreen() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let client = UserDefaultsClient(
            string: { defaults.string(forKey: $0) },
            bool: { defaults.bool(forKey: $0) },
            data: { defaults.data(forKey: $0) },
            double: { defaults.double(forKey: $0) },
            integer: { defaults.integer(forKey: $0) },
            remove: { defaults.removeObject(forKey: $0) },
            setString: { defaults.set($0, forKey: $1) },
            setBool: { defaults.set($0, forKey: $1) },
            setData: { defaults.set($0, forKey: $1) },
            setDouble: { defaults.set($0, forKey: $1) },
            setInteger: { defaults.set($0, forKey: $1) }
        )

        withDependencies {
            $0.userDefaultsClient = client
        } operation: {
            let useCase = LastMainScreenUseCase()

            useCase.save(.admin)
            #expect(useCase.load() == .admin)

            useCase.save(.map)
            #expect(useCase.load() == .map)

            useCase.save(nil)
            #expect(useCase.load() == nil)
        }
    }

    @Test("未定義の値は画面記録なしとして扱う")
    func ignoresUnknownStoredValue() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("unknown", forKey: "lastMainScreen")
        let client = UserDefaultsClient(
            string: { defaults.string(forKey: $0) },
            bool: { defaults.bool(forKey: $0) },
            data: { defaults.data(forKey: $0) },
            double: { defaults.double(forKey: $0) },
            integer: { defaults.integer(forKey: $0) },
            remove: { defaults.removeObject(forKey: $0) },
            setString: { defaults.set($0, forKey: $1) },
            setBool: { defaults.set($0, forKey: $1) },
            setData: { defaults.set($0, forKey: $1) },
            setDouble: { defaults.set($0, forKey: $1) },
            setInteger: { defaults.set($0, forKey: $1) }
        )

        withDependencies {
            $0.userDefaultsClient = client
        } operation: {
            #expect(LastMainScreenUseCase().load() == nil)
        }
    }
}
