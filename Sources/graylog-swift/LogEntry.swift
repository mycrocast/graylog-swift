import Foundation

// Struct to hold log entries
struct LogEntry: Codable {
    let version: String
    let host: String
    let shortMessage: String
    let fullMessage: String?
    let timestamp: TimeInterval
    let level: Int
    var additionalFields: [String: Any] // Custom fields

    enum CodingKeys: String, CodingKey {
        case version
        case host
        case shortMessage = "short_message"
        case fullMessage = "full_message"
        case timestamp
        case level
        case additionalFields
    }
    
    init (version: String, host: String, shortMessage: String, fullMessage: String?, timestamp: TimeInterval, level: Int, additionalFields: [String: Any]) {
        self.version = version
        self.host = host
        self.shortMessage = shortMessage
        self.fullMessage = fullMessage
        self.timestamp = timestamp
        self.level = level
        self.additionalFields = [:]
    }
    
    // Custom encoding to handle additionalFields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(host, forKey: .host)
        try container.encode(shortMessage, forKey: .shortMessage)
        try container.encodeIfPresent(fullMessage, forKey: .fullMessage)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(level, forKey: .level)
        
        // Encode additionalFields as a separate dictionary
        var additionalContainer = encoder.container(keyedBy: AdditionalFieldKeys.self)
        for (key, value) in additionalFields {
            let codingKey = AdditionalFieldKeys(stringValue: "_\(key)")!
            if let stringValue = value as? String {
                try additionalContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try additionalContainer.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try additionalContainer.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try additionalContainer.encode(boolValue, forKey: codingKey)
            } else {
                // Handle other types as necessary
                let error = EncodingError.Context(codingPath: [codingKey], debugDescription: "Unsupported type for additional field: \(key)")
                throw EncodingError.invalidValue(value, error)
            }
        }
    }
    
    // Custom decoding to handle additionalFields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        host = try container.decode(String.self, forKey: .host)
        shortMessage = try container.decode(String.self, forKey: .shortMessage)
        fullMessage = try container.decodeIfPresent(String.self, forKey: .fullMessage)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        level = try container.decode(Int.self, forKey: .level)
        
        // Decode additionalFields
        let additionalContainer = try decoder.container(keyedBy: AdditionalFieldKeys.self)
        var tempAdditionalFields = [String: Any]()
        
        for key in additionalContainer.allKeys {
            let fieldName = key.stringValue.dropFirst() // Remove leading "_"
            if let stringValue = try? additionalContainer.decode(String.self, forKey: key) {
                tempAdditionalFields[String(fieldName)] = stringValue
            } else if let intValue = try? additionalContainer.decode(Int.self, forKey: key) {
                tempAdditionalFields[String(fieldName)] = intValue
            } else if let doubleValue = try? additionalContainer.decode(Double.self, forKey: key) {
                tempAdditionalFields[String(fieldName)] = doubleValue
            } else if let boolValue = try? additionalContainer.decode(Bool.self, forKey: key) {
                tempAdditionalFields[String(fieldName)] = boolValue
            }
        }
        
        additionalFields = tempAdditionalFields
    }
    
    // Helper struct to dynamically create keys for additional fields
    struct AdditionalFieldKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }

    func toDictionary() -> [String: Any] {
        var logDict: [String: Any] = [
            "version": version,
            "host": host,
            "short_message": shortMessage,
            "timestamp": timestamp,
            "level": level
        ]
        
        if let fullMessage = fullMessage {
            logDict["full_message"] = fullMessage
        }
        
        // Add additional fields
        for (key, value) in additionalFields {
            logDict["_\(key)"] = value
        }
        
        return logDict
    }
}
