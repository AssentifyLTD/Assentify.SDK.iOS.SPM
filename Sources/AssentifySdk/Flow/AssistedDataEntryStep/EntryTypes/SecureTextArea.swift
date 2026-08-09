import SwiftUI
import UIKit

public struct SecureTextArea: View {

    public let title: String
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (String) -> Void

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
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.onValueChange = onValueChange
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
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(BaseTheme.fieldColor))
                    
                    UIKitTextView(
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
                        isEnabled: !((field.readOnly ?? false) || ( getIsLocked())),
                        textColor: UIColor(Color(BaseTheme.baseTextColor))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .frame(height: textAreaHeight)
                .contentShape(Rectangle())
                .onTapGesture { focusedFieldId = fieldId }
                
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
                
            }
            .onAppear {
                if let existing = field.value, !existing.isEmpty {
                    value = existing
                }
                loadDefaultIfNeeded()
            }
            .onChange(of: field.value) { newValue in
                let v = newValue ?? ""
                if v != value { value = v }
            }
            .onChange(of: field.inputKey) { _ in loadDefaultIfNeeded(force: true) }
            .onChange(of: field.languageTransformation) { _ in loadDefaultIfNeeded(force: true) }
        }
    }

    
    private func getIsLocked()->Bool{
        let identifiers = field.inputPropertyIdentifierList ?? []
        return field.isLocked! && !identifiers.isEmpty
    }
    
    private var textAreaHeight: CGFloat {
        let rows = max(1, field.sizeByRows ?? 3)
        let rowHeight: CGFloat = 22
        let verticalPadding: CGFloat = 20
        return CGFloat(rows) * rowHeight + verticalPadding
    }

    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force && !value.isEmpty { return }

        if let existing = field.value, !existing.isEmpty, !force {
            value = existing
            validate()
            return
        }

        let defaultValue = AssistedFormHelper.getDefaultValueValue(
            key, page, flowController: flowController
        ) ?? ""

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

// MARK: - UIKit TextView (keeps keyboard open)
fileprivate struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    let isEnabled: Bool
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = textColor
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.delegate = context.coordinator
        tv.isScrollEnabled = true
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEnabled

        if uiView.text != text {
            uiView.text = text
        }

        // ✅ keep first responder stable
        if isFirstResponder, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFirstResponder: $isFirstResponder)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var isFirstResponder: Bool

        init(text: Binding<String>, isFirstResponder: Binding<Bool>) {
            self._text = text
            self._isFirstResponder = isFirstResponder
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !isFirstResponder { isFirstResponder = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if isFirstResponder { isFirstResponder = false }
        }

        func textViewDidChange(_ textView: UITextView) {
            let newValue = textView.text ?? ""
            if text != newValue {
                text = newValue
            }
        }
    }
}
