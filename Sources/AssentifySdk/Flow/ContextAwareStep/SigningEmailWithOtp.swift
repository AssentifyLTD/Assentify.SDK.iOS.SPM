import SwiftUI
import UIKit

public struct SigningEmailWithOtp: View {
    
    public let title: String
    public let flowController: FlowController
    public var contextAwareSigningModel: ContextAwareSigningModel
    
    public let onValueChange: (String) -> Void
    public let onValid: (VerifyOtpRequestOtpModel) -> Void
    
    @State private var email: String = ""
    @State private var otp: String = ""
    
    @State private var isOtpStep: Bool = false
    @State private var isVerified: Bool = false
    @State private var verifying: Bool = false
    @State private var sendingOtp: Bool = false
    
    @State private var errToShow: String = ""
    @State private var requestError: String = ""
    
    private let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
    
    public init(
        title: String,
        contextAwareSigningModel: ContextAwareSigningModel,
        flowController: FlowController,
        onValueChange: @escaping (String) -> Void,
        onValid: @escaping (VerifyOtpRequestOtpModel) -> Void
    ) {
        self.title = title
        self.contextAwareSigningModel = contextAwareSigningModel
        self.flowController = flowController
        self.onValueChange = onValueChange
        self.onValid = onValid
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            if !isOtpStep {
                emailField()
            } else {
                otpField()
                otpFooter()
            }
            
            if requestError.isNotBlank {
                Text(requestError)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseRedColor))
                    .padding(.top, 4)
            }
            
            if errToShow.isNotBlank {
                Text(errToShow)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseRedColor))
                    .padding(.top, 4)
            }
        }
        .onAppear {
            self.email = getEmailValueByKey(contextAwareSigningModel.data.otpTargets.first!, flowController: flowController)
            recomputeEmailError()
        }
        .onChange(of: email) { _ in
            requestError = ""
            onValueChange(email)
            recomputeEmailError()
        }
    }
    
    // MARK: - Derived
    
    private var otpSize: Int {
        Int(contextAwareSigningModel.data.otpSize ?? 8)
    }
    
    private var otpFormat: Int {
        Int(contextAwareSigningModel.data.otpFormat ?? 1)
    }
    
    private var expiryMinutes: Double {
        contextAwareSigningModel.data.otpExpiryTime ?? 1.0
    }
    
    // MARK: - UI
    
    @ViewBuilder
    private func emailField() -> some View {
        HStack(spacing: 10) {
            TextField(title, text: $email)
                .disabled(true)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .foregroundColor(Color(BaseTheme.baseTextColor))
            
            if emailLooksValid(email) {
                Button {
                    sendOtp()
                } label: {
                    ZStack {
                        if sendingOtp {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(BaseTheme.baseTextColor))
                                .scaleEffect(0.9)
                        } else {
                            Text(FlowStrings.sendOtp)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(BaseTheme.baseTextColor))
                        }
                    }
                    .frame(minWidth: 86)
                    .frame(height: 40)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(BaseTheme.baseAccentColor))
                    )
                }
                .disabled(sendingOtp || !emailLooksValid(email))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 55)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
    }
    
    @ViewBuilder
    private func otpField() -> some View {
        TextField(FlowStrings.otpPlaceholder(size: otpSize), text: Binding(
            get: { isVerified ? email : otp },
            set: { raw in
                guard !isVerified, !verifying else { return }
                
                requestError = ""
                
                let filtered = filterByOtpType(raw, otpType: otpFormat)
                let limited = String(filtered.prefix(otpSize))
                otp = limited
                
                if limited.count == otpSize, otpMatchesType(limited, otpType: otpFormat) {
                    verifyOtp()
                }
            }
        ))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(otpKeyboardType(otpFormat))
        .disabled(isVerified)
        .foregroundColor(Color(BaseTheme.baseTextColor))
        .padding(.horizontal, 14)
        .frame(height: 55)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
    }
    
    @ViewBuilder
    private func otpFooter() -> some View {
        HStack {
            if isVerified {
                Text(FlowStrings.verifiedSuccessfully)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
            } else if verifying {
                Text(FlowStrings.otpVerifying)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
            } else if sendingOtp {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(BaseTheme.baseTextColor))
                        .scaleEffect(0.7)
                    
                    Text(FlowStrings.sendingOtp)
                        .font(.system(size: 12))
                        .foregroundColor(Color(BaseTheme.baseAccentColor))
                }
            } else {
                ResendOtpControl(
                    expiryMinutes: expiryMinutes
                ) {
                    resendOtp()
                }
            }
            
            Spacer()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Logic
    
    private func recomputeEmailError() {
        if email.isNotBlank && !emailLooksValid(email) {
            errToShow = FlowStrings.invalidEmail
        } else {
            errToShow = ""
        }
    }
    
    private func sendOtp() {
        guard !sendingOtp else { return }
        guard emailLooksValid(email) else { return }
        
        let configModelObject = ConfigModelObject.shared.get()
        guard let configModelObject else { return }
        
        sendingOtp = true
        requestError = ""
        
        let request = RequestOtpModel(
            token: email.trimmingCharacters(in: .whitespacesAndNewlines),
            inputType:OtpChannelEnum.from(value: contextAwareSigningModel.data.otpInputType ?? 1)?.name ?? "Sms",
            otpSize: otpSize,
            otpType: contextAwareSigningModel.data.otpInputType ?? 1,
            otpExpiryTime: expiryMinutes,
            otpFormat: contextAwareSigningModel.data.otpFormat ?? 1,
            smsProvider: contextAwareSigningModel.data.smsProvider,
            whatsappProvider: contextAwareSigningModel.data.whatsappProvider,
        )
        
        OtpHelper.requestOtp(config: configModelObject, requestOtpModel: request)
        { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    sendingOtp = false
                    isOtpStep = true
                    otp = ""
                    isVerified = false
                    requestError = ""
                }
                
            case .failure:
                DispatchQueue.main.async {
                    sendingOtp = false
                    requestError = FlowStrings.otpSendFailed
                }
            }
        }
    }
    
    private func resendOtp() {
        sendOtp()
    }
    
    private func verifyOtp() {
        guard emailLooksValid(email) else { return }
        guard otp.count == otpSize else { return }
        
        let configModelObject = ConfigModelObject.shared.get()
        guard let configModelObject else { return }
        
        verifying = true
        requestError = ""
        
        let req = VerifyOtpRequestOtpModel(
            token: email.trimmingCharacters(in: .whitespacesAndNewlines),
            otp: otp,
            otpExpiryTime: expiryMinutes
        )
        
        OtpHelper.verifyOtp(config: configModelObject, verifyOtpRequestOtpModel: req) { result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    verifying = false
                    if response {
                        isVerified = true
                        requestError = ""
                        onValid(req)
                    } else {
                        isVerified = false
                        requestError = FlowStrings.invalidOtp
                    }
                }
                
            case .failure:
                DispatchQueue.main.async {
                    verifying = false
                    isVerified = false
                    requestError = FlowStrings.invalidOtp
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func emailLooksValid(_ s: String) -> Bool {
        let x = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if !(x.contains("@") && x.contains(".") && x.count >= 5) {
            return false
        }
        
        let regex = try! NSRegularExpression(
            pattern: emailPattern,
            options: [.caseInsensitive]
        )
        
        let range = NSRange(location: 0, length: x.utf16.count)
        return regex.firstMatch(in: x, options: [], range: range) != nil
    }
    
    private func otpMatchesType(_ value: String, otpType: Int) -> Bool {
        switch otpType {
        case 1:
            return value.allSatisfy { $0.isNumber }
        case 2:
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        case 3:
            return value.allSatisfy { $0.isLetter }
        case 4:
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        default:
            return true
        }
    }
    
    private func filterByOtpType(_ raw: String, otpType: Int) -> String {
        switch otpType {
        case 1:
            return raw.filter { $0.isNumber }
        case 2:
            return raw.filter { $0.isLetter || $0.isNumber }
        case 3:
            return raw.filter { $0.isLetter }
        case 4:
            return raw.filter { $0.isLetter || $0.isNumber }
        default:
            return raw
        }
    }
    
    private func otpKeyboardType(_ otpType: Int) -> UIKeyboardType {
        switch otpType {
        case 1:
            return .numberPad
        case 2:
            return .asciiCapable
        case 3:
            return .default
        case 4:
            return .asciiCapable
        default:
            return .asciiCapable
        }
    }
}

fileprivate extension String {
    var isNotBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


func getEmailValueByKey(_ key: String,flowController:FlowController) -> String {
    let doneList = flowController.getAllDoneSteps()
    for step in doneList {
        let list = step.submitRequestModel?.extractedInformation ?? [:]
        for info in list where info.key == key {
            return info.value
        }
    }
    return ""
}
