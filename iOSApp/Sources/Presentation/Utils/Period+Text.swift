import Shared

extension Period {
    var text: String {
        String(
            format: "%d/%d %@ %02d:%02d〜%02d:%02d",
            date.month,
            date.day,
            title,
            start.hour,
            start.minute,
            end.hour,
            end.minute
        )
    }
    
    var shortText: String{
        String(
            format: "%d/%d %@",
            date.month,
            date.day,
            title,
        )
    }
    
    func text(dateFormat: String = "y/m/d") -> String {
        "\(date.text(format: dateFormat)) \(title)"
    }
    
    var path: String {
        "\(date.year)-\(date.month)-\(date.day)-\(title)"
    }
}
