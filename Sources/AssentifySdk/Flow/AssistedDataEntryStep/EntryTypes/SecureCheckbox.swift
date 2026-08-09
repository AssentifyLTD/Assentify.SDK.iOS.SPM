import SwiftUI

public struct SecureCheckbox: View {

    public let title: String
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (Bool) -> Void

    @State private var isChecked: Bool = false

    public init(
        title: String,
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        onValueChange: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.page = page
        self._field = field
        self.flowController = flowController
        self.onValueChange = onValueChange
    }

    public var body: some View {
        if field.isHidden == false {
            HStack(alignment: .top, spacing: 6) {

                // MARK: - Checkbox box
                Button(action: handleToggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                isChecked
                                    ? Color(BaseTheme.baseAccentColor)
                                    : Color(BaseTheme.baseTextColor).opacity(0.8),
                                lineWidth: 2
                            )
                            .frame(width: 22, height: 22)

                        if isChecked {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(BaseTheme.baseAccentColor))
                                .frame(width: 22, height: 22)

                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(getIsLocked())
                .opacity(getIsLocked() ? 0.4 : 1.0)
                .padding(.top, 2)

                // MARK: - Label
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .padding(.horizontal, 3)
                    .onTapGesture { handleToggle() }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) // 👈 pinned to leading
            .onAppear {
                loadDefaultIfNeeded()
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .onChange(of: field.value) { newValue in
                let parsed = parseBool(newValue)
                if parsed != isChecked {
                    isChecked = parsed
                }
            }
        }
    }

    // MARK: - Toggle handler

    private func handleToggle() {
        guard !getIsLocked() else { return }
        isChecked.toggle()
        let stringValue = isChecked ? "true" : "false"
        field.value = stringValue
        if let key = field.inputKey {
            AssistedFormHelper.changeValue(key, stringValue, page)
        }
        onValueChange(isChecked)
    }

    // MARK: - Lock check

    private func getIsLocked() -> Bool {
        let identifiers = field.inputPropertyIdentifierList ?? []
        return (field.isLocked ?? false) && !identifiers.isEmpty
    }

    // MARK: - Default value loader

    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force, let existing = field.value, !existing.isEmpty {
            isChecked = parseBool(existing)
            onValueChange(isChecked)
            return
        }

        let raw = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""
        let defaultBool = parseBool(raw.isEmpty ? nil : raw)

        isChecked = defaultBool
        field.value = defaultBool ? "true" : "false"
        AssistedFormHelper.changeValue(key, field.value ?? "false", page)
        onValueChange(isChecked)
    }

    // MARK: - Bool parser

    private func parseBool(_ raw: String?) -> Bool {
        return raw?.trimmingCharacters(in: .whitespaces).lowercased() == "true"
    }
}
