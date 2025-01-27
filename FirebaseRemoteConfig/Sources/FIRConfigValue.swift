import Foundation

class FIRRemoteConfigValue {
    private var _data: Data
    private var _source: FIRRemoteConfigSource

    init(data: Data?, source: FIRRemoteConfigSource) {
        _data = data ?? Data()
        _source = source
    }

    var stringValue: String {
        return String(data: _data, encoding: .utf8) ?? ""
    }

    var numberValue: NSNumber {
        return NSNumber(value: Double(stringValue) ?? 0)
    }

    var dataValue: Data {
        return _data
    }

    var boolValue: Bool {
        return self.stringValue.boolValue
    }

    func JSONValue() -> Any {
        if let data = dataValue {
            do {
                return try JSONSerialization.jsonObject(data)
            }
            catch let error {
                print(error)
            }
            
        }
        return nil
    }

    func debugDescription() -> String {
        let content = String(format: "Boolean: %@, String: %@, Number: %@, JSON:%@, Data: %@, Source: %@",
                             String(describing: boolValue), stringValue, numberValue,
                             String(describing: JSONValue()), String(describing: dataValue),
                             String(describing: _source))

        return String(format: "<%@: %p, %@>", String(describing: Self.self), Unmanaged.passUnretained(self), content)
    }
}
