import Foundation

public class LogManager {
    
    // Singleton instance (lazy, so it's only initialized when first accessed)
    public static let shared: LogManager = {
        guard let instance = LogManager.instance else {
            fatalError("LogManager not configured. Call LogManager.configure(graylogEndpoint:batchInterval:) first.")
        }
        return instance
    }()
    
    // Singleton instance
    private static var instance : LogManager?
    
    private var graylogEndpoint: URL
    private var batchInterval: TimeInterval = 60 // 1 minute
    private let userDefaultsKey = "LogEntries"
    
    private var timer: Timer?
    private let logQueue = DispatchQueue(label: "com.example.logQueue")

    
    // Private init to enforce singleton pattern
      private init(graylogEndpoint: URL, batchInterval: TimeInterval) {
          self.graylogEndpoint = graylogEndpoint
          self.batchInterval = batchInterval
          
          // Start sending logs at the specified interval
          self.timer = Timer.scheduledTimer(timeInterval: batchInterval,
                                            target: self,
                                            selector: #selector(sendBatchLogs),
                                            userInfo: nil,
                                            repeats: true)
      }
      
      // MARK: - Configuration Method
      
      /// Configures the LogManager singleton. Must be called before accessing `shared`.
      public static func configure(graylogEndpoint: URL, batchInterval: TimeInterval = 60.0) {
          guard instance == nil else {
              print("LogManager is already configured.")
              return
          }
          instance = LogManager(graylogEndpoint: graylogEndpoint, batchInterval: batchInterval)
      }
    
 
    // MARK: - Logging Methods
    
    public func log(shortMessage: String, fullMessage: String? = nil, level: Int = 1, additionalFields: [String: Any] = [:]) {
        let logEntry = LogEntry(
            version: "1.1",
            host: "my-application-host", // Customize this as needed
            shortMessage: shortMessage,
            fullMessage: fullMessage,
            timestamp: Date().timeIntervalSince1970,
            level: level,
            additionalFields: additionalFields
        )
        
        self.logQueue.async {
            // Store the log in UserDefaults
            self.storeLogEntry(logEntry)
        }
    }
    
    // MARK: - Storing Logs
    
    private func storeLogEntry(_ logEntry: LogEntry) {
        var storedLogs = loadStoredLogs()
        storedLogs.append(logEntry)
        
        if let encoded = try? JSONEncoder().encode(storedLogs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadStoredLogs() -> [LogEntry] {
        if let savedLogs = UserDefaults.standard.object(forKey: userDefaultsKey) as? Data {
            if let decodedLogs = try? JSONDecoder().decode([LogEntry].self, from: savedLogs) {
                return decodedLogs
            }
        }
        return []
    }
    
    private func removeStoredLogs(_ logsToRemove: [LogEntry]) {
        logQueue.async {
            var storedLogs = self.loadStoredLogs()
            storedLogs.removeAll { logEntry in
                logsToRemove.contains(where: { $0.timestamp == logEntry.timestamp })
            }
            
            if let encoded = try? JSONEncoder().encode(storedLogs) {
                UserDefaults.standard.set(encoded, forKey: self.userDefaultsKey)
            }
        }
    }
    
    // MARK: - Sending Logs
    
    @objc private func sendBatchLogs() {
        logQueue.async {
            let logsToSend = self.loadStoredLogs()
            
            guard !logsToSend.isEmpty else {
                return // No logs to send
            }
            
            let jsonLogs = logsToSend.map { $0.toDictionary() }
            
            var request = URLRequest(url: self.graylogEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonLogs, options: [])
                request.httpBody = jsonData
            } catch {
                print("Error serializing JSON: \(error)")
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send logs: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
                    // Successfully sent, remove the logs from storage
                    self.removeStoredLogs(logsToSend)
                } else {
                    print("Failed to send logs. Server returned an error.")
                }
            }
            
            task.resume()
        }
    }
}
