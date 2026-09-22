import Shared

public extension Period {
    var mapMenuText: String {
        "\(date.text(format: "m/d（w）"))\(title)"
    }
}
