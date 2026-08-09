import SwiftUI
import UIKit

public struct SecurePhoneInput: View {

    public let title: String
    public let options: [CountryOption]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (_ selectedDial: String, _ localNumber: String) -> Void

    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var expanded: Bool = false
    @State private var selectedIso2: String = ""
    @State private var selectedDial: String = ""
    @State private var localNumber: String = ""
    @State private var phoneRegex: String = ""
    @State private var err: String = ""
    @State private var searchText: String = ""
    @State private var userStartedTyping: Bool = false

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
        onValueChange: @escaping (_ selectedDial: String, _ localNumber: String) -> Void
    ) {
        self.title = title
        self.options = options
        self.page = page
        self._field = field
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.onValueChange = onValueChange

        if self.field.isHidden == true {
            setupDefaultsIfNeeded()
        }
    }

    public var body: some View {
        if self.field.isHidden == false {
            VStack(alignment: .leading, spacing: 6) {

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Color(BaseTheme.baseTextColor))

                HStack(alignment: .top, spacing: 8) {

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
                        isEnabled: !isReadOnly
                    ) { newValue in
                        localNumber = newValue.filter { $0.isNumber || $0 == " " || $0 == "-" }
                        handleValueChange()
                    }
                    .frame(height: 55)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(BaseTheme.fieldColor))
                    )
                }

                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: expanded)
            .onAppear {
                setupDefaultsIfNeeded()
                handleValueChange()
            }
            .onChange(of: selectedIso2) { _ in
                syncCountryChange()
            }
            .onChange(of: localNumber) { _ in
                handleValueChange()
            }
            .onChange(of: focusedFieldId) { newValue in
                if newValue != fieldId && expanded == false {
                    searchText = ""
                    userStartedTyping = false
                }
            }
            .fullScreenCover(isPresented: $expanded) {
                dialogView()
                    .presentationBackgroundClearIfAvailable()
            }
        }
    }

    private func codeButton() -> some View {
        HStack {
            Text(codeDisplay)
                .font(.system(size: 16))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

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
            focusedFieldId = fieldId
            guard !isReadOnly else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                expanded = true
                searchText = ""
                userStartedTyping = false
            }
        }
    }

    private var filteredOptions: [CountryOption] {
        if !userStartedTyping {
            return options
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return options
        }

        return options.filter { option in
            option.name.localizedCaseInsensitiveContains(trimmed) ||
            option.code2.localizedCaseInsensitiveContains(trimmed) ||
            option.code3.localizedCaseInsensitiveContains(trimmed) ||
            option.dialCode.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var dialogListHeight: CGFloat {
        let itemCount = max(filteredOptions.count, 1)
        let contentHeight = CGFloat(itemCount) * rowHeight
        return min(contentHeight, listMaxHeight)
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(BaseTheme.fieldColor))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(BaseTheme.fieldColor))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(BaseTheme.fieldColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color(BaseTheme.baseTextColor).opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                // consume taps inside dialog so background tap does not close it
            }
        }
    }

    @ViewBuilder
    private func dialogList() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredOptions.isEmpty {
                    HStack {
                        Text(FlowStrings.noResultsFound)
                            .font(.system(size: 15))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: rowHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(filteredOptions, id: \.self) { option in
                        let isSelected = option.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame

                        Button {
                            selectedIso2 = option.code2
                            selectedDial = option.dialCode
                            phoneRegex = option.phoneRegexPattern
                            applyRegex()
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if option != filteredOptions.last {
                            Divider()
                                .background(Color(BaseTheme.baseTextColor).opacity(0.10))
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: dialogListHeight)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            // consume taps inside list area
        }
    }

    private var isReadOnly: Bool {
        field.readOnly ?? false
    }

    private var codeDisplay: String {
        if let c = options.first(where: { $0.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame }) {
            return "\(flagEmoji(c.code2)) \(c.dialCode)"
        }
        return selectedDial.isEmpty ? "—" : selectedDial
    }

    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.15)) {
            expanded = false
            searchText = ""
            userStartedTyping = false
        }
    }

    private func syncCountryChange() {
        if let match = options.first(where: { $0.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame }) {
            selectedDial = match.dialCode
            phoneRegex = match.phoneRegexPattern
            applyRegex()
        }
        handleValueChange()
    }

    private func setupDefaultsIfNeeded() {
        let rawDefault = (field.defaultCountryCode ?? "").uppercased()
        selectedIso2 = options.first(where: { $0.dialCode.uppercased() == rawDefault })?.code2 ?? rawDefault
        selectedDial = options.first(where: { $0.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame })?.dialCode ?? ""

        if let key = field.inputKey {
            let raw = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""
            localNumber = raw.filter { $0.isNumber }
        }

        if let c = options.first(where: { $0.code2.caseInsensitiveCompare(selectedIso2) == .orderedSame }) {
            phoneRegex = c.phoneRegexPattern
            applyRegex()
        }
    }

    private func applyRegex() {
        guard let key = field.inputKey else { return }
        AssistedFormHelper.changeRegex(key, phoneRegex, selectedDial, page)
    }

    private func handleValueChange() {
        onValueChange(selectedDial, localNumber)
        validate()
    }

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}

 struct UIKitPhoneTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    let isEnabled: Bool
    let onChange: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = PaddedTextFieldPhone()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor(Color(BaseTheme.baseTextColor))
        tf.keyboardType = .phonePad
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)

        tf.font = .systemFont(ofSize: 16)
        tf.adjustsFontSizeToFitWidth = true
        tf.minimumFontSize = 11
        tf.textAlignment = .left

        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.textAlignment = BaseTheme.baseUiLanguage == UiLanguage.Arabic ? .right : .left

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
            let newValue = sender.text ?? ""
            if text != newValue {
                text = newValue
                onChange(newValue)
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !isFirstResponder {
                isFirstResponder = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if isFirstResponder {
                isFirstResponder = false
            }
        }
    }
}

public final class PaddedTextFieldPhone: UITextField {

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

    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    public override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    public override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.clearButtonRect(forBounds: bounds)
        return rect.offsetBy(dx: -textInsets.right / 2, dy: 0)
    }
}
