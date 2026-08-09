import SwiftUI

public struct SecureCheckboxGroup: View {

    public let title: String
    public let options: [String]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: ([String]) -> Void

    @State private var selected: Set<String> = []
    @State private var err: String = ""

    public init(
        title: String,
        options: [String],
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        onValueChange: @escaping ([String]) -> Void
    ) {
        self.title = title
        self.options = options
        self.page = page
        self._field = field
        self.flowController = flowController
        self.onValueChange = onValueChange
    }

    public var body: some View {
        if field.isHidden == false {
            VStack(alignment: .leading, spacing: 6) {

                // MARK: - Title
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))

                // MARK: - Options container
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        let isChecked = selected.contains(option)

                        HStack(alignment: .top, spacing: 6) {

                            // Checkbox box
                            Button(action: { handleToggle(option: option) }) {
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

                            // Label
                            Text(option)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(BaseTheme.baseTextColor))
                                .lineLimit(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                                .padding(.horizontal, 3)
                                .onTapGesture { handleToggle(option: option) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) // 👈 pinned to leading
                        .padding(.vertical, 4)

                        // Divider between items (not after last)
                        if option != options.last {
                            Divider()
                                .padding(.leading, 48)
                                .foregroundColor(Color(BaseTheme.fieldColor).opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(BaseTheme.fieldColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Error
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
            }
            .onAppear {
                loadDefaultIfNeeded()
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .onChange(of: field.value) { newValue in
                let parsed = parseSelected(newValue)
                if parsed != selected { selected = parsed }
            }
            .onChange(of: selected) { _ in
                validate()
            }
        }
    }

    // MARK: - Toggle handler

    private func handleToggle(option: String) {
        guard !getIsLocked() else { return }
        if selected.contains(option) {
            selected.remove(option)
        } else {
            selected.insert(option)
        }
        let joined = selected.joined(separator: ",")
        field.value = joined
        if let key = field.inputKey {
            AssistedFormHelper.changeValue(key, joined, page)
        }
        onValueChange(Array(selected))
        validate()
    }

    // MARK: - Lock check

    private func getIsLocked() -> Bool {
        let identifiers = field.inputPropertyIdentifierList ?? []
        return (field.isLocked ?? false) && !identifiers.isEmpty
    }

    // MARK: - Default loader

    private func loadDefaultIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force, let existing = field.value, !existing.isEmpty {
            selected = parseSelected(existing)
            onValueChange(Array(selected))
            validate()
            return
        }

        let raw = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""
        selected = parseSelected(raw)
        field.value = raw
        AssistedFormHelper.changeValue(key, raw, page)
        onValueChange(Array(selected))
        validate()
    }

    // MARK: - Parse comma-separated string → Set

    private func parseSelected(_ raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    // MARK: - Validate

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}
