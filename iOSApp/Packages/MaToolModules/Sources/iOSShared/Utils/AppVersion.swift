import Foundation

public enum AppVersion {
    public static var current: String {
        #if DEBUG
        "9.9.9"
        #else
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        #endif
    }
}
