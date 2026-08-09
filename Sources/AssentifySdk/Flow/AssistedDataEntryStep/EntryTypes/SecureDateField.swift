import SwiftUI
import UIKit

public struct SecureDateField: View {

    public let title: String
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onDateChange: (String) -> Void

    // ✅ focus support from pager (same pattern as SecureTextField)
    @Binding public var focusedFieldId: String?
    public let fieldId: String

    public let dateFormat: String

    @State private var value: String = ""
    @State private var err: String = ""

    @State private var showPicker: Bool = false
    @State private var tempDate: Date = Date()
    @State private var isLocked: Bool = false

    public init(
        title: String,
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        dateFormat: String = "dd/MM/yyyy",
        onDateChange: @escaping (String) -> Void
    ) {
        self.title = title
        self.page = page
        self._field = field
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.dateFormat = dateFormat
        self.onDateChange = onDateChange
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
                
                ZStack {
                    // read-only display (same look as text field container)
                    HStack(spacing: 10) {
                        Text(value.isEmpty ? " " : value)
                            .font(.system(size: 16))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: 8)
                        
                        Button {
                            openPickerIfAllowed()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(Color(BaseTheme.baseAccentColor))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canPick)
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
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
                    openPickerIfAllowed()
                }
                
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
                
            }
            .onAppear {
                // ✅ sync from field.value
                if let existing = field.value, !existing.isEmpty {
                    value = existing
                }
                loadDefaultIfNeeded()
                validate()
                
            }
            .onChange(of: field.value) { newValue in
                let v = newValue ?? ""
                if v != value {
                    value = v
                    validate()
                }
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .sheet(isPresented: $showPicker) {
                datePickerSheet()
            }
        }
    }

    // MARK: - Derived
    private var canPick: Bool {
        !((field.readOnly ?? false) || (getIsLocked()))
    }

    // MARK: - Default value
    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force && !value.isEmpty { return }

        if let existing = field.value, !existing.isEmpty, !force {
            value = existing
            validate()
            return
        }

        let defaultValue = AssistedFormHelper.getDefaultValueValue(key, page, flowController: self.flowController) ?? ""

        value = defaultValue
        field.value = defaultValue
        AssistedFormHelper.changeValue(key, defaultValue, page)
        validate()
    }
    
    private func getIsLocked()->Bool{
        let identifiers = field.inputPropertyIdentifierList ?? []
        return field.isLocked! && !identifiers.isEmpty
    }

    // MARK: - Validation
    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }

    // MARK: - Picker open / persist
    private func openPickerIfAllowed() {
        guard canPick else { return }
        focusedFieldId = fieldId

        // init tempDate from current string, otherwise today (clamped)
        let current = parseDate(value, pattern: dateFormat) ?? Date()
        tempDate = clamp(current, min: minDate, max: maxDate)

        showPicker = true
    }

    private func persist(_ newValue: String) {
        guard let key = field.inputKey else { return }

        value = newValue
        field.value = newValue
        AssistedFormHelper.changeValue(key, newValue, page)

        validate()
        onDateChange(newValue)
    }

    // MARK: - Sheet UI
    @ViewBuilder
    private func datePickerSheet() -> some View {
        NavigationView {
            VStack(spacing: 16) {

                DatePicker(
                    "",
                    selection: Binding(
                        get: { tempDate },
                        set: { newDate in
                            tempDate = clamp(newDate, min: minDate, max: maxDate)
                        }
                    ),
                    in: (minDate ?? Date.distantPast)...(maxDate ?? Date.distantFuture),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                .tint(Color(BaseTheme.baseAccentColor))

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FlowStrings.cancel) {
                        showPicker = false
                    }
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(FlowStrings.ok) {
                        let s = formatDate(tempDate, pattern: dateFormat)
                        persist(s)
                        showPicker = false
                    }
                    .foregroundColor(Color(BaseTheme.baseAccentColor))
                }
            }
        }
    }
    
 
    // 27/02/2026
    private var minDate: Date? {
        guard let s = field.from, !s.isEmpty else { return nil }
        return parseDate(s, pattern: dateFormat)
    }

    private var maxDate: Date? {
        guard let s = field.to, !s.isEmpty else { return nil }
        return parseDate(s, pattern: dateFormat)
    }

    // MARK: - Date helpers (UTC like your Kotlin)
    private func makeFormatter(pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = pattern
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0) // ✅ UTC
        return f
    }

    private func parseDate(_ s: String, pattern: String) -> Date? {
        makeFormatter(pattern: pattern).date(from: s)
    }

    private func formatDate(_ d: Date, pattern: String) -> String {
        makeFormatter(pattern: pattern).string(from: d)
    }

    private func clamp(_ date: Date, min: Date?, max: Date?) -> Date {
        var d = date
        if let min, d < min { d = min }
        if let max, d > max { d = max }
        return d
    }
}
