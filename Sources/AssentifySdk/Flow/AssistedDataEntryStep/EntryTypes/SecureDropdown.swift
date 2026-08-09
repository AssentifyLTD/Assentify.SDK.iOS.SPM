import SwiftUI
import UIKit

public struct SecureDropdown: View {

    public let title: String
    public let options: [String]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (String) -> Void

    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var selected: String = ""
    @State private var err: String = ""
    @State private var expanded: Bool = false
    @State private var searchText: String = ""
    @State private var userStartedTyping: Bool = false

    private let rowHeight: CGFloat = 52
    private let listMaxHeight: CGFloat = 320

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

        if self.field.isHidden == true {
            loadDefaultIfNeeded()
        }
    }

    public var body: some View {
        if self.field.isHidden == false {
            ZStack {
                VStack(alignment: .leading, spacing: 6) {

                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseTextColor))

                    HStack(spacing: 10) {
                        Text(selected.isEmpty ? " " : selected)
                            .font(.system(size: 16))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.8))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.15), value: expanded)
                    }
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
                        guard !isReadOnly else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expanded = true
                            searchText = ""
                            userStartedTyping = false
                        }
                    }

                    if !err.isEmpty {
                        Text(err)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(BaseTheme.baseRedColor))
                    }
                }
                .zIndex(0)
            }
            .onAppear {
                if let existing = field.value, !existing.isEmpty {
                    selected = existing
                }
                loadDefaultIfNeeded()
                validate()
            }
            .onChange(of: field.value) { newValue in
                let v = newValue ?? ""
                if v != selected {
                    selected = v
                    validate()
                }
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .onChange(of: field.languageTransformation) { _ in
                loadDefaultIfNeeded(force: true)
            }
            .onChange(of: focusedFieldId) { newValue in
                if newValue != fieldId {
                    expanded = false
                    searchText = ""
                    userStartedTyping = false
                }
            }
            .fullScreenCover(isPresented: $expanded) {
                dialogView()
            }
        }
    }

    private var isReadOnly: Bool {
        (field.readOnly ?? false) || getIsLocked()
    }

    private func getIsLocked() -> Bool {
        let identifiers = field.inputPropertyIdentifierList ?? []
        return (field.isLocked ?? false) && !identifiers.isEmpty
    }

    private var filteredOptions: [String] {
        if !userStartedTyping {
            return options
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return options
        }

        return options.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
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
                            ForEach(filteredOptions.indices, id: \.self) { idx in
                                let option = filteredOptions[idx]

                                Button {
                                    applyAndPersist(option)
                                    closeDialog()
                                } label: {
                                    HStack {
                                        Text(option)
                                            .font(.system(size: 15))
                                            .foregroundColor(Color(BaseTheme.baseTextColor))

                                        Spacer()

                                        if option == selected {
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

                                if idx < filteredOptions.count - 1 {
                                    Divider()
                                        .background(Color(BaseTheme.baseTextColor).opacity(0.10))
                                        .padding(.leading, 14)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(height: dialogListHeight)

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
        }
        .presentationBackgroundClearIfAvailable()
    }

    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.15)) {
            expanded = false
            searchText = ""
            userStartedTyping = false
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

        let langEnum = field.languageTransformation ?? 0
        if langEnum == 0 {
            applyAndPersist(defaultValue)
            return
        }

        guard let targetLang = field.targetOutputLanguage, !targetLang.isEmpty else {
            applyAndPersist(defaultValue)
            return
        }

        if selected.isEmpty || force {
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
                        self.applyAndPersist(data.value)
                    } else {
                        self.applyAndPersist(defaultValue)
                    }
                }
            }
        }
    }

    private func applyAndPersist(_ newValue: String) {
        guard let key = field.inputKey else { return }
        selected = newValue
        field.value = newValue
        AssistedFormHelper.changeValue(key, newValue, page)
        onValueChange(newValue)
        validate()
    }

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}

fileprivate struct PresentationBackgroundClearIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}

extension View {
    func presentationBackgroundClearIfAvailable() -> some View {
        self.modifier(PresentationBackgroundClearIfAvailable())
    }
}
