import SwiftUI
import Combine
import UIKit

public struct SecureDropdownWithDataSource: View {
    
    public let title: String
    public let page: Int
    public let flowController: FlowController
    
    @Binding public var field: DataEntryPageElement
    
    public let onValueChange: ([DataSourceAttribute], [String: String]) -> Void
    
    @Binding public var focusedFieldId: String?
    public let fieldId: String
    
    @State private var dataSourceData: DataSourceData? = nil
    @State private var isLoading: Bool = false
    
    @State private var selected: [DataSourceAttribute] = []
    @State private var err: String = ""
    @State private var expanded: Bool = false
    @State private var searchText: String = ""
    @State private var userStartedTyping: Bool = false
    @State private var cancellable: AnyCancellable?
    @State private var filterKeyValues: [String:String] = [:]

    private let rowHeight: CGFloat = 52
    private let listMaxHeight: CGFloat = 320
    
    public init(
        title: String,
        page: Int,
        field: Binding<DataEntryPageElement>,
        flowController: FlowController,
        focusedFieldId: Binding<String?>,
        fieldId: String,
        onValueChange: @escaping ([DataSourceAttribute], [String: String]) -> Void
    ) {
        self.title = title
        self.page = page
        self._field = field
        self.flowController = flowController
        self._focusedFieldId = focusedFieldId
        self.fieldId = fieldId
        self.onValueChange = onValueChange
        
        if self.field.isHidden == true {
            loadDataSourceAndSelectDefault()
        }
    }
    
    public var body: some View {
        if self.field.isHidden == false {
            VStack(alignment: .leading, spacing: 6) {
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                
                if isLoading && dataSourceData == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(BaseTheme.baseTextColor)))
                        .scaleEffect(1.0)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(BaseTheme.fieldColor))
                        )
                } else {
                    HStack(spacing: 10) {
                        Text(displayValueForSelected())
                            .font(.system(size: 16))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: 8)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.8))
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
                        guard dataSourceData != nil else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expanded = true
                            searchText = ""
                            userStartedTyping = false
                        }
                    }
                }
                
                if !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
            }
            .onAppear {
                validate()
                loadDataSourceAndSelectDefault()
                cancellable = FilterManager.shared.trigger
                       .sink {
                           let newfilterKeyValues = AssistedFormHelper.getFilterValue(dataSourceData: dataSourceData)
                           if(newfilterKeyValues != filterKeyValues){
                               self.filterKeyValues = newfilterKeyValues;
                               self.dataSourceData = nil
                               self.selected = []
                               loadDataSourceAndSelectDefault()
                           }
                }
                
            }
            .onChange(of: field.inputKey) { _ in
                loadDataSourceAndSelectDefault(force: true)
            }
            .onChange(of: field.languageTransformation) { _ in
                loadDataSourceAndSelectDefault(force: true)
            }
            .onChange(of: focusedFieldId) { newValue in
                if newValue != fieldId {
                    expanded = false
                    searchText = ""
                    userStartedTyping = false
                }
            }
            .onChange(of: selectedDisplayValue()) { _ in
                validate()
            }
            .fullScreenCover(isPresented: $expanded) {
                dialogView()
                    .presentationBackgroundClearIfAvailable()
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
    
    private func displayValueForSelected() -> String {
        let v = selectedDisplayValue()
        return v.isEmpty ? " " : v
    }
    
    private func selectedDisplayValue() -> String {
        selected.first(where: { $0.mappedKey == "Display Value" })?.value ?? ""
    }
    
    private func itemDisplayValue(_ item: DataSourceItem) -> String {
        item.dataSourceAttributes.first(where: { $0.mappedKey == "Display Value" })?.value ?? ""
    }
    
    private var filteredItems: [DataSourceItem] {
        guard let items = dataSourceData?.items else { return [] }
        
        if !userStartedTyping {
            return items
        }
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return items
        }
        
        return items.filter { item in
            itemDisplayValue(item).localizedCaseInsensitiveContains(trimmed)
        }
    }
    
    private var dialogListHeight: CGFloat {
        let itemCount = max(filteredItems.count, 1)
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
                
                if isLoading && dataSourceData == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(BaseTheme.baseTextColor)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                } else if dataSourceData != nil {
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
                    
                    dialogList(items: filteredItems)
                } else {
                    Text(FlowStrings.noDataAvailable)
                        .font(.system(size: 15))
                        .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .padding(.horizontal, 16)
                }
                
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
    }
    
    @ViewBuilder
    private func dialogList(items: [DataSourceItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if items.isEmpty {
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
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        let optionText = itemDisplayValue(item)
                        
                        Button {
                            selectItem(item)
                            closeDialog()
                        } label: {
                            HStack {
                                Text(optionText)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(BaseTheme.baseTextColor))
                                
                                Spacer()
                                
                                if optionText == selectedDisplayValue() {
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
                        
                        if idx < items.count - 1 {
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
    }
    
    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.15)) {
            expanded = false
            searchText = ""
            userStartedTyping = false
        }
    }
    
    private func selectItem(_ item: DataSourceItem) {
        guard let ds = dataSourceData else { return }
        guard let key = field.inputKey else { return }
        
        selected = item.dataSourceAttributes
        
        AssistedFormHelper.changeValueSecureDropdownWithDataSource(
            key: key,
            dataSourceAttribute: selected,
            outputKeys: ds.outputKeys,
            page: page
        )
        
        onValueChange(selected, ds.outputKeys)
        validate()
    }
    
    private func loadDataSourceAndSelectDefault(force: Bool = false) {
        guard let key = field.inputKey, !key.isEmpty else { return }
        guard let endpointId = field.endpointId else { return }
        
        if isLoading && !force { return }
        
        isLoading = true
        
        let config = ConfigModelObject.shared.get()
        let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId ?? 0
        
        AssistedFormHelper.getDataSourceValues(
            apiKey: ApiKeyObject.shared.get()!,
            config: config!,
            elementIdentifier: field.elementIdentifier,
            stepId: stepId,
            endpointId: endpointId,
            filterKeyValues : filterKeyValues
        ) { result in
            
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let data = response.data {
                        self.dataSourceData = data
                    }
                    
                    guard let ds = self.dataSourceData else { return }
                    
                    let defaultRaw = AssistedFormHelper.getDefaultValueValue(
                        key,
                        self.page,
                        flowController: self.flowController
                    ) ?? ""
                    
                    let langEnum = self.field.languageTransformation ?? 0
                    if langEnum == 0 {
                        if let matched = self.findItemByDisplayValue(ds: ds, display: defaultRaw) {
                            self.selected = matched.dataSourceAttributes
                            if !self.selected.isEmpty {
                                self.onValueChange(self.selected, ds.outputKeys)
                            }
                        }
                        self.validate()
                        return
                    }
                    
                    guard
                        let targetLang = self.field.targetOutputLanguage,
                        !targetLang.isEmpty
                    else {
                        if let matched = self.findItemByDisplayValue(ds: ds, display: defaultRaw) {
                            self.selected = matched.dataSourceAttributes
                            if !self.selected.isEmpty {
                                self.onValueChange(self.selected, ds.outputKeys)
                            }
                        }
                        self.validate()
                        return
                    }
                    
                    if self.selected.isEmpty || force {
                        let dataList = [
                            LanguageTransformationModel(
                                languageTransformationEnum: langEnum,
                                key: key,
                                value: defaultRaw,
                                language: targetLang,
                                dataType: self.field.inputType
                            )
                        ]
                        
                        AssistedFormHelper.valueTransformation(
                            language: targetLang,
                            transformationModel: TransformationModel(languageTransformationModels: dataList)
                        ) { tData in
                            DispatchQueue.main.async {
                                let finalDisplay = tData?.value ?? defaultRaw
                                
                                if let matched = self.findItemByDisplayValue(ds: ds, display: finalDisplay) {
                                    self.selected = matched.dataSourceAttributes
                                } else if let fallback = self.findItemByDisplayValue(ds: ds, display: defaultRaw) {
                                    self.selected = fallback.dataSourceAttributes
                                }
                                
                                if !self.selected.isEmpty, let inputKey = self.field.inputKey {
                                    AssistedFormHelper.changeValueSecureDropdownWithDataSource(
                                        key: inputKey,
                                        dataSourceAttribute: self.selected,
                                        outputKeys: ds.outputKeys,
                                        page: self.page
                                    )
                                    self.onValueChange(self.selected, ds.outputKeys)
                                }
                                
                                self.validate()
                            }
                        }
                    } else {
                        self.validate()
                    }
                }
                
            case .failure(let err):
                DispatchQueue.main.async {
                    self.isLoading = false
                    print(err)
                }
            }
        }
    }
    
    private func findItemByDisplayValue(ds: DataSourceData, display: String) -> DataSourceItem? {
        ds.items.first { item in
            itemDisplayValue(item).caseInsensitiveCompare(display) == .orderedSame
        }
    }
    
    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}
