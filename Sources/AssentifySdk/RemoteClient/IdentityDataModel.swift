import Foundation


public enum IdentityField {
    static let firstName = "FirstName"
    static let lastName = "LastName"
    static let dateOfBirth = "DateOfBirth"
    static let fatherName = "FatherName"

    // config code -> JSON key the API expects
    static let jsonKeys: [String: String] = [
        firstName: "firstName",
        lastName: "lastName",
        dateOfBirth: "dob",
        fatherName: "fatherName"
    ]
}

public enum IdentityMatchUseCase {
    static let supportingDoc = 0
    static let mrzViz = 1
}

public struct IdentityMatchRequest: Codable {
    let primary: [String: String]
    let document: [String: String]
    var useCase: Int = IdentityMatchUseCase.supportingDoc
}

public func buildIdentity(
    identityFields: [String],
    values: [String: String?]
) -> [String: String] {
    let pairs = identityFields.compactMap { code -> (String, String)? in
        guard let key = IdentityField.jsonKeys[code],
              let raw = values[code] ?? nil else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : (key, value)
    }
    return Dictionary(pairs, uniquingKeysWith: { _, last in last })
}

public struct IdentityMatchResponse: Codable {
    let samePerson: Bool?
    let confidence: Double?
    let reason: String?
}
