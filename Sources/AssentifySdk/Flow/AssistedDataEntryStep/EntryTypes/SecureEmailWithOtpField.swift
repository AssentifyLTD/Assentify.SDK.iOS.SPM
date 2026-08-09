import SwiftUI
import UIKit



public struct SecureEmailWithOtpField: View {
    
    public let title: String
    public let page: Int
    public let flowController: FlowController
    
    @Binding public var field: DataEntryPageElement
    
    public let onValueChange: (String) -> Void
    public let onValid: () -> Void
    
    // focus support
    @Binding public var focusedFieldId: String?
    public let fieldId: String
    
    @State private var email: String = ""
    @State private var otp: String = ""
    
    @State private var isOtpStep: Bool = false
    @State private var isVerified: Bool = false
    @State private var verifying: Bool = false
    
    @State private var errToShow: String = ""
    
    public init(
        title: String,
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        onValueChange: @escaping (String) -> Void,
        onValid: @escaping () -> Void
    ) {
        self.title = title
        self.page = page
        self._field = field
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.onValueChange = onValueChange
        self.onValid = onValid
        if (self.field.isHidden == true){
            syncInitialEmail()
        }
    }
    
    public var body: some View {
        if (self.field.isHidden == false){
            VStack(alignment: .leading, spacing: 6) {
                
                Text(headerTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                
                if !isOtpStep {
                    emailField()
                } else {
                    otpField()
                    otpFooter()
                }
                
                if verifying {
                    Text(FlowStrings.otpVerifying)
                        .font(.system(size: 12))
                        .foregroundColor(Color(BaseTheme.baseAccentColor))
                        .padding(.top, 4)
                }
                
                if !errToShow.isEmpty {
                    Text(errToShow)
                        .font(.system(size: 12))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                        .padding(.top, 4)
                }
            }
            
            .onAppear {
                syncInitialEmail()
                recomputeEmailError()
            }
            .onChange(of: email) { _ in
                onValueChange(email)
                recomputeEmailError()
            }
        }}
    
    // MARK: - Derived
    
    private var headerTitle: String {
        (!isOtpStep || isVerified) ? title : FlowStrings.enterOtp
    }
    
    private var otpSize: Int {
        Int(field.otpSize ?? 8)
    }
    
    private var otpFormat: Int {
        Int(field.otpFormat ?? 1) // 1 numeric, 2 alnum, 3 letters
    }
    
    private var expiryMinutes: Double {
        field.otpExpiryTime ?? 1.0
    }
    
    private var isReadOnly: Bool {
        (field.readOnly ?? false)
    }
    
    // MARK: - UI blocks
    
    @ViewBuilder
    private func emailField() -> some View {
        HStack(spacing: 10) {
            
            UIKitEmailTextField(
                text: $email,
                isFirstResponder: Binding(
                    get: { focusedFieldId == fieldId },
                    set: { newValue in
                        if newValue { focusedFieldId = fieldId }
                        else if focusedFieldId == fieldId { focusedFieldId = nil }
                    }
                ),
                isEnabled: !isReadOnly
            ) { newValue in
                email = newValue
            }
            .frame(height: 55)
            
            if emailLooksValid(email) {
                Button {
                    sendOtp()
                } label: {
                    Text(FlowStrings.sendOtp)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(BaseTheme.baseAccentColor))
                        )
                }
                .disabled(!emailLooksValid(email) || isReadOnly)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 55)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
        .contentShape(Rectangle())
        .onTapGesture { focusedFieldId = fieldId }
    }
    
    @ViewBuilder
    private func otpField() -> some View {
        HStack(spacing: 10) {
            UIKitOtpTextField(
                text: Binding(
                    get: { isVerified ? email : otp },
                    set: { raw in
                        guard !isVerified else { return }
                        let filtered = filterByOtpType(raw, otpType: otpFormat)
                        let limited = String(filtered.prefix(otpSize))
                        otp = limited
                        
                        // auto verify when otp complete
                        if otp.count == otpSize, otpMatchesType(otp, otpType: otpFormat) {
                            verifyOtp()
                        }
                    }
                ),
                isFirstResponder: Binding(
                    get: { focusedFieldId == fieldId },
                    set: { newValue in
                        if newValue { focusedFieldId = fieldId }
                        else if focusedFieldId == fieldId { focusedFieldId = nil }
                    }
                ),
                isEnabled: !isReadOnly && !isVerified,
                keyboardType: otpKeyboardType(otpFormat),
                placeholder: FlowStrings.otpPlaceholder(size: otpSize)
            )
            .frame(height: 55)
        }
        .padding(.horizontal, 14)
        .frame(height: 55)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
        .contentShape(Rectangle())
        .onTapGesture { focusedFieldId = fieldId }
    }
    
    @ViewBuilder
    private func otpFooter() -> some View {
        HStack {
            if isVerified {
                Text(FlowStrings.verifiedSuccessfully)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
            } else {
                if !verifying {
                    ResendOtpControl(
                        expiryMinutes: expiryMinutes
                    ) {
                        resendOtp()
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Logic
    
    private func syncInitialEmail() {
        // if you already store default email somewhere, set it here
        if let existing = field.value, !existing.isEmpty {
            email = existing
        }
    }
    
    private func recomputeEmailError() {
        if email.isNotBlank, !emailLooksValid(email) {
            errToShow = FlowStrings.invalidEmail
        } else {
            errToShow = ""
        }
    }
    
    private func sendOtp() {
        guard emailLooksValid(email) else { return }
        guard !isReadOnly else { return }
        
        let configModelObject = ConfigModelObject.shared.get()
        
        let request = RequestOtpModel(
            token: email.trimmingCharacters(in: .whitespacesAndNewlines),
            inputType: field.inputType,
            otpSize: otpSize,
            otpType: field.otpType ?? 1,
            otpExpiryTime: expiryMinutes,
            otpFormat: field.otpFormat ?? 1,
            smsProvider: field.smsProvider,
            whatsappProvider: field.whatsappProvider,
        )
        
        OtpHelper.requestOtp(config: configModelObject!, requestOtpModel: request) {
            
            result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    isOtpStep = true
                    otp = ""
                    isVerified = false
                }
            case .failure(let err):
                
                print(err)
            }
            
            
            
        }
        
        
        
    }
    
    private func resendOtp() {
        // same as sendOtp but without changing email
        sendOtp()
    }
    
    private func verifyOtp() {
        guard emailLooksValid(email) else { return }
        guard otp.count == otpSize else { return }
        
        verifying = true
        
        let configModelObject = ConfigModelObject.shared.get()
        
        let req = VerifyOtpRequestOtpModel(
            token: email.trimmingCharacters(in: .whitespacesAndNewlines),
            otp: otp,
            otpExpiryTime: expiryMinutes
        )
        
        OtpHelper.verifyOtp(config: configModelObject!, verifyOtpRequestOtpModel: req) {
            
            result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    verifying = false
                    if response {
                        isVerified = true
                        onValid()
                    } else {
                        isVerified = false
                    }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    isVerified = false
                }
                
            }
            
            
            
        }
    }
    
    // MARK: - Helpers (same as Kotlin)
    
    private func emailLooksValid(_ s: String) -> Bool {
        let x = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return x.contains("@") && x.contains(".") && x.count >= 5
    }
    
    private func otpMatchesType(_ value: String, otpType: Int) -> Bool {
        switch otpType {
        case 1: return value.allSatisfy { $0.isNumber }
        case 2: return value.allSatisfy { $0.isLetter || $0.isNumber }
        case 3: return value.allSatisfy { $0.isLetter }
        case 4: return value.allSatisfy { $0.isLetter || $0.isNumber }
        default: return true
        }
    }
    
    private func filterByOtpType(_ raw: String, otpType: Int) -> String {
        switch otpType {
        case 1: return raw.filter { $0.isNumber }
        case 2: return raw.filter { $0.isLetter || $0.isNumber }
        case 3: return raw.filter { $0.isLetter }
        case 4: return raw.filter { $0.isLetter || $0.isNumber }
        default: return raw
        }
    }
    
    private func otpKeyboardType(_ otpType: Int) -> UIKeyboardType {
        switch otpType {
        case 1: return .numberPad
        case 2: return .asciiCapable
        case 3: return .default
        case 4: return .asciiCapable
        default: return .asciiCapable
        }
    }
}

public struct ResendOtpControl: View {

    public let expiryMinutes: Double
    public let onResend: () -> Void

    @State private var remainingSeconds: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(expiryMinutes: Double, onResend: @escaping () -> Void) {
        self.expiryMinutes = expiryMinutes
        self.onResend = onResend
    }

    public var body: some View {
        Button {
            guard canResend else { return }

            onResend()
            resetTimer()
        } label: {
            Text(canResend ? FlowStrings.resendOtpReady : FlowStrings.resendIn(countdownLabel))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(BaseTheme.baseAccentColor))
        }
        .buttonStyle(.plain)
        .disabled(!canResend)
        .onAppear {
            resetTimer()
        }
        .onReceive(timer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
    }

    private var totalSeconds: Int {
        max(1, Int(expiryMinutes * 60))
    }

    private var canResend: Bool {
        remainingSeconds <= 0
    }

    private var countdownLabel: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func resetTimer() {
        remainingSeconds = totalSeconds
    }
}

// MARK: - Small helpers
fileprivate extension String {
    var isNotBlank: Bool { !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

fileprivate struct UIKitEmailTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    let isEnabled: Bool
    let onChange: (String) -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let tf = PaddedTextFieldEmail()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor(Color(BaseTheme.baseTextColor))
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        tf.font = .systemFont(ofSize: 16)
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.isEnabled = isEnabled
        if uiView.text != text { uiView.text = text }
        
        if isFirstResponder, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        else if !isFirstResponder, uiView.isFirstResponder { uiView.resignFirstResponder() }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFirstResponder: $isFirstResponder, onChange: onChange)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFirstResponder: Bool
        let onChange: (String) -> Void
        
        init(text: Binding<String>, isFirstResponder: Binding<Bool>, onChange: @escaping (String) -> Void) {
            self._text = text
            self._isFirstResponder = isFirstResponder
            self.onChange = onChange
        }
        
        @objc func editingChanged(_ sender: UITextField) {
            let v = sender.text ?? ""
            if text != v {
                text = v
                onChange(v)
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) { if !isFirstResponder { isFirstResponder = true } }
        func textFieldDidEndEditing(_ textField: UITextField) { if isFirstResponder { isFirstResponder = false } }
    }
}

fileprivate struct UIKitOtpTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    let isEnabled: Bool
    let keyboardType: UIKeyboardType
    var placeholder: String = "OTP"

    func makeUIView(context: Context) -> UITextField {
        let tf = PaddedTextFieldEmail()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor(Color(BaseTheme.baseTextColor))
        tf.keyboardType = keyboardType
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        tf.font = .systemFont(ofSize: 16)
        tf.placeholder = placeholder
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.keyboardType = keyboardType
        
        if uiView.text != text { uiView.text = text }
        
        if isFirstResponder, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        else if !isFirstResponder, uiView.isFirstResponder { uiView.resignFirstResponder() }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFirstResponder: $isFirstResponder)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFirstResponder: Bool
        
        init(text: Binding<String>, isFirstResponder: Binding<Bool>) {
            self._text = text
            self._isFirstResponder = isFirstResponder
        }
        
        @objc func editingChanged(_ sender: UITextField) {
            let v = sender.text ?? ""
            if text != v { text = v }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) { if !isFirstResponder { isFirstResponder = true } }
        func textFieldDidEndEditing(_ textField: UITextField) { if isFirstResponder { isFirstResponder = false } }
    }
}

public final class PaddedTextFieldEmail: UITextField {
    
    // MARK: - Padding
    public var textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        borderStyle = .none
        backgroundColor = .clear
        clipsToBounds = true
    }
    
    // MARK: - Text Rects
    
    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    public override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    public override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.clearButtonRect(forBounds: bounds)
        return rect.offsetBy(dx: -textInsets.right / 2, dy: 0)
    }
}

