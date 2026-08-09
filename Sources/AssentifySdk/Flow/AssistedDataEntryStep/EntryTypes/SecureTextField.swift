import SwiftUI
import UIKit

public struct SecureTextField: View {

    public let title: String
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement

    public let onValueChange: (String) -> Void

    // ✅ focus support from pager
    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var value: String = ""
    @State private var err: String = ""

    public init(
        title: String,
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        onValueChange: @escaping (String) -> Void
    ) {
        self.title = title
        self.page = page
        self._field = field
        self.onValueChange = onValueChange
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        if (self.field.isHidden == true){
            loadDefaultIfNeeded()
        }
    }

    public var body: some View {
        if (self.field.isHidden == false){
            
            VStack(alignment: .leading, spacing: 6) {
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                
                UIKitTextField(
                    text: Binding(
                        get: { value },
                        set: { newValue in
                            // ✅ SAME LOGIC AS YOU HAD
                            value = newValue
                            field.value = newValue
                            
                            if let key = field.inputKey {
                                AssistedFormHelper.changeValue(key, newValue, page)
                            }
                            
                            onValueChange(newValue)
                            validate()
                        }
                    ),
                    isFirstResponder: Binding(
                        get: { focusedFieldId == fieldId },
                        set: { newValue in
                            if newValue { focusedFieldId = fieldId }
                            else if focusedFieldId == fieldId { focusedFieldId = nil }
                        }
                    ),
                    isEnabled: !((field.readOnly ?? false) || getIsLocked()),
                    textColor: UIColor(Color(BaseTheme.baseTextColor))
                ) .frame(maxWidth: .infinity)
                    .padding(.horizontal, 1)
                    .frame(height: 55)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(BaseTheme.fieldColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedFieldId = fieldId
                    }
                
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
                
            }
            .onAppear {
                // ✅ important: sync from field.value to local state
                if let existing = field.value, !existing.isEmpty {
                    value = existing
                }
                loadDefaultIfNeeded()
            }
            .onChange(of: field.value) {  newValue in
                // ✅ keep sync (prevents SwiftUI recreation weirdness)
                let v = newValue ?? ""
                if v != value {
                    value = v
                }
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .onChange(of: field.languageTransformation) { _ in
                loadDefaultIfNeeded(force: true)
            }
        }
    }
    
    private func getIsLocked()->Bool{
        let identifiers = field.inputPropertyIdentifierList ?? []
        return field.isLocked! && !identifiers.isEmpty
    }

    // MARK: - Default + Transformation (same as you)
    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force && !value.isEmpty { return }

        if let existing = field.value, !existing.isEmpty, !force {
            value = existing
            validate()
            return
        }

        let defaultValue = AssistedFormHelper.getDefaultValueValue(key, page, flowController: self.flowController) ?? ""

        let langEnum = field.languageTransformation ?? 0
        if langEnum == 0 {
            value = defaultValue
            field.value = defaultValue
            AssistedFormHelper.changeValue(key, defaultValue, page)
            validate()
            return
        }

        if value.isEmpty {
            guard let targetLang = field.targetOutputLanguage, !targetLang.isEmpty else {
                value = defaultValue
                field.value = defaultValue
                AssistedFormHelper.changeValue(key, defaultValue, page)
                validate()
                return
            }

            let dataList = [
                LanguageTransformationModel(
                    languageTransformationEnum: langEnum,
                    key: key,
                    value: defaultValue,
                    language: targetLang,
                    dataType: field.inputType
                )
            ]

            AssistedFormHelper.valueTransformation(
                language: targetLang,
                transformationModel: TransformationModel(languageTransformationModels: dataList)
            ) { data in
                DispatchQueue.main.async {
                    if let data {
                        self.value = data.value
                        self.field.value = data.value
                        AssistedFormHelper.changeValue(key, data.value, self.page)
                    } else {
                        self.value = defaultValue
                        self.field.value = defaultValue
                        AssistedFormHelper.changeValue(key, defaultValue, self.page)
                    }
                    self.validate()
                }
            }
        }
    }

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}

fileprivate struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    let isEnabled: Bool
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextField {
        let tf = PaddedTextField()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = textColor
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)

        // ✅ FIX: make long text fit inside the container
        tf.font = .systemFont(ofSize: 16)
        tf.adjustsFontSizeToFitWidth = true
        tf.minimumFontSize = 11

        // ✅ keep it one line
        tf.textAlignment = BaseTheme.baseUiLanguage == UiLanguage.Arabic ? .right : .left

        // ✅ Helps SwiftUI sizing not fight UIKit
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.textColor = textColor
        uiView.textAlignment = BaseTheme.baseUiLanguage == UiLanguage.Arabic ? .right : .left

        if uiView.text != text {
            uiView.text = text
        }

        // ✅ maintain first responder
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
            let newValue = sender.text ?? ""
            if text != newValue {
                text = newValue
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !isFirstResponder { isFirstResponder = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if isFirstResponder { isFirstResponder = false }
        }
    }
}

// ✅ Adds left/right padding so text doesn't collide with your rounded background
fileprivate final class PaddedTextField: UITextField {
    var horizontalPadding: CGFloat = 10

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }
}
