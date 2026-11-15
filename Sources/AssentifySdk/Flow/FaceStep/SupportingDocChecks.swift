import Foundation

/// Shared logic for the supporting-document scans (passport and ID card).
/// Kotlin duplicates this in SupportingPassportScanActivity and SupportingIDCardScanActivity;
/// here both steps call the same code.
enum SupportingDocChecks {

    struct Outcome {
        let faceResult: CompareFacesResponse?
        let identityResult: IdentityMatchResponse?
        let selfieImage: String
    }

    // MARK: - Face compare + identity match

    /// Runs the face compare (selfie vs the document's face) and the identity match at the same time.
    /// Any failure counts as "no match" (fail closed). `completion` runs on the main thread.
    static func run(
        flowController: FlowController,
        documentProperties: [String: Any],
        documentFace: String,
        useCase: Int,
        completion: @escaping (Outcome) -> Void
    ) {
        let selfie = FaceModelObject.shared.get()?.faceExtractedModel?.baseImageFace ?? ""

        guard let sdk = AssentifySdkObject.shared.get(), !selfie.isEmpty else {
            DispatchQueue.main.async {
                completion(Outcome(faceResult: nil, identityResult: nil, selfieImage: selfie))
            }
            return
        }

        let customization = flowController.getCurrentStep()?.stepDefinition?.customization
        let group = DispatchGroup()
        var faceResult: CompareFacesResponse?
        var identityResult: IdentityMatchResponse?

        // 1) Face compare. No face on the document -> no match.
        if !documentFace.isEmpty {
            group.enter()
            sdk.startCompareFaces(
                sourceImageUrl: selfie,
                targetImageUrl: documentFace,
                onSuccess: { result in
                    faceResult = result
                    group.leave()
                },
                onError: { _ in
                    group.leave()                       // faceResult stays nil -> no match
                }
            )
        }

        // 2) Identity match (runs at the same time)
        if customization?.aiAdjudicatorEnabled == true {
            group.enter()
            sdk.startIdentityMatch(
                identityFields: customization?.identityFields ?? [],
                primaryValues: identityValues(from: originalIdProperties(flowController)),
                documentValues: identityValues(from: documentProperties),
                useCase: useCase,
                onSuccess: { result in
                    identityResult = result
                    group.leave()
                },
                onError: { _ in
                    group.leave()                       // identityResult stays nil -> not same person
                }
            )
        } else {
            identityResult = IdentityMatchResponse(
                samePerson: true,
                confidence: nil,
                reason: "Adjudicator disabled"
            )
        }

        group.notify(queue: .main) {
            completion(Outcome(faceResult: faceResult, identityResult: identityResult, selfieImage: selfie))
        }
    }

    // MARK: - Output properties

    /// The face step's output properties: IsSkippedStatus from `isSkip`, FaceAuthenticity 0/1 -> false/true.
    static func faceOutputProperties(model: FaceResponseModel?, isSkip: Bool) -> [String: String] {
        var output: [String: String] = (model?.faceExtractedModel?.outputProperties ?? [:])
            .mapValues { String(describing: $0) }

        if let key = output.keys.first(where: { $0.contains("OnBoardMe_FaceImageAcquisition_IsSkippedStatus") }) {
            output[key] = String(isSkip)
        }

        if let key = output.keys.first(where: { $0.contains("OnBoardMe_FaceImageAcquisition_FaceAuthenticity") }) {
            if output[key] == "0" {
                output[key] = "false"
            } else if output[key] == "1" {
                output[key] = "true"
            }
        }

        return output
    }

    /// Everything sent when the supporting-document step is done (Next or Skip on the result screen).
    static func outputProperties(
        isSkip: Bool,
        faceResult: CompareFacesResponse?,
        identityResult: IdentityMatchResponse?,
        documentProperties: [String: String]
    ) -> [String: String] {
        var output = faceOutputProperties(model: FaceModelObject.shared.get(), isSkip: isSkip)

        output["status"]     = (faceResult?.status).map { String($0) } ?? ""
        output["scanStatus"] = faceResult?.scanStatus ?? ""
        output["matchScore"] = (faceResult?.matchScore).map { String($0) } ?? ""
        output["isLive"]     = (faceResult?.isLive).map { String($0) } ?? ""
        output["error"]      = faceResult?.error ?? ""

        output["samePerson"] = (identityResult?.samePerson).map { String($0) } ?? ""
        output["confidence"] = (identityResult?.confidence).map { String($0) } ?? ""
        output["reason"]     = identityResult?.reason ?? ""

        for (key, value) in documentProperties {
            output[key] = value
        }
        return output
    }

    // MARK: - Identity values

    /// The extracted information of the main ID step.
    /// Kotlin: FlowController.getAllDoneSteps().first { IdentificationDocumentCapture }.submitRequestModel.extractedInformation
    static func originalIdProperties(_ flowController: FlowController) -> [String: Any] {
        // TODO: match the names in your Swift FlowController / step models
        let idStep = flowController.getAllDoneSteps().first {
            $0.stepDefinition?.stepDefinition == StepsNames.identificationDocumentCapture
        }
        let properties: [String: Any] = idStep?.submitRequestModel?.extractedInformation ?? [:]
        return properties
    }

    static func identityValues(from properties: [String: Any]) -> [String: String?] {
        [
            IdentityField.firstName:   value(in: properties, key: "OnBoardMe_IdentificationDocumentCapture_name"),
            IdentityField.lastName:    value(in: properties, key: "OnBoardMe_IdentificationDocumentCapture_surname"),
            IdentityField.fatherName:  value(in: properties, key: "OnBoardMe_IdentificationDocumentCapture_ID_FathersName"),
            IdentityField.dateOfBirth: value(in: properties, key: "OnBoardMe_IdentificationDocumentCapture_Birth_Date")
        ]
    }

    /// Exact key first, then the first key that contains it.
    /// Keys are sorted because Swift dictionaries have no stable order.
    private static func value(in properties: [String: Any], key: String) -> String? {
        if let exact = properties[key] {
            return text(exact)
        }
        guard let match = properties.keys.sorted().first(where: { $0.contains(key) }),
              let found = properties[match] else { return nil }
        return text(found)
    }

    private static func text(_ value: Any) -> String? {
        if let string = value as? String { return string }
        if value is NSNull { return nil }
        return String(describing: value)
    }
}
