import SwiftUI
import Foundation


enum OtpChannelEnum: Int, Codable {
    case sms = 1
    case whatsapp = 2
    case both = 3
    case email = 4

    var name: String {
        switch self {
        case .sms:
            return "Sms"
        case .whatsapp:
            return "Whatsapp"
        case .both:
            return "Both"
        case .email:
            return "Email"
        }
    }

    static func from(value: Int) -> OtpChannelEnum? {
        return OtpChannelEnum(rawValue: value)
    }
}

public enum ContextAwareStepEventType: String {
    case onSend
    case onTokensComplete
    case onSignature
    case onError
}

// MARK: - Multiple Files Context Aware Screen
public struct MultipleFilesContextAwareScreen: View, ContextAwareDelegate {

    @State private var shareFile: ShareFile? = nil

    // MARK: Delegate callbacks
    public func onHasTokens(
        templateId: Int,
        documentTokens: [TokensMappings],
        contextAwareSigningModel: ContextAwareSigningModel
    ) {
        DispatchQueue.main.async {
            self.eventType = .onTokensComplete
            self.contextAwareSigningObject = contextAwareSigningModel

            self.selectedTemplates.append(
                SelectedTemplatesTokens(
                    templateId: templateId,
                    templateName: FlowStrings.agreement,
                    documentTokens: documentTokens
                )
            )

            let raw = contextAwareSigningModel.data.confirmationMessage ?? ""
            Task.detached(priority: .userInitiated) {
                let cleaned = self.cleanedConfirmation(raw)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    self.confirmationCleaned = cleaned
                }
            }

            if self.contextAwareSigningObject?.data.selectedTemplates.count == self.selectedTemplates.count {
                self.eventType = .onTokensComplete
            }
        }

        if let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId {
            if let userDocumentModel = CreateUserDocumentObject.shared.get(stepId: stepId) {
                buildOnCreateUserDocumentInstance(userDocumentResponseModel: userDocumentModel)
            }
        }
    }


    public func buildOnCreateUserDocumentInstance(userDocumentResponseModel: CreateUserDocumentResponseModel) {
        DispatchQueue.main.async {
            self.checked = true
            self.currentTemplateId = self.selectedTemplates.first?.templateId
            guard let tid = self.currentTemplateId else { return }
            self.documentWithTokensObject.append(
                DocumentWithTokensModel(
                    templateId: tid,
                    createUserDocumentResponseModel: userDocumentResponseModel
                )
            )
            self.eventType = .onTokensComplete
            if let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId {
                if let signatureModel = SignatureResponseObject.shared.get(stepId: stepId) {
                    buildOnSignature(signatureResponseModel: signatureModel)
                }
            }
        }
    }


    public func buildOnSignature(signatureResponseModel: SignatureResponseModel) {
        approvedDocuments.append(
            DocumentWithTokensModel(
                templateId: self.documentWithTokensObject.first!.templateId,
                createUserDocumentResponseModel: self.documentWithTokensObject.first!.createUserDocumentResponseModel
            )
        )

        DispatchQueue.main.async {
            guard let firstApproved = self.approvedDocuments.first else { return }

            self.documentWithTokensAndSigned.append(
                DocumentWithTokensAndSinged(
                    templateId: firstApproved.templateId,
                    signatureResponseModel: signatureResponseModel
                )
            )

            if self.contextAwareSigningObject?.data.autoDownload == true {
                downloadAndShare(signatureResponseModel.signedDocumentUri)
            }

            if !self.approvedDocuments.isEmpty {
                self.approvedDocuments.removeFirst()
            }

            if self.contextAwareSigningObject?.data.selectedTemplates.count == self.documentWithTokensAndSigned.count {
                self.eventType = .onSignature
                self.clickLoading = false
            } else {
               // self.signNextApprovedIfPossible()
            }

            let currentStep = flowController.getCurrentStep()
            var extractedInformation: [String: String] = [:]

            let outputProperties = flowController.getCurrentStep()?.stepDefinition?.outputProperties ?? []
            for outputProperty in outputProperties {
                if outputProperty.key.contains("OnBoardMe_ContextAwareSigning_DocumentURL") {
                    extractedInformation[outputProperty.key] =
                        documentWithTokensAndSigned.first?.signatureResponseModel.signedDocumentUri ?? ""
                }
            }
        }
    }


    public func onCreateUserDocumentInstance(userDocumentResponseModel: CreateUserDocumentResponseModel) {

        if let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId {
            CreateUserDocumentObject.shared.set(userDocumentResponseModel, stepId: stepId)
        }

        DispatchQueue.main.async {
            guard let tid = self.currentTemplateId else { return }
            self.documentWithTokensObject.append(
                DocumentWithTokensModel(
                    templateId: tid,
                    createUserDocumentResponseModel: userDocumentResponseModel
                )
            )
            self.eventType = .onTokensComplete
            self.clickLoading = false
        }
    }

    public func onSignature(signatureResponseModel: SignatureResponseModel) {

        DispatchQueue.main.async {
            if let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId {
                SignatureResponseObject.shared.set(signatureResponseModel, stepId: stepId)
            }

            guard let firstApproved = self.approvedDocuments.first else { return }

            self.documentWithTokensAndSigned.append(
                DocumentWithTokensAndSinged(
                    templateId: firstApproved.templateId,
                    signatureResponseModel: signatureResponseModel
                )
            )

            if self.contextAwareSigningObject?.data.autoDownload == true {
                downloadAndShare(signatureResponseModel.signedDocumentUri)
            }

            if !self.approvedDocuments.isEmpty {
                self.approvedDocuments.removeFirst()
            }

            if self.contextAwareSigningObject?.data.selectedTemplates.count == self.documentWithTokensAndSigned.count {
                self.eventType = .onSignature
                self.clickLoading = false
            } else {
               // self.signNextApprovedIfPossible()
            }

            let currentStep = flowController.getCurrentStep()
            var extractedInformation: [String: String] = [:]

            let outputProperties = flowController.getCurrentStep()?.stepDefinition?.outputProperties ?? []
            for outputProperty in outputProperties {
                if outputProperty.key.contains("OnBoardMe_ContextAwareSigning_DocumentURL") {
                    extractedInformation[outputProperty.key] =
                        documentWithTokensAndSigned.first?.signatureResponseModel.signedDocumentUri ?? ""
                }
            }

            flowController.trackProgress(
                currentStep: currentStep!,
                inputData: extractedInformation,
                response: "Completed",
                status: "InProgress"
            )
        }
    }

    private func downloadAndShare(_ urlString: String) {
        guard let u = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: u)
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("SignedDocument_\(UUID().uuidString).pdf")

                try data.write(to: fileURL, options: [.atomic])
                shareFile = ShareFile(url: fileURL)
            } catch {}
        }
    }

    public func onError(message: String) {
        DispatchQueue.main.async {
            self.eventType = .onError
            self.errorMessage = message
            self.clickLoading = false
        }
    }

    // MARK: Inputs
    private let flowController: FlowController
    private let steps = LocalStepsObject.shared.get()

    @State private var clickLoading: Bool = false
    @State private var didStart: Bool = false
    @State private var eventType: ContextAwareStepEventType = .onSend
    @State private var contextAwareSigningObject: ContextAwareSigningModel? = nil
    @State private var confirmationCleaned: String = ""
    @State private var currentTemplateId: Int? = nil

    @State private var selectedTemplates: [SelectedTemplatesTokens] = []
    @State private var documentWithTokensObject: [DocumentWithTokensModel] = []
    @State private var documentWithTokensAndSigned: [DocumentWithTokensAndSinged] = []

    @State private var approvedDocuments: [DocumentWithTokensModel] = []
    @State private var signatureB64: String = ""
    @State private var signatureToReuse: String? = nil

    @State private var checked: Bool = false
    @State private var selectedTemplate: SelectedTemplatesTokens? = nil
    @State private var showTemplates: Bool = false

    @State private var errorMessage: String = FlowStrings.somethingWentWrong

    // OTP states
    @State private var otpValue: String = ""
    @State private var isOtpValidated: Bool = false
    @State private var verifyOtpRequestOtpModel: VerifyOtpRequestOtpModel? = nil

    @State private var contextAwareSigning: ContextAwareSigning? = nil

    private let timeStarted: String = getCurrentDateTimeForTracking()
    private var defaultTitle: String = ""
    private let configModel = ConfigModelObject.shared.get()

    public init(flowController: FlowController) {
        self.flowController = flowController

        let currentStep = flowController.getCurrentStep()
        flowController.trackProgress(
            currentStep: currentStep!,
            inputData: flowController.outputPropertiesToMap(currentStep!.stepDefinition!.outputProperties),
            response: nil,
            status: "InProgress"
        )

        defaultTitle = configModel!
            .stepDefinitions
            .first(where: { $0.stepId == currentStep!.stepDefinition!.stepId })!
            .customization.header ?? ""
    }

    // MARK: Derived
    private var enableOtp: Bool {
        contextAwareSigningObject?.data.enableOtp == true
    }

    private var otpInputType: Int? {
        contextAwareSigningObject?.data.otpInputType
    }

    private var enableDigitalSignature: Bool {
        contextAwareSigningObject?.data.hideSignatureBoard == false
    }

    private var canSign: Bool {
        if enableOtp {
            if enableDigitalSignature {
                return isOtpValidated && !signatureB64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                return isOtpValidated
            }
        } else {
            if enableDigitalSignature {
                return !signatureB64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                return true
            }
        }
    }

    private var shouldHideApprovedContentForOtp: Bool {
        enableOtp &&
        !isOtpValidated &&
        approvedDocuments.count == selectedTemplates.count &&
        !selectedTemplates.isEmpty &&
        selectedTemplate == nil &&
        eventType != .onSignature
    }

    // MARK: Start
    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        eventType = .onSend
        selectedTemplates.removeAll()
        documentWithTokensObject.removeAll()
        documentWithTokensAndSigned.removeAll()
        approvedDocuments.removeAll()
        signatureB64 = ""
        signatureToReuse = nil
        checked = false
        selectedTemplate = nil
        showTemplates = false
        otpValue = ""
        isOtpValidated = false

        let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId

        contextAwareSigning = AssentifySdkObject.shared.get()?.startContextAwareSigning(
            contextAwareDelegate: self,
            stepId: stepId
        )
    }

    // MARK: Actions
    private func onBack() {
        flowController.backClick()
    }

    private func onNext() {
        var extractedInformation: [String: String] = [:]

        let outputProperties = flowController.getCurrentStep()?.stepDefinition?.outputProperties ?? []
        for outputProperty in outputProperties {
            if outputProperty.key.contains("OnBoardMe_ContextAwareSigning_DocumentURL") {
                extractedInformation[outputProperty.key] = documentWithTokensAndSigned.first?.signatureResponseModel.signedDocumentUri ?? ""
            }
        }

        flowController.makeCurrentStepDone(
            extractedInformation: extractedInformation,
            timeStarted: self.timeStarted
        )
        flowController.naveToNextStep()
    }

    private func onCreateUserDocumentResponseModel(_ template: SelectedTemplatesTokens) {
        clickLoading = true
        var tokenValues: [String: String] = [:]
        for token in template.documentTokens {
            tokenValues[String(token.tokenId)] = getValueByKey(token.sourceKey)
        }

        currentTemplateId = template.templateId
        contextAwareSigning?.createUserDocumentInstance(templateId: template.templateId, data: tokenValues)
    }

    private func onSignTapped() {
        let signatureToSend = enableDigitalSignature ? signatureB64 : ""
        signatureToReuse = signatureToSend

        guard let first = approvedDocuments.first else { return }

        clickLoading = true
        contextAwareSigning?.signature(
            documentId: first.createUserDocumentResponseModel.documentId,
            documentInstanceId: first.createUserDocumentResponseModel.templateInstanceId,
            signature: signatureToSend,
            verifyOtpRequestOtpModel:verifyOtpRequestOtpModel,
            signerName: getValuesByKeys((contextAwareSigningObject?.data.autoGeneratedSignatureValues)!,flowController: flowController),
            enableSignatureVisualVerifier: contextAwareSigningObject?.data.enableSignatureVisualVerifier,
            faceImage: getFaceImage(key:(contextAwareSigningObject?.data.faceImageSource)!,flowController: flowController)
        )
    }
    
    func getValuesByKeys(_ keys: [String], flowController: FlowController) -> String {
        let doneList = flowController.getAllDoneSteps()
        var results: [String: String] = [:]

        for step in doneList {
            let infoList = step.submitRequestModel?.extractedInformation ?? [:]
            for info in infoList {
                if keys.contains(info.key) && results[info.key] == nil {
                    results[info.key] = info.value
                }
            }
        }

        return keys.compactMap { results[$0] }.joined(separator: ", ")
    }
    
    func getFaceImage(key:String,flowController: FlowController) -> String {
        let doneList = flowController.getAllDoneSteps()
        var result = ""

        for step in doneList {
                let infoList = step.submitRequestModel?.extractedInformation ?? [:]
                for info in infoList {
                    if info.key == key {
                        result = info.value
                    }
                }
            
        }

        return result
    }

    private func signNextApprovedIfPossible() {
//        guard let first = approvedDocuments.first else { return }
//        let signatureToSend = enableDigitalSignature ? (signatureToReuse ?? "") : ""
//
//        contextAwareSigning?.signature(
//            documentId: first.createUserDocumentResponseModel.documentId,
//            documentInstanceId: first.createUserDocumentResponseModel.templateInstanceId,
//            signature: signatureToSend,
//            
//        )
    }

    private func getValueByKey(_ key: String) -> String {
        let doneList = flowController.getAllDoneSteps()
        for step in doneList {
            let list = step.submitRequestModel?.extractedInformation ?? [:]
            for info in list where info.key == key {
                return info.value
            }
        }
        return ""
    }

    private func removeHtml(_ value: String) -> String {
        guard let data = value.data(using: .utf8) else { return value }
        if let att = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return att.string
        }
        return value
    }

    // MARK: UI helpers
    private func isTemplateApproved(_ templateId: Int) -> Bool {
        approvedDocuments.contains(where: { $0.templateId == templateId })
    }

    private func docForTemplate(_ templateId: Int) -> DocumentWithTokensModel? {
        documentWithTokensObject.first(where: { $0.templateId == templateId })
    }

    private func signedForTemplate(_ templateId: Int) -> DocumentWithTokensAndSinged? {
        documentWithTokensAndSigned.first(where: { $0.templateId == templateId })
    }

    // MARK: Body
    public var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {

                VStack(spacing: 10) {
                    ProgressStepperView(steps: steps ?? [], bundle: .main,onBack: {onBack()})
                }
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 16) {

                        if eventType == .onSend {
                            
                            
                            if self.contextAwareSigningObject?.data.header != nil &&
                               self.contextAwareSigningObject?.data.subHeader != nil &&
                               self.contextAwareSigningObject?.data.svgLogoUrl != nil {
                                
                                VStack(spacing: 5) {
                                    HStack {
                                        Spacer()
                                        LogoSvgUrl(url: self.contextAwareSigningObject?.data.svgLogoUrl ?? "")
                                            .frame(width: 80, height: 80)
                                        Spacer()
                                    }

                                    Text(self.contextAwareSigningObject?.data.header ?? "")
                                        .font(.system(size: 25, weight: .bold))
                                        .foregroundColor(Color(BaseTheme.baseTextColor))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.horizontal, 20)

                                    Text(self.contextAwareSigningObject?.data.subHeader ?? "")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.horizontal, 20)
                                }
                            }
                            else{
                                VStack {
                                    Text(contextAwareSigningObject?.data.header ?? defaultTitle)
                                        .font(.system(size: 23, weight: .bold))
                                        .foregroundColor(Color(BaseTheme.baseTextColor))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 25)
                                        .padding(.top, 10)

                                    Spacer()
                                        .frame(height: UIScreen.main.bounds.height * 0.25)

                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color(BaseTheme.baseTextColor))
                                        .scaleEffect(1.2)

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        
                        }

                        if eventType == .onError {
                            VStack(spacing: 12) {
                                Spacer(minLength: 40)
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color(BaseTheme.baseRedColor))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                Spacer(minLength: 40)
                            }
                        }

                        if eventType == .onTokensComplete || eventType == .onSignature {

                            let shouldShowListScreen =
                                (selectedTemplate == nil)
                                || (selectedTemplate != nil && docForTemplate(selectedTemplate!.templateId) == nil && !clickLoading)

                            if shouldShowListScreen {
                                if let obj = contextAwareSigningObject {
                                    
                                    if self.contextAwareSigningObject?.data.header != nil &&
                                       self.contextAwareSigningObject?.data.subHeader != nil &&
                                       self.contextAwareSigningObject?.data.svgLogoUrl != nil {
                                        
                                        VStack(spacing: 5) {
                                            HStack {
                                                Spacer()
                                                LogoSvgUrl(url: self.contextAwareSigningObject?.data.svgLogoUrl ?? "")
                                                    .frame(width: 80, height: 80)
                                                Spacer()
                                            }

                                            Text(self.contextAwareSigningObject?.data.header ?? "")
                                                .font(.system(size: 25, weight: .bold))
                                                .foregroundColor(Color(BaseTheme.baseTextColor))
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.horizontal, 20)

                                            Text(self.contextAwareSigningObject?.data.subHeader ?? "")
                                                .font(.system(size: 15, weight: .regular))
                                                .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.horizontal, 20)
                                        }
                                        
                                    }
                                    else{
                                        Text(obj.data.header ?? "")
                                            .font(.system(size: 23, weight: .bold))
                                            .foregroundColor(Color(BaseTheme.baseTextColor))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 25)

                                        if let sub = obj.data.subHeader, !sub.isEmpty {
                                            Text(sub)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(Color(BaseTheme.baseTextColor))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 25)
                                        }
                                        
                                        Spacer(minLength: 12)
                                    }
                                 
                                }

                             

                                HStack(spacing: 0) {
                                    Toggle(isOn: Binding(
                                        get: { checked },
                                        set: { newVal in
                                            if approvedDocuments.count != selectedTemplates.count {
                                                checked = newVal
                                            }
                                        }
                                    )) {
                                        Text(FlowStrings.agreeToTerms)
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color(BaseTheme.baseTextColor))
                                    }
                                    .toggleStyle(CheckboxToggleStyle(accent: Color(BaseTheme.baseAccentColor)))

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)

                                if !shouldHideApprovedContentForOtp {
                                    if !confirmationCleaned.isEmpty {
                                        Text(confirmationCleaned)
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color(BaseTheme.baseTextColor))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 25)
                                    }

                                    Text(
                                        approvedDocuments.count != selectedTemplates.count
                                        ? FlowStrings.pleaseReviewFiles
                                        : FlowStrings.thankYouApproving
                                    )
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color(BaseTheme.baseTextColor))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 25)

                                    if approvedDocuments.count != selectedTemplates.count {
                                        VStack(spacing: 10) {
                                            ForEach(selectedTemplates, id: \.templateId) { doc in
                                                DocumentRowView(
                                                    title: doc.templateName,
                                                    isApproved: isTemplateApproved(doc.templateId),
                                                    isActive: checked,
                                                    onTap: {
                                                        guard checked else { return }
                                                        selectedTemplate = doc
                                                        if docForTemplate(doc.templateId) == nil {
                                                            onCreateUserDocumentResponseModel(doc)
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 25)
                                    } else {
                                        Button {
                                            showTemplates.toggle()
                                        } label: {
                                            HStack {
                                                Text(FlowStrings.filesReviewedApproved)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color(BaseTheme.baseTextColor))
                                                Spacer()
                                                Image(systemName: showTemplates ? "chevron.up" : "chevron.down")
                                                    .foregroundColor(Color(BaseTheme.baseTextColor))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color(BaseTheme.fieldColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                        .padding(.horizontal, 25)

                                        if showTemplates {
                                            VStack(spacing: 10) {
                                                ForEach(selectedTemplates, id: \.templateId) { doc in
                                                    DocumentRowView(
                                                        title: doc.templateName,
                                                        isApproved: isTemplateApproved(doc.templateId),
                                                        isActive: checked,
                                                        onTap: {
                                                            guard checked else { return }
                                                            selectedTemplate = doc
                                                            if docForTemplate(doc.templateId) == nil {
                                                                onCreateUserDocumentResponseModel(doc)
                                                            }
                                                        }
                                                    )
                                                }
                                            }
                                            .padding(.horizontal, 25)
                                            .padding(.top, 8)
                                        }
                                    }
                                }
                            }

                            // ── Signed doc viewer (after signature) ──
                            if let sel = selectedTemplate,
                               eventType == .onSignature {
                                DocumentPageFromUrlView(
                                    url: signedForTemplate(sel.templateId)?.signatureResponseModel.signedDocumentUri,
                                    isLoading: signedForTemplate(sel.templateId) == nil,
                                    onCancel: { selectedTemplate = nil }
                                )
                                .padding(.top, 8)
                            }

                            // ── PDF viewer / loader (before signature) ──
                            if let sel = selectedTemplate,
                               eventType != .onSignature {
                                DocumentPageView(
                                    userDocumentResponseModel: docForTemplate(sel.templateId)?.createUserDocumentResponseModel,
                                    isApproved: isTemplateApproved(sel.templateId),
                                    isLoading: docForTemplate(sel.templateId) == nil,
                                    onAccept: {
                                        if !isTemplateApproved(sel.templateId) {
                                            if let doc = docForTemplate(sel.templateId) {
                                                approvedDocuments.append(
                                                    DocumentWithTokensModel(
                                                        templateId: sel.templateId,
                                                        createUserDocumentResponseModel: doc.createUserDocumentResponseModel
                                                    )
                                                )
                                            }
                                        }
                                        selectedTemplate = nil
                                    },
                                    onCancel: { selectedTemplate = nil }
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 15)
                                .padding(.top, 8)
                            }

                            if selectedTemplate == nil,
                               approvedDocuments.count == selectedTemplates.count,
                               eventType != .onSignature {

                                Spacer(minLength: 8)

                                if enableOtp && !isOtpValidated {
                                    if otpInputType == OtpChannelEnum.email.rawValue {
                                        SigningEmailWithOtp(
                                            title: FlowStrings.emailVerificationTitle,
                                            contextAwareSigningModel: contextAwareSigningObject!,
                                            flowController: flowController,
                                            onValueChange: { value in otpValue = value },
                                            onValid: { response in
                                                verifyOtpRequestOtpModel = response
                                                isOtpValidated = true
                                            }
                                        )
                                        .padding(.horizontal, 25)
                                    } else {
                                        SigningPhoneWithOtp(
                                            title: FlowStrings.phoneNumberTitle,
                                            contextAwareSigningModel: contextAwareSigningObject!,
                                            flowController: flowController,
                                            onValueChange: { value in otpValue = value },
                                            onValid: { response in
                                                verifyOtpRequestOtpModel = response
                                                isOtpValidated = true
                                            }
                                        )
                                        .padding(.horizontal, 25)
                                    }
                                } else if enableDigitalSignature {
                                    SignaturePadContainer(signatureBase64: $signatureB64,isLoading:clickLoading)
                                            .padding(.top, 8)
                                    
                                 
                                }else if clickLoading{
                                    ZStack {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Color(BaseTheme.baseTextColor))
                                            .scaleEffect(1.2).padding(.top, 40)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 20)
                }



                if selectedTemplate == nil && eventType == .onTokensComplete && !clickLoading {
                    BaseClickButton(
                        title: enableOtp && !isOtpValidated
                            ? FlowStrings.validateOtpFirst
                            : (enableDigitalSignature ? FlowStrings.acceptTermsAndSign : FlowStrings.acceptTerms),
                        verticalPadding: 18,
                        enabled: canSign
                    ) {
                        onSignTapped()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                if selectedTemplate == nil && eventType == .onSignature {
                    
                    
                    if self.contextAwareSigningObject?.data.isNormalClick ==  true{
                        BaseClickButton(title: FlowStrings.next, verticalPadding: 18, enabled: true) {
                            onNext()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }else{
                        BaseSliderClick(
                            onNext: {
                                onNext()
                            },
                            label: FlowStrings.next,
                            icon: "checkmark",
                            isActive: true
                        ) .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                  
                }
            }
            .topBarBackLogo { onBack() }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .modifier(InterceptSystemBack(action: onBack))
        .task { startIfNeeded() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func cleanedConfirmation(_ raw: String) -> String {
        removeHtml(raw)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Document Row
fileprivate struct DocumentRowView: View {
    let title: String
    let isApproved: Bool
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isActive {
                    Image(systemName: isApproved ? "checkmark.circle" : "doc")
                        .font(.system(size: isApproved ? 22 : 18, weight: .semibold))
                        .foregroundColor(
                            isApproved
                            ? Color(BaseTheme.baseGreenColor)
                            : Color(BaseTheme.baseAccentColor)
                        )
                        .frame(width: 26)
                } else {
                    Color.clear.frame(width: 26)
                }

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor).opacity(isActive ? 1.0 : 0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "eye")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseAccentColor).opacity(isActive ? 1.0 : 0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(BaseTheme.fieldColor).opacity(isActive ? 1.0 : 0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Page (before signature)
fileprivate struct DocumentPageView: View {
    let userDocumentResponseModel: CreateUserDocumentResponseModel?
    let isApproved: Bool
    let isLoading: Bool
    let onAccept: () -> Void
    let onCancel: () -> Void

    private var pdfHeight: CGFloat {
        !isApproved
            ? UIScreen.main.bounds.height - 380
            : UIScreen.main.bounds.height - 360
    }

    var body: some View {
        VStack(spacing: 15) {

            if isLoading {
                // ← loader shown immediately while PDF is fetched
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(BaseTheme.fieldColor))
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(BaseTheme.baseTextColor))
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: pdfHeight)

            } else if let doc = userDocumentResponseModel {
                PdfViewerFromBase64(base64Data: doc.templateInstance)
                    .frame(maxWidth: .infinity)
                    .frame(height: pdfHeight)

                if !isApproved {
                    BaseClickButton(title: FlowStrings.approve, verticalPadding: 18, enabled: true) {
                        onAccept()
                    }
                }
            }
            
                OutlineButton(
                    title: FlowStrings.cancel,
                    cornerRadius: 28,
                    borderColor: Color(BaseTheme.baseAccentColor),
                    textColor: Color(BaseTheme.baseAccentColor),
                    height: 55,
                    action: onCancel
                )
            

            
        }
    }
}

// MARK: - Document Page From URL (after signature)
fileprivate struct DocumentPageFromUrlView: View {
    let url: String?
    let isLoading: Bool
    let onCancel: () -> Void

    @State private var shareFile: ShareFile? = nil
    @State private var showFullScreen: Bool = false

    private var pdfHeight: CGFloat {
        UIScreen.main.bounds.height - 350
    }

    var body: some View {
        VStack(spacing: 15) {

            if isLoading {
                // ← loader shown immediately while signed PDF loads
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(BaseTheme.fieldColor))
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(BaseTheme.baseTextColor))
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: pdfHeight)
                .padding(.horizontal, 15)

            } else if let url {
                BasePDFCardViewFomUrl(
                    urlString: url,
                    tintColor: BaseTheme.baseTextColor,
                    onDownloadTap: { downloadAndShare(url) },
                    onFullScreenTap: { showFullScreen = true }
                )
                .frame(height: pdfHeight)
                .padding(.horizontal, 15)
            }

            OutlineButton(
                title: FlowStrings.cancel,
                cornerRadius: 28,
                borderColor: Color(BaseTheme.baseAccentColor),
                textColor: Color(BaseTheme.baseAccentColor),
                height: 55,
                action: onCancel
            )
            .padding(.horizontal, 15)
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let url { FullScreenPDFView(urlString: url) }
        }
    }

    private func downloadAndShare(_ urlString: String) {
        guard let u = URL(string: urlString) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: u)
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("SignedDocument_\(UUID().uuidString).pdf")
                try data.write(to: fileURL, options: [.atomic])
                shareFile = ShareFile(url: fileURL)
            } catch {}
        }
    }
}

fileprivate struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

fileprivate struct SignaturePadContainer: View {
    @Binding var signatureBase64: String
    var isLoading: Bool

    var body: some View {
        SignaturePad(title: FlowStrings.signature,isLoading:isLoading) { b64 in
            signatureBase64 = b64
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .padding(.horizontal, 25)
    }
}

// MARK: - Tiny helpers
fileprivate struct CheckboxToggleStyle: ToggleStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(accent)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

public struct SelectedTemplatesTokens: Codable {
    public let templateId: Int
    public let templateName: String
    public let documentTokens: [TokensMappings]

    public init(templateId: Int, templateName: String, documentTokens: [TokensMappings]) {
        self.templateId = templateId
        self.templateName = templateName
        self.documentTokens = documentTokens
    }
}

public struct DocumentWithTokensModel: Codable {
    public let templateId: Int
    public let createUserDocumentResponseModel: CreateUserDocumentResponseModel

    public init(templateId: Int, createUserDocumentResponseModel: CreateUserDocumentResponseModel) {
        self.templateId = templateId
        self.createUserDocumentResponseModel = createUserDocumentResponseModel
    }
}

public struct DocumentWithTokensAndSinged: Codable {
    public let templateId: Int
    public let signatureResponseModel: SignatureResponseModel

    public init(templateId: Int, signatureResponseModel: SignatureResponseModel) {
        self.templateId = templateId
        self.signatureResponseModel = signatureResponseModel
    }
}

private struct OutlineButton: View {
    let title: String
    let cornerRadius: CGFloat
    let borderColor: Color
    let textColor: Color
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}


