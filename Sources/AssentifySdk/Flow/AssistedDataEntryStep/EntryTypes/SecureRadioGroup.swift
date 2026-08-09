import SwiftUI
import UIKit

public struct SecureRadioGroup: View {

    public let title: String
    public let options: [String]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (String) -> Void

    // ✅ focus support from pager (optional but keeps behavior consistent)
    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var selected: String = ""
    @State private var err: String = ""

    public init(
        title: String,
        options: [String],
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        onValueChange: @escaping (String) -> Void
    ) {
        self.title = title
        self.options = options
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
                
                VStack(spacing: 0) {
                    
                    ForEach(options.indices, id: \.self) { idx in
                        let option = options[idx]
                        let isSelected = (selected == option)
                        
                        Button {
                            guard !isReadOnly else { return }
                            focusedFieldId = fieldId
                            select(option)
                        } label: {
                            HStack(spacing: 10) {
                                
                                RadioIndicator(isSelected: isSelected)
                                
                                Text(option)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(
                                        isReadOnly
                                        ? Color(BaseTheme.baseTextColor).opacity(0.6)
                                        : Color(BaseTheme.baseTextColor)
                                    )
                                    .lineLimit(2)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(BaseTheme.fieldColor))
                        }
                        .buttonStyle(.plain)
                        .disabled(isReadOnly)
                        
                        if idx < options.count - 1 {
                            Divider()
                                .background(Color(BaseTheme.baseTextColor).opacity(0.10))
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(BaseTheme.fieldColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(BaseTheme.baseTextColor).opacity(0.06), lineWidth: 1)
                )
                
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
                
            }
            .onAppear {
                syncFromField()
                loadDefaultIfNeeded()
                validate()
            }
            .onChange(of: field.value) { _ in
                syncFromField()
                validate()
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
        }
        
    }

    // MARK: - Derived
    private var isReadOnly: Bool {
        (field.readOnly ?? false)
    }

    // MARK: - Sync / Default / Persist
    private func syncFromField() {
        let v = field.value ?? ""
        if !v.isEmpty, v != selected {
            selected = v
        }
    }

    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }
        if !force && !selected.isEmpty { return }

        if let existing = field.value, !existing.isEmpty, !force {
            selected = existing
            validate()
            return
        }

        let defaultValue = AssistedFormHelper.getDefaultValueValue(
            key,
            page,
            flowController: self.flowController
        ) ?? ""

        // only set if still empty or force
        if selected.isEmpty || force {
            select(defaultValue)
        }
    }

    private func select(_ option: String) {
        guard let key = field.inputKey else { return }

        selected = option
        field.value = option

        AssistedFormHelper.changeValue(key, option, page)

        onValueChange(option)
        validate()
    }

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}

// MARK: - Radio Indicator (custom)
fileprivate struct RadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected
                    ? Color(BaseTheme.baseAccentColor)
                    : Color(BaseTheme.baseTextColor).opacity(0.6),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(Color(BaseTheme.baseAccentColor))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 26, height: 26)
    }
}
