import SwiftUI
import UIKit

public struct SecurePhoneWithOtpField: View {

    public let title: String
    public let options: [CountryOption]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement

    public let onValueChange: (String) -> Void
    public let onRegxChange: (String, String) -> Void
    public let onValid: () -> Void

    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var expanded = false
    @State private var selectedIso2 = "LB"
    @State private var selectedDial = "+961"
    @State private var phoneRegex = ""

    @State private var localNumber = ""
    @State private var otp = ""

    @State private var isOtpStep = false
    @State private var isVerified = false
    @State private var verifying = false

    @State private var errToShow = ""
    @State private var searchText = ""
    @State private var userStartedTyping = false
    @State private var didSetup = false

    private let rowHeight: CGFloat = 52
    private let listMaxHeight: CGFloat = 320

    public init(
        title: String,
        options: [CountryOption],
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        onValueChange: @escaping (String) -> Void,
        onRegxChange: @escaping (String, String) -> Void,
        onValid: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.page = page
        self._field = field
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.onValueChange = onValueChange
        self.onRegxChange = onRegxChange
        self.onValid = onValid
    }

    public var body: some View {
        if field.isHidden == false {
            VStack(alignment: .leading, spacing: 6) {

                Text(headerTitle)
                    .font(.system(size: 16))
                    .foregroundColor(Color(BaseTheme.baseTextColor))

                if !isOtpStep {
                    phoneRow()
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
                setupOnce()
            }
            .fullScreenCover(isPresented: $expanded) {
                dialogView()
                    .presentationBackgroundClearIfAvailable()
            }
        }
    }

    private var headerTitle: String {
        (!isOtpStep || isVerified) ? title : FlowStrings.enterOtp
    }

    private var otpSize: Int {
        Int(field.otpSize ?? 8)
    }

    private var otpFormat: Int {
        Int(field.otpFormat ?? 1)
    }

    private var expiryMinutes: Double {
        field.otpExpiryTime ?? 1.0
    }

    private var isReadOnly: Bool {
        field.readOnly ?? false
    }

    private var e164Phone: String {
        buildE164(localNumber, selectedDial: selectedDial)
    }

    private var codeDisplay: String {
        if let c = options.first(where: { $0.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame }) {
            return "\(flagEmoji(c.code2)) \(c.dialCode)"
        }

        return selectedDial
    }

    private func setupOnce() {
        guard !didSetup else { return }
        didSetup = true

        if let lebanon = options.first(where: { $0.code2.uppercased() == "LB" }) {
            selectedIso2 = lebanon.code2
            selectedDial = lebanon.dialCode
            phoneRegex = lebanon.phoneRegexPattern
        }

        syncInitialPhone()
        recomputePhoneError()
    }

    private func syncInitialPhone() {
        guard let existing = field.value, !existing.isEmpty else { return }

        let digits = existing.filter { $0.isNumber }
        let dialDigits = selectedDial.filter { $0.isNumber }

        if !dialDigits.isEmpty, digits.hasPrefix(dialDigits) {
            localNumber = String(digits.dropFirst(dialDigits.count))
        } else {
            localNumber = digits
        }
    }

    @ViewBuilder
    private func phoneRow() -> some View {
        HStack(spacing: 10) {

            codeButton()
                .frame(width: 140)

            UIKitPhoneTextField(
                text: $localNumber,
                isFirstResponder: Binding(
                    get: { focusedFieldId == fieldId },
                    set: { newValue in
                        if newValue {
                            focusedFieldId = fieldId
                        } else if focusedFieldId == fieldId {
                            focusedFieldId = nil
                        }
                    }
                ),
                isEnabled: !isReadOnly,
                onChange: { raw in
                    let clean = raw.filter { $0.isNumber || $0 == " " || $0 == "-" }

                    if localNumber != clean {
                        localNumber = clean
                    }

                    let full = buildE164(clean, selectedDial: selectedDial)

                    field.value = full
                    onValueChange(full)
                    recomputePhoneError()
                }
            )
            .frame(height: 55)
            .overlay(alignment: .trailing) {
                if phoneLooksValid(localNumber) {
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
                    .padding(.trailing, 6)
                    .disabled(isReadOnly)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(BaseTheme.fieldColor))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                focusedFieldId = fieldId
            }
        }
    }

    private func codeButton() -> some View {
        HStack {
            Text(codeDisplay)
                .font(.system(size: 16))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.8))
        }
        .padding(.horizontal, 12)
        .frame(height: 55)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isReadOnly else { return }

            focusedFieldId = nil
            expanded = true
            searchText = ""
            userStartedTyping = false
        }
    }

    @ViewBuilder
    private func otpField() -> some View {
        UIKitOtpTextFieldPhone(
            text: Binding(
                get: { isVerified ? e164Phone : otp },
                set: { raw in
                    guard !isVerified else { return }

                    let filtered = filterByOtpType(raw, otpType: otpFormat)
                    otp = String(filtered.prefix(otpSize))

                    if otp.count == otpSize, otpMatchesType(otp, otpType: otpFormat) {
                        verifyOtp()
                    }
                }
            ),
            isFirstResponder: Binding(
                get: { focusedFieldId == fieldId },
                set: { newValue in
                    if newValue {
                        focusedFieldId = fieldId
                    } else if focusedFieldId == fieldId {
                        focusedFieldId = nil
                    }
                }
            ),
            isEnabled: !isReadOnly && !isVerified,
            keyboardType: otpKeyboardType(otpFormat),
            placeholder: FlowStrings.otpPlaceholder(size: otpSize)
        )
        .padding(.horizontal, 14)
        .frame(height: 55)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(BaseTheme.fieldColor))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusedFieldId = fieldId
        }
    }

    @ViewBuilder
    private func otpFooter() -> some View {
        HStack {
            if isVerified {
                Text(FlowStrings.verifiedSuccessfully)
                    .font(.system(size: 12))
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
            } else if !verifying {
                ResendOtpControl(expiryMinutes: expiryMinutes) {
                    resendOtp()
                }
            }

            Spacer()
        }
        .padding(.top, 6)
    }

    private var filteredOptions: [CountryOption] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !userStartedTyping || trimmed.isEmpty {
            return options
        }

        return options.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.code2.localizedCaseInsensitiveContains(trimmed) ||
            $0.code3.localizedCaseInsensitiveContains(trimmed) ||
            $0.dialCode.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var dialogListHeight: CGFloat {
        min(CGFloat(max(filteredOptions.count, 1)) * rowHeight, listMaxHeight)
    }

    @ViewBuilder
    private func dialogView() -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    closeDialog()
                }

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))

                    Spacer()

                    Button {
                        closeDialog()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color(BaseTheme.fieldColor)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.7))

                    TextField(
                        "",
                        text: Binding(
                            get: { searchText },
                            set: {
                                searchText = $0
                                userStartedTyping = true
                            }
                        ),
                        prompt: Text(FlowStrings.search)
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.45))
                    )
                    .textFieldStyle(.plain)
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .accentColor(Color(BaseTheme.baseAccentColor))
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(BaseTheme.fieldColor))
                )
                .padding(.horizontal, 16)

                dialogList()

                Button {
                    closeDialog()
                } label: {
                    Text(FlowStrings.close)
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(BaseTheme.fieldColor))
                        )
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(BaseTheme.fieldColor))
            )
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func dialogList() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredOptions.isEmpty {
                    Text(FlowStrings.noResultsFound)
                        .font(.system(size: 15))
                        .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.7))
                        .frame(height: rowHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                } else {
                    ForEach(filteredOptions, id: \.self) { option in
                        let isSelected = option.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame

                        Button {
                            selectedIso2 = option.code2
                            selectedDial = option.dialCode
                            phoneRegex = option.phoneRegexPattern

                            let full = buildE164(localNumber, selectedDial: selectedDial)

                            field.value = full

                            //onRegxChange(phoneRegex, selectedDial)
                            onValueChange(full)

                            recomputePhoneError()
                            closeDialog()
                        } label: {
                            HStack(spacing: 10) {
                                Text(flagEmoji(option.code2))

                                Text(option.dialCode)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(BaseTheme.baseTextColor))

                                Text(option.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(BaseTheme.baseTextColor))
                                    .lineLimit(1)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(BaseTheme.baseAccentColor))
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(height: dialogListHeight)
        .padding(.horizontal, 16)
    }

    private func closeDialog() {
        expanded = false
        searchText = ""
        userStartedTyping = false
        focusedFieldId = nil
    }

    private func recomputePhoneError() {
        if localNumber.isNotBlank, !phoneLooksValid(localNumber) {
            errToShow = FlowStrings.pleaseEnterValidPhone
        } else {
            errToShow = ""
        }
    }

    private func phoneLooksValid(_ local: String) -> Bool {
        let digits = local.filter { $0.isNumber }

        guard !digits.isEmpty else { return false }

        if phoneRegex.isEmpty {
            return true
        }

        guard let regex = try? NSRegularExpression(pattern: phoneRegex) else {
            return true
        }

        let range = NSRange(location: 0, length: digits.utf16.count)
        return regex.firstMatch(in: digits, options: [], range: range) != nil
    }

    private func sendOtp() {
        guard phoneLooksValid(localNumber) else {
            recomputePhoneError()
            return
        }

        guard !isReadOnly else { return }
        guard let config = ConfigModelObject.shared.get() else { return }

        let request = RequestOtpModel(
            token: e164Phone,
            inputType: field.inputType,
            otpSize: otpSize,
            otpType: field.otpType ?? 1,
            otpExpiryTime: expiryMinutes,
            otpFormat: field.otpFormat ?? 1,
            smsProvider: field.smsProvider,
            whatsappProvider: field.whatsappProvider
        )

        OtpHelper.requestOtp(config: config, requestOtpModel: request) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    isOtpStep = true
                    otp = ""
                    isVerified = false
                    errToShow = ""

                case .failure(let err):
                    errToShow = err.localizedDescription
                }
            }
        }
    }

    private func resendOtp() {
        sendOtp()
    }

    private func verifyOtp() {
        guard phoneLooksValid(localNumber) else { return }
        guard otp.count == otpSize else { return }
        guard let config = ConfigModelObject.shared.get() else { return }

        verifying = true

        let req = VerifyOtpRequestOtpModel(
            token: e164Phone,
            otp: otp,
            otpExpiryTime: expiryMinutes
        )

        OtpHelper.verifyOtp(config: config, verifyOtpRequestOtpModel: req) { result in
            DispatchQueue.main.async {
                verifying = false

                switch result {
                case .success(let ok):
                    if ok {
                        isVerified = true
                        errToShow = ""
                        onValid()
                    } else {
                        isVerified = false
                        errToShow = FlowStrings.invalidOtp
                    }

                case .failure(let err):
                    isVerified = false
                    errToShow = err.localizedDescription
                }
            }
        }
    }

    private func otpMatchesType(_ value: String, otpType: Int) -> Bool {
        switch otpType {
        case 1:
            return value.allSatisfy { $0.isNumber }
        case 2, 4:
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        case 3:
            return value.allSatisfy { $0.isLetter }
        default:
            return true
        }
    }

    private func filterByOtpType(_ raw: String, otpType: Int) -> String {
        switch otpType {
        case 1:
            return raw.filter { $0.isNumber }
        case 2, 4:
            return raw.filter { $0.isLetter || $0.isNumber }
        case 3:
            return raw.filter { $0.isLetter }
        default:
            return raw
        }
    }

    private func otpKeyboardType(_ otpType: Int) -> UIKeyboardType {
        switch otpType {
        case 1:
            return .numberPad
        case 2, 4:
            return .asciiCapable
        case 3:
            return .default
        default:
            return .asciiCapable
        }
    }
}

fileprivate func buildE164(_ local: String, selectedDial: String) -> String {
    let digits = local.filter { $0.isNumber }
    let normalized = digits.hasPrefix("0") ? String(digits.dropFirst(1)) : digits
    return selectedDial + normalized
}

fileprivate extension String {
    var isNotBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct UIKitOtpTextFieldPhone: UIViewRepresentable {

    @Binding var text: String
    @Binding var isFirstResponder: Bool

    let isEnabled: Bool
    let keyboardType: UIKeyboardType
    var placeholder: String = "OTP"

    func makeUIView(context: Context) -> UITextField {
        let tf = PaddedTextFieldPhone()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor(Color(BaseTheme.baseTextColor))
        tf.keyboardType = keyboardType
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.delegate = context.coordinator
        tf.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged),
            for: .editingChanged
        )
        tf.font = .systemFont(ofSize: 16)
        tf.placeholder = placeholder
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.keyboardType = keyboardType

        if uiView.text != text {
            uiView.text = text
        }

        if isFirstResponder, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
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
            let value = sender.text ?? ""
            if text != value {
                text = value
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFirstResponder = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFirstResponder = false
        }
    }
}
