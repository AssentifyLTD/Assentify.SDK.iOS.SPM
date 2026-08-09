import SwiftUI
import Combine

public struct AssistedDataEntryPager: View {
    
    @Binding private var model: AssistedDataEntryModel
    @Binding private var currentPage: Int
    private let onFieldChanged: () -> Void
    public let flowController: FlowController
    
    @State private var focusedFieldId: String?
    
    public init(
        model: Binding<AssistedDataEntryModel>,
        currentPage: Binding<Int>,
        flowController: FlowController,
        onFieldChanged: @escaping () -> Void
    ) {
        self._model = model
        self._currentPage = currentPage
        self.flowController = flowController
        self.onFieldChanged = onFieldChanged
    }
    
    public var body: some View {
        TabView(selection: $currentPage) {
            ForEach(model.assistedDataEntryPages.indices, id: \.self) { pageIndex in
                AssistedDataEntrySinglePage(
                    model: $model,
                    pageIndex: pageIndex,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    onFieldChanged: onFieldChanged
                )
                .tag(pageIndex)
                .background(DisablePagingScrollView())
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - Single Page (split to reduce compiler load)
fileprivate struct AssistedDataEntrySinglePage: View {
    
    @Binding var model: AssistedDataEntryModel
    let pageIndex: Int
    let flowController: FlowController
    @Binding var focusedFieldId: String?
    let onFieldChanged: () -> Void
    
    var body: some View {
        let page = model.assistedDataEntryPages[pageIndex]
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                
                if page.title != nil &&
                   page.subTitle != nil &&
                   page.svgLogoUrl != nil {
                    VStack(spacing: 5) {
                        HStack {
                            Spacer()
                            LogoSvgUrl(url: page.svgLogoUrl ?? "")
                                .frame(width: 70, height: 70)
                            Spacer()
                        }
                        Text(page.title ?? "")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 20)

                        Text(page.subTitle ?? "")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 20)
                    }
                }else{
                    Text(page.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                
            
                
                AssistedDataEntryFieldsList(
                    model: $model,
                    pageIndex: pageIndex,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    onFieldChanged: onFieldChanged
                )
                
                Color.clear.frame(height: 320)
            }
            .padding(.horizontal, 25)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .tapToDismissKeyboard(focusedFieldId: $focusedFieldId)
        .modifier(ScrollDismissNeverIfAvailable())
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Fields List (split again)
fileprivate struct AssistedDataEntryFieldsList: View {
    
    @Binding var model: AssistedDataEntryModel
    let pageIndex: Int
    let flowController: FlowController
    @Binding var focusedFieldId: String?
    let onFieldChanged: () -> Void
    
    var body: some View {
        // important: use indices -> avoids searching firstIndex(where:) per item
        let elements = model.assistedDataEntryPages[pageIndex].dataEntryPageElements
        
        VStack(spacing: 20) {
            ForEach(elements.indices, id: \.self) { i in
                AssistedDataEntryFieldRow(
                    pageIndex: pageIndex,
                    element: elements[i],
                    elementBinding: $model.assistedDataEntryPages[pageIndex].dataEntryPageElements[i],
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    onFieldChanged: onFieldChanged
                ).padding(.top , 7)
            }
        }
    }
}

// MARK: - Field Row (smallest piece)
fileprivate struct AssistedDataEntryFieldRow: View {
    
    let pageIndex: Int
    let element: DataEntryPageElement
    @Binding var elementBinding: DataEntryPageElement
    
    let flowController: FlowController
    @Binding var focusedFieldId: String?
    let onFieldChanged: () -> Void
    
    var body: some View {
        let type = InputTypes.fromString(element.inputType)
        let fieldId = element.elementIdentifier // ✅ this is the id you intended
        
        Group {
            switch type {
            case .text, .email:
                SecureTextField(
                    title: element.textTitle ?? "",
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onValueChange: { new in
                        guard let key = element.inputKey else { return }
                        
                        AssistedFormHelper.changeValue(key, new, pageIndex)
                        
                        
                        onFieldChanged()
                    }
                )
                .keyboardType(type == .email ? .emailAddress : .default)
                .textInputAutocapitalization(type == .email ? .never : .sentences)
                .autocorrectionDisabled(type == .email)
                
            case .textArea:
                SecureTextArea(
                    title: element.textTitle ?? "",
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onValueChange: { new in
                        guard let key = element.inputKey else { return }
                        
                        AssistedFormHelper.changeValue(key, new, pageIndex)
                        
                        
                        onFieldChanged()
                    }
                )
            case.date:
                SecureDateField(
                    title: element.textTitle ?? "",
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onDateChange: { new in
                        guard let key = element.inputKey else { return }
                        
                        AssistedFormHelper.changeValue(key, new, pageIndex)
                        
                        
                        onFieldChanged()
                    }
                )
                
            case .dropDown:
                if (element.endpointId != nil) {
                    SecureDropdownWithDataSource(
                        title: element.textTitle ?? "",
                        page: pageIndex,
                        field: $elementBinding,
                        flowController: flowController,
                        focusedFieldId: $focusedFieldId,
                        fieldId: fieldId,
                        onValueChange: { new, outputKeys in
                            guard let key = element.inputKey else { return }
                            
                            AssistedFormHelper.changeValueSecureDropdownWithDataSource(
                                key: key,
                                dataSourceAttribute: new,
                                outputKeys: outputKeys,
                                page: pageIndex
                            )
                            
                            onFieldChanged()
                            FilterManager.shared.updateFilter();
                        }
                    )
                }else{
                    SecureDropdown(
                        title: element.textTitle ?? "",
                        options: element.dataSourceContent?
                            .split(separator: ",")
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        ?? [],
                        page: pageIndex,
                        field: $elementBinding,
                        flowController: flowController,
                        focusedFieldId: $focusedFieldId,
                        fieldId: fieldId,
                        onValueChange: { new in
                            guard let key = element.inputKey else { return }
                            
                            AssistedFormHelper.changeValue(key, new, pageIndex)
                            
                            
                            onFieldChanged()
                        }
                    )
                }
                
            case .radioButtonGroup :
                SecureRadioGroup(
                    title: element.textTitle ?? "",
                    options: element.dataSourceContent?
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    ?? [],
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onValueChange: { new in
                        guard let key = element.inputKey else { return }

                        AssistedFormHelper.changeValue(key, new, pageIndex)
                        

                        onFieldChanged()
                    }
                )
                
            case .nationality:
                SecureNationalityDropdown(
                    title: element.textTitle ?? "",
                    options: allCountries,
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                ){ iso3 in
                    guard let key = element.inputKey else { return }

                    AssistedFormHelper.changeValue(key, iso3, pageIndex)
                    onFieldChanged()
                }
            case .phoneNumber:
                SecurePhoneInput(
                    title: element.textTitle ?? "",
                    options: allCountries,
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                ){ selectedDial ,localNumber in
                    guard let key = element.inputKey else { return }

                    AssistedFormHelper.changeValue(key, localNumber, pageIndex)
                    onFieldChanged()
                }
                
            case .emailWithOTP:
                SecureEmailWithOtpField(
                    title: element.textTitle ?? "",
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onValueChange: { newEmail in
                        guard let key = element.inputKey else { return }

                        AssistedFormHelper.changeValue(key, newEmail, pageIndex)
                        onFieldChanged()
                            onFieldChanged()
                        },
                        onValid: {
                            guard let key = element.inputKey else { return }

                            AssistedFormHelper.changeLocalOtpValid(key, true, pageIndex)
                            onFieldChanged()
                        }
                )
                
            case .phoneNumberWithOTP :
                SecurePhoneWithOtpField(
                    title: element.textTitle ?? "",
                    options: allCountries,
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    focusedFieldId: $focusedFieldId,
                    fieldId: fieldId,
                    onValueChange: { newPhone in
                        guard let key = element.inputKey else { return }

                        AssistedFormHelper.changeValue(key, newPhone, pageIndex)
                        onFieldChanged()
                            onFieldChanged()
                    }, onRegxChange : {phoneRegex,selectedDial in

                        guard let key = element.inputKey else { return }
                        AssistedFormHelper.changeRegex(key, phoneRegex, selectedDial, pageIndex)

                    },
                    
                        onValid: {
                            guard let key = element.inputKey else { return }

                            AssistedFormHelper.changeLocalOtpValid(key, true, pageIndex)
                            onFieldChanged()
                        }
                )
            case .checkbox:
                SecureCheckbox(
                    title: element.textTitle ?? "",
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    onValueChange: { new in
                        guard let key = element.inputKey else { return }
                        
                        AssistedFormHelper.changeValue(key, String(new), pageIndex)
                        
                        
                        onFieldChanged()
                    }
                )
            case .checkboxGroup:
                SecureCheckboxGroup(
                    title: element.textTitle ?? "",
                    options: element.dataSourceContent?
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    ?? [],
                    page: pageIndex,
                    field: $elementBinding,
                    flowController: flowController,
                    onValueChange: { new in
                        let result = new.joined(separator: ",")

                        guard let key = element.inputKey else { return }

                        AssistedFormHelper.changeValue(key, result, pageIndex)
                        

                        onFieldChanged()
                    }
                )
            default:
                EmptyView()
            }
        }
        .id(fieldId)
    }
}

// MARK: - Disable TabView Paging Scroll
struct DisablePagingScrollView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        DispatchQueue.main.async {
            var s: UIView? = v.superview
            while let view = s {
                if let scroll = view as? UIScrollView, scroll.isPagingEnabled {
                    scroll.isScrollEnabled = false
                    break
                }
                s = view.superview
            }
        }
        return v
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - iOS16+ keyboard dismiss (no iOS16 types exposed)
fileprivate struct ScrollDismissNeverIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.never)
        } else {
            content
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

fileprivate struct TapToDismissKeyboard: ViewModifier {
    @Binding var focusedFieldId: String?
    
    func body(content: Content) -> some View {
        content
        // tap anywhere in empty space
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedFieldId = nil
                    UIApplication.shared.endEditing()
                }
            )
    }
}

fileprivate extension View {
    func tapToDismissKeyboard(focusedFieldId: Binding<String?>) -> some View {
        modifier(TapToDismissKeyboard(focusedFieldId: focusedFieldId))
    }
}
