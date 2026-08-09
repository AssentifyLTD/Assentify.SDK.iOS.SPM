import SwiftUI
import UIKit

public struct SigningPhoneWithOtp: View {
    
    public let title: String
    public let flowController: FlowController
    public var contextAwareSigningModel: ContextAwareSigningModel
    
    public let onValueChange: (String) -> Void
    public let onValid: (VerifyOtpRequestOtpModel) -> Void
    
    @State private var phone: String = ""
    @State private var otp: String = ""
    
    @State private var isOtpStep: Bool = false
    @State private var isVerified: Bool = false
    @State private var verifying: Bool = false
    @State private var sendingOtp: Bool = false
    
    @State private var requestError: String = ""
    
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
                phoneField()
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
        }
        .onAppear {
            self.phone = getPhoneValueByKey(
                contextAwareSigningModel.data.otpTargets.first ?? "",
                flowController: flowController
            )
            
            onValueChange(phone)
        }
        .onChange(of: phone) { _ in
            requestError = ""
            onValueChange(phone)
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
    private func phoneField() -> some View {
        HStack(spacing: 10) {
            TextField(title, text: $phone)
                .disabled(true)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(Color(BaseTheme.baseTextColor))
            
            if phone.isNotBlank {
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
                .disabled(sendingOtp || phone.isNotBlank == false)
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
            get: { isVerified ? phone : otp },
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
        .keyboardType(otpKeyboardType(otpFormat))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
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
                ResendOtpControl(expiryMinutes: expiryMinutes) {
                    resendOtp()
                }
            }
            
            Spacer()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Logic
    
    private func sendOtp() {
        guard !sendingOtp else { return }
        guard phone.isNotBlank else { return }
        guard let configModelObject = ConfigModelObject.shared.get() else { return }
        
        sendingOtp = true
        requestError = ""
        
        let req = RequestOtpModel(
            token: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            inputType: OtpChannelEnum.from(value: contextAwareSigningModel.data.otpInputType ?? 1)?.name ?? "Sms",
            otpSize: otpSize,
            otpType: contextAwareSigningModel.data.otpInputType ?? 1,
            otpExpiryTime: expiryMinutes,
            otpFormat: contextAwareSigningModel.data.otpFormat ?? 1,
            smsProvider: contextAwareSigningModel.data.smsProvider,
            whatsappProvider: contextAwareSigningModel.data.whatsappProvider
        )
        
        OtpHelper.requestOtp(config: configModelObject, requestOtpModel: req) { result in
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
        guard phone.isNotBlank else { return }
        guard otp.count == otpSize else { return }
        guard let configModelObject = ConfigModelObject.shared.get() else { return }
        
        verifying = true
        requestError = ""
        
        let verifyReq = VerifyOtpRequestOtpModel(
            token: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            otp: otp,
            otpExpiryTime: expiryMinutes
        )
        
        OtpHelper.verifyOtp(config: configModelObject, verifyOtpRequestOtpModel: verifyReq) { result in
            switch result {
            case .success(let success):
                DispatchQueue.main.async {
                    verifying = false
                    isVerified = success
                    
                    if success {
                        requestError = ""
                        onValid(verifyReq)
                    } else {
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
    
    // MARK: - OTP Helpers
    
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

// MARK: - Helpers

fileprivate extension String {
    var isNotBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

func getPhoneValueByKey(_ key: String, flowController: FlowController) -> String {
    let doneList = flowController.getAllDoneSteps()
    
    for step in doneList {
        let list = step.submitRequestModel?.extractedInformation ?? [:]
        
        for info in list where info.key == key {
            return info.value
        }
    }
    
    return ""
}
