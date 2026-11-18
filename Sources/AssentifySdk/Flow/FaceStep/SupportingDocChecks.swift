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

    /// The face step's supporting-document output keys (exact names, as declared in the step's outputProperties).
    enum OutputKey {
        static let extractionsJSON  = "OnBoardMe_FaceImageAcquisition_SupportingDocumentExtractionsJSON"
        static let image            = "OnBoardMe_FaceImageAcquisition_SupportingDocumentImage"
        static let face             = "OnBoardMe_FaceImageAcquisition_SupportingDocumentFace"
        static let firstName        = "OnBoardMe_FaceImageAcquisition_SupportingDocumentFirstName"
        static let lastName         = "OnBoardMe_FaceImageAcquisition_SupportingDocumentLastName"
        static let faceMatchOutcome = "OnBoardMe_FaceImageAcquisition_FaceMatchOutcome"
        static let matchPercentage  = "OnBoardMe_FaceImageAcquisition_SupportingDocumentMatchPercentage"
        static let mismatchFields   = "OnBoardMe_FaceImageAcquisition_IdentityMismatchFields"
        static let finalMatchPercentage   = "OnBoardMe_FaceImageAcquisition_FinalMatchPercentage"
    }

    /// Keys read from the supporting document's transformed properties (exact names).
    /// TODO: confirm these against a real passport / ID response.
    enum DocumentKey {
        static let originalImage = "OnBoardMe_IdentificationDocumentCapture_OriginalFrontImage"
        static let firstName     = "OnBoardMe_IdentificationDocumentCapture_name"
        static let lastName      = "OnBoardMe_IdentificationDocumentCapture_surname"
    }

    /// The values of OnBoardMe_FaceImageAcquisition_FaceMatchOutcome.
    enum FaceMatchOutcome {
        static let supportingDocumentSuccess = "SupportingDocumentSuccess"
        static let supportingDocumentSkipped = "SupportingDocumentSkipped"
    }

    /// Everything sent when the supporting-document step is done (Next or Skip on the result screen).
    /// Call it BEFORE makeCurrentStepDone(): it reads the current (face) step's outputProperties.
    static func outputProperties(
        isSkip: Bool,
        faceResult: CompareFacesResponse?,
        identityResult: IdentityMatchResponse?,
        documentProperties: [String: String],
        documentFace: String,
        flowController: FlowController
    ) -> [String: String] {
        var output = faceOutputProperties(model: FaceModelObject.shared.get(), isSkip: isSkip)

        // The face step as written in the config file, and the output keys it declares
        let currentStepId = flowController.getCurrentStep()?.stepDefinition?.stepId
        let step = ConfigModelObject.shared.get()?.stepDefinitions.first { $0.stepId == currentStepId }
        let declaredProperties = step?.outputProperties ?? []
        let declaredKeys = Set(declaredProperties.map { $0.key })

        /// Writes a value only under a key the step declares (exact match).
        func set(_ name: String, _ value: String) {
            guard let key = declaredKeys.first(where: { $0 == name })
                    ?? declaredKeys.first(where: { $0.contains(name) }) else { return }
            output[key] = value
        }

        // 2) every extracted value of the supporting document, as one JSON string
        set(OutputKey.extractionsJSON, jsonString(documentProperties))

        // 3) 4) 5) single values from the document
        set(OutputKey.image,     documentProperties[DocumentKey.originalImage] ?? "")
        set(OutputKey.firstName, documentProperties[DocumentKey.firstName] ?? "")
        set(OutputKey.lastName,  documentProperties[DocumentKey.lastName] ?? "")

        // 6) the face cropped from the document (first item of faces)
        set(OutputKey.face, documentFace)

        
        // 7) the identity fields that did not match
        set(OutputKey.mismatchFields, identityResult?.reason ?? "")
        // 8) the compare-faces score
        set(OutputKey.matchPercentage, faceResult?.matchScore?.description ?? "")
        set(OutputKey.finalMatchPercentage, faceResult?.matchScore?.description ?? "")

        // 9) skipped or passed
        set(OutputKey.faceMatchOutcome, isSkip
            ? FaceMatchOutcome.supportingDocumentSkipped
            : FaceMatchOutcome.supportingDocumentSuccess)

        return output
    }

    

    private static func jsonString(_ properties: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: properties, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
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
