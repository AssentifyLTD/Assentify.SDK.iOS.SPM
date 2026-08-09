import Foundation

public final class ConfigFileManager {
    
    private let fileName: String
    
    private var fileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let name = fileName.hasSuffix(".json") ? fileName : "\(fileName).json"
        return documentsDir.appendingPathComponent(name)
    }
    
    init(fileName: String) {
        self.fileName = fileName
    }
    
    // MARK: - Private Helpers
    
    private func readFromBundle() throws -> String {
        let resourceName = (fileName as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw ConfigFileError.fileNotFoundInBundle(fileName)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
    
    private func validateJSON(_ content: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw ConfigFileError.invalidJSON
        }
        do {
            try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ConfigFileError.invalidJSON
        }
    }
    
    // MARK: - Public Methods
    
    func initFromBundleIfNeeded(processJsonConfigFile: String = "") {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let json: String
            if processJsonConfigFile.isEmpty {
                json = try readFromBundle()
            } else {
                let sourceURL = URL(fileURLWithPath: processJsonConfigFile)
                json = try String(contentsOf: sourceURL, encoding: .utf8)
            }
            try json.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[ConfigFileManager] initFromBundleIfNeeded error: \(error)")
        }
    }
    
    func read() -> String? {
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }
    
    private func readRootJSON() -> [String: Any]? {
        guard let json = read(),
              let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return root
    }
    
    func readEngagement() -> ConfigModel? {
        guard let root = readRootJSON(),
              let engagementDict = root["engagement"] as? [String: Any] else {
            print("Failed to get engagement dictionary")
            return nil
        }

        do {
            let engagementData = try JSONSerialization.data(withJSONObject: engagementDict)

            let decoder = JSONDecoder()
            let config = try decoder.decode(ConfigModel.self, from: engagementData)

            return config
        } catch {
            print("ConfigModel decode error: \(error)")
            return nil
        }
    }
    
    func readTheme() -> TenantThemeModel? {
        guard let root = readRootJSON(),
              let themeDict = root["theme"] as? [String: Any],
              let themeData = try? JSONSerialization.data(withJSONObject: themeDict) else {
            return nil
        }
        return try? JSONDecoder().decode(TenantThemeModel.self, from: themeData)
    }
    
    func readTemplates() -> [Templates]? {
        guard let root = readRootJSON(),
              let templatesArray = root["templates"] as? [[String: Any]],
              let templatesData = try? JSONSerialization.data(withJSONObject: templatesArray) else {
            return nil
        }
        return try? JSONDecoder().decode([Templates].self, from: templatesData)
    }
    
    func readContentHash() -> String? {
        return readRootJSON()?["contentHash"] as? String
    }
    
    func write(_ newContent: String) {
        do {
            try validateJSON(newContent)
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[ConfigFileManager] write error: \(error)")
        }
    }
    
    func clear() {
        write("{}")
    }
}

// MARK: - Errors

enum ConfigFileError: Error {
    case fileNotFoundInBundle(String)
    case invalidJSON
}
