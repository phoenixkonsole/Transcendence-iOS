import Foundation
import UIKit

struct Rate {
    let code: String
    let name: String
    let rate: Double
    
    var currencySymbol: String {
        if let symbol = Rate.symbolMap[code] {
            return symbol
        } else {
            let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
            let identifier = Locale.identifier(fromComponents: components)
            return Locale(identifier: identifier).currencySymbol ?? code
        }
    }
    
    static var symbolMap: [String: String] = {
        var map = [String: String]()
        Locale.availableIdentifiers.forEach { identifier in
            let locale = Locale(identifier: identifier)
            guard let code = locale.currencyCode else { return }
            guard let symbol = locale.currencySymbol else { return }
            
            if let collision = map[code] {
                if collision.utf8.count > symbol.utf8.count {
                    map[code] = symbol
                }
            } else {
                map[code] = symbol
            }
        }
        return map
    }()
    
    var locale: Locale {
        let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
        let identifier = Locale.identifier(fromComponents: components)
        return Locale(identifier: identifier)
    }
    
    var localString: String {
        let format = NumberFormatter()
        format.numberStyle = .currency
        format.currencySymbol = currencySymbol
        return format.string(from: rate as NSNumber) ?? ""
    }
    
    static var empty: Rate {
        return Rate(code: "", name: "", rate: 0.0)
    }
}

extension Rate {
    init?(data: Any) {
        guard let dictionary = data as? [String: Any] else { return nil }
        guard let code = dictionary["code"] as? String else { return nil }
        guard let name = dictionary["name"] as? String else { return nil }
        guard let rate = dictionary["rate"] as? Double else { return nil }
        self.init(code: code, name: name, rate: rate)
    }
    
    init?(dictionary: Any, ratio: Double) {
        guard let dictionary = dictionary as? [String: Any] else { return nil }
        guard let code = dictionary["code"] as? String else { return nil }
        guard let name = dictionary["name"] as? String else { return nil }
        guard let rate = dictionary["rate"] as? Double else { return nil }
        self.init(code: code, name: name, rate: rate * ratio)
    }
    
    var dictionary: [String: Any] {
        return [
            "code": code,
            "name": name,
            "rate": rate        ]
    }
}

extension Rate : Equatable {}

func ==(lhs: Rate, rhs: Rate) -> Bool {
    return lhs.code == rhs.code && lhs.name == rhs.name && lhs.rate == rhs.rate
}
