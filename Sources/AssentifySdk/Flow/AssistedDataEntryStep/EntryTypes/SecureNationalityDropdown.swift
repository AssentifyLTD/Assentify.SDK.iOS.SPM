import SwiftUI
import UIKit
import Foundation

public struct SecureNationalityDropdown: View {

    public let title: String
    public let options: [CountryOption]
    public let page: Int
    public let flowController: FlowController

    @Binding public var field: DataEntryPageElement
    public let onValueChange: (String) -> Void

    @Binding public var focusedFieldId: String?
    public let fieldId: String

    @State private var defaultRaw: String = ""
    @State private var selectedCode: String = ""
    @State private var err: String = ""
    @State private var expanded: Bool = false
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
            loadDefaultRawIfNeeded()
        }
    }

    public var body: some View {
        if self.field.isHidden == false {
            VStack(alignment: .leading, spacing: 6) {

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseTextColor))

                HStack(spacing: 10) {
                    Text(displayText.isEmpty ? " " : displayText)
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
            .onAppear {
                loadDefaultRawIfNeeded()
                validate()
            }
            .onChange(of: field.inputKey) { _ in
                loadDefaultRawIfNeeded(force: true)
            }
            .onChange(of: field.languageTransformation) { _ in
                loadDefaultRawIfNeeded(force: true)
            }
            .onChange(of: selectedCode) { _ in
                validate()
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

    private var selectedCountry: CountryOption? {
        options.first(where: { $0.code3.caseInsensitiveCompare(selectedCode) == .orderedSame })
    }

    private var displayText: String {
        guard let c = selectedCountry else { return "" }
        return "\(flagEmoji(c.code2))  \(c.name)"
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

    private func computeDefaultCode(from rawValue: String) -> String {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "" }

        if let c = options.first(where: { $0.code3.compare(raw, options: .caseInsensitive) == .orderedSame }) {
            return c.code3
        }
        if let c = options.first(where: { $0.name.compare(raw, options: .caseInsensitive) == .orderedSame }) {
            return c.code3
        }
        if let c = options.first(where: { $0.name.range(of: raw, options: .caseInsensitive) != nil }) {
            return c.code3
        }
        if let c = options.first(where: { $0.code3.range(of: raw, options: .caseInsensitive) != nil }) {
            return c.code3
        }
        return ""
    }

    private func loadDefaultRawIfNeeded(force: Bool = false) {
        guard let key = field.inputKey else { return }

        if !force && !defaultRaw.isEmpty { return }

        let langEnum = field.languageTransformation ?? 0

        if langEnum == 0 {
            defaultRaw = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""
            let code = computeDefaultCode(from: defaultRaw)
            if !code.isEmpty {
                selectedCode = code.uppercased()
                onValueChange(selectedCode)
            }
            return
        }

        guard let targetLang = field.targetOutputLanguage, !targetLang.isEmpty else {
            defaultRaw = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""
            let code = computeDefaultCode(from: defaultRaw)
            if !code.isEmpty {
                selectedCode = code.uppercased()
                onValueChange(selectedCode)
            }
            return
        }

        let defaultValue = AssistedFormHelper.getDefaultValueValue(key, page, flowController: flowController) ?? ""

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
                    self.defaultRaw = data.value
                    AssistedFormHelper.changeValue(key, data.value, self.page)
                } else {
                    self.defaultRaw = defaultValue
                }

                let code = self.computeDefaultCode(from: self.defaultRaw)
                if !code.isEmpty {
                    self.selectedCode = code.uppercased()
                    self.onValueChange(self.selectedCode)
                }

                self.validate()
            }
        }
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
                    ForEach(filteredOptions.indices, id: \.self) { idx in
                        let option = filteredOptions[idx]
                        let optionText = "\(flagEmoji(option.code2))  \(option.name)"
                        let isSelected = option.code3.caseInsensitiveCompare(selectedCode) == .orderedSame

                        Button {
                            selectedCode = option.code3.uppercased()
                            onValueChange(selectedCode)
                            closeDialog()
                        } label: {
                            HStack {
                                Text(optionText)
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

    private func validate() {
        guard let key = field.inputKey else { return }
        err = AssistedFormHelper.validateField(key, page) ?? ""
    }
}






public func flagEmoji(_ iso2: String) -> String {
    let code = iso2.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard code.count == 2 else { return "🏳" }

    let base: UInt32 = 0x1F1E6 // 'A' regional indicator

    guard
        let first = code.unicodeScalars.first,
        let second = code.unicodeScalars.dropFirst().first,
        first.value >= 65, first.value <= 90,   // 'A'...'Z'
        second.value >= 65, second.value <= 90
    else { return "🏳" }

    let a = base + (first.value - 65)
    let b = base + (second.value - 65)

    guard let scalarA = UnicodeScalar(a), let scalarB = UnicodeScalar(b) else { return "🏳" }

    return String(Character(scalarA)) + String(Character(scalarB))
}

public struct CountryOption: Hashable, Codable {
    public let code3: String      // ISO3 e.g. "USA"
    public let code2: String      // ISO2 e.g. "US"
    public let name: String
    public let dialCode: String
    public let phoneRegexPattern: String

    public init(_ code3: String, _ code2: String, _ name: String, _ dialCode: String, _ phoneRegexPattern: String) {
        self.code3 = code3
        self.code2 = code2
        self.name = name
        self.dialCode = dialCode
        self.phoneRegexPattern = phoneRegexPattern
    }
}

// Optional helper if you want to validate phone later
public extension CountryOption {
    func isPhoneValid(_ phone: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: phoneRegexPattern)
            let range = NSRange(phone.startIndex..., in: phone)
            return regex.firstMatch(in: phone, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

public let allCountries: [CountryOption] = [
    // North America
    CountryOption("USA", "US", "United States", "+1", "^[2-9][0-9]{9}$"),
    CountryOption("CAN", "CA", "Canada", "+1", "^[2-9][0-9]{9}$"),
    CountryOption("MEX", "MX", "Mexico", "+52", "^[1-9]\\d{9,10}$"),

    // Central America & Caribbean
    CountryOption("GTM", "GT", "Guatemala", "+502", "^[2-9]\\d{7}$"),
    CountryOption("HND", "HN", "Honduras", "+504", "^[3-9]\\d{7}$"),
    CountryOption("SLV", "SV", "El Salvador", "+503", "^[67]\\d{7}$"),
    CountryOption("NIC", "NI", "Nicaragua", "+505", "^[58]\\d{7}$"),
    CountryOption("CRI", "CR", "Costa Rica", "+506", "^[5-8]\\d{7}$"),
    CountryOption("PAN", "PA", "Panama", "+507", "^[6-7]\\d{7}$"),
    CountryOption("DOM", "DO", "Dominican Republic", "+1-809", "^[2-9]\\d{7}$"),
    CountryOption("HTI", "HT", "Haiti", "+509", "^[34]\\d{7}$"),
    CountryOption("JAM", "JM", "Jamaica", "+1-876", "^[2-9]\\d{7}$"),
    CountryOption("PRI", "PR", "Puerto Rico", "+1-787", "^[2-9]\\d{7}$"),
    CountryOption("CUB", "CU", "Cuba", "+53", "^5\\d{7}$"),

    // South America
    CountryOption("BRA", "BR", "Brazil", "+55", "^[1-9]\\d{9,10}$"),
    CountryOption("ARG", "AR", "Argentina", "+54", "^\\d{10}$"),
    CountryOption("COL", "CO", "Colombia", "+57", "^3\\d{9}$"),
    CountryOption("PER", "PE", "Peru", "+51", "^9\\d{8}$"),
    CountryOption("CHL", "CL", "Chile", "+56", "^[2-9]\\d{8}$"),
    CountryOption("ECU", "EC", "Ecuador", "+593", "^9\\d{8}$"),
    CountryOption("VEN", "VE", "Venezuela", "+58", "^4\\d{9}$"),
    CountryOption("BOL", "BO", "Bolivia", "+591", "^[67]\\d{7}$"),
    CountryOption("PRY", "PY", "Paraguay", "+595", "^9\\d{8}$"),
    CountryOption("URY", "UY", "Uruguay", "+598", "^9\\d{7}$"),

    // Europe
    CountryOption("GBR", "GB", "United Kingdom", "+44", "^\\d{10,11}$"),
    CountryOption("DEU", "DE", "Germany", "+49", "^\\d{10,12}$"),
    CountryOption("FRA", "FR", "France", "+33", "^[1-9]\\d{8}$"),
    CountryOption("ITA", "IT", "Italy", "+39", "^[3-9]\\d{8,10}$"),
    CountryOption("ESP", "ES", "Spain", "+34", "^[6-9]\\d{8}$"),
    CountryOption("PRT", "PT", "Portugal", "+351", "^9\\d{8}$"),
    CountryOption("NLD", "NL", "Netherlands", "+31", "^[6-9]\\d{8}$"),
    CountryOption("BEL", "BE", "Belgium", "+32", "^4\\d{8}$"),
    CountryOption("CHE", "CH", "Switzerland", "+41", "^(7|4)\\d{8}$"),
    CountryOption("AUT", "AT", "Austria", "+43", "^[6-9]\\d{8,9}$"),
    CountryOption("SWE", "SE", "Sweden", "+46", "^[1-9]\\d{6,9}$"),
    CountryOption("NOR", "NO", "Norway", "+47", "^\\d{8}$"),
    CountryOption("DNK", "DK", "Denmark", "+45", "^\\d{8}$"),
    CountryOption("FIN", "FI", "Finland", "+358", "^[4-5]\\d{8}$"),
    CountryOption("POL", "PL", "Poland", "+48", "^[5-8]\\d{8}$"),
    CountryOption("RUS", "RU", "Russia", "+7", "^9\\d{9}$"),
    CountryOption("UKR", "UA", "Ukraine", "+380", "^[3-9]\\d{8}$"),
    CountryOption("IRL", "IE", "Ireland", "+353", "^[8-9]\\d{8}$"),
    CountryOption("GRC", "GR", "Greece", "+30", "^6\\d{9}$"),
    CountryOption("CZE", "CZ", "Czech Republic", "+420", "^[6-7]\\d{8}$"),
    CountryOption("ROU", "RO", "Romania", "+40", "^7\\d{8}$"),
    CountryOption("HUN", "HU", "Hungary", "+36", "^[2-9]\\d{8}$"),
    CountryOption("BGR", "BG", "Bulgaria", "+359", "^[6789]\\d{8}$"),
    CountryOption("SRB", "RS", "Serbia", "+381", "^6\\d{7,8}$"),
    CountryOption("HRV", "HR", "Croatia", "+385", "^9\\d{8}$"),
    CountryOption("SVK", "SK", "Slovakia", "+421", "^9\\d{8}$"),
    CountryOption("SVN", "SI", "Slovenia", "+386", "^[3-7]\\d{7}$"),
    CountryOption("BLR", "BY", "Belarus", "+375", "^[2-9]\\d{8}$"),
    CountryOption("LTU", "LT", "Lithuania", "+370", "^6\\d{7}$"),
    CountryOption("LVA", "LV", "Latvia", "+371", "^2\\d{7}$"),
    CountryOption("EST", "EE", "Estonia", "+372", "^[5-9]\\d{7}$"),
    CountryOption("ALB", "AL", "Albania", "+355", "^6\\d{7}$"),
    CountryOption("MKD", "MK", "North Macedonia", "+389", "^7\\d{7}$"),
    CountryOption("BIH", "BA", "Bosnia and Herzegovina", "+387", "^6\\d{7}$"),
    CountryOption("MLT", "MT", "Malta", "+356", "^[79]\\d{7}$"),
    CountryOption("ISL", "IS", "Iceland", "+354", "^\\d{7}$"),
    CountryOption("LUX", "LU", "Luxembourg", "+352", "^[24-9]\\d{7}$"),

    // Middle East
    CountryOption("SAU", "SA", "Saudi Arabia", "+966", "^5\\d{8}$"),
    CountryOption("ARE", "AE", "United Arab Emirates", "+971", "^5\\d{8}$"),
    CountryOption("TUR", "TR", "Turkey", "+90", "^5\\d{9}$"),
    CountryOption("IRN", "IR", "Iran", "+98", "^9\\d{9}$"),
    CountryOption("IRQ", "IQ", "Iraq", "+964", "^7[3-9]\\d{8}$"),
    CountryOption("JOR", "JO", "Jordan", "+962", "^7\\d{8}$"),
    CountryOption("LBN", "LB", "Lebanon", "+961", "^(03|70|71|76|78|79|81)\\d{6}$"),
    CountryOption("KWT", "KW", "Kuwait", "+965", "^[569]\\d{7}$"),
    CountryOption("QAT", "QA", "Qatar", "+974", "^3\\d{7}$"),
    CountryOption("OMN", "OM", "Oman", "+968", "^(9|7)\\d{7}$"),
    CountryOption("BHR", "BH", "Bahrain", "+973", "^3\\d{7}$"),
    CountryOption("YEM", "YE", "Yemen", "+967", "^7\\d{8}$"),
    CountryOption("SYR", "SY", "Syria", "+963", "^9\\d{8}$"),

    // Africa
    CountryOption("EGY", "EG", "Egypt", "+20", "^1\\d{8,9}$"),
    CountryOption("ZAF", "ZA", "South Africa", "+27", "^[6-8]\\d{8}$"),
    CountryOption("NGA", "NG", "Nigeria", "+234", "^\\d{7,10}$"),
    CountryOption("KEN", "KE", "Kenya", "+254", "^(7|1)\\d{8}$"),
    CountryOption("ETH", "ET", "Ethiopia", "+251", "^9\\d{8}$"),
    CountryOption("GHA", "GH", "Ghana", "+233", "^[235]\\d{8}$"),
    CountryOption("TZA", "TZ", "Tanzania", "+255", "^[67]\\d{8}$"),
    CountryOption("UGA", "UG", "Uganda", "+256", "^[7]\\d{8}$"),
    CountryOption("DZA", "DZ", "Algeria", "+213", "^[5-7]\\d{8}$"),
    CountryOption("MAR", "MA", "Morocco", "+212", "^[5-9]\\d{8}$"),
    CountryOption("TUN", "TN", "Tunisia", "+216", "^[2459]\\d{7}$"),
    CountryOption("LBY", "LY", "Libya", "+218", "^9[1-9]\\d{7}$"),
    CountryOption("SDN", "SD", "Sudan", "+249", "^9\\d{8}$"),
    CountryOption("SEN", "SN", "Senegal", "+221", "^7\\d{8}$"),
    CountryOption("CIV", "CI", "Ivory Coast", "+225", "^[0-9]\\d{9}$"),
    CountryOption("CMR", "CM", "Cameroon", "+237", "^[236-9]\\d{7}$"),
    CountryOption("AGO", "AO", "Angola", "+244", "^9\\d{8}$"),
    CountryOption("MOZ", "MZ", "Mozambique", "+258", "^8[2-9]\\d{7}$"),
    CountryOption("ZMB", "ZM", "Zambia", "+260", "^9\\d{8}$"),
    CountryOption("ZWE", "ZW", "Zimbabwe", "+263", "^7\\d{8}$"),
    CountryOption("MWI", "MW", "Malawi", "+265", "^[1789]\\d{7}$"),
    CountryOption("RWA", "RW", "Rwanda", "+250", "^7\\d{8}$"),
    CountryOption("BDI", "BI", "Burundi", "+257", "^[79]\\d{7}$"),

    // Asia
    CountryOption("CHN", "CN", "China", "+86", "^1\\d{10}$"),
    CountryOption("IND", "IN", "India", "+91", "^[6-9]\\d{9}$"),
    CountryOption("PAK", "PK", "Pakistan", "+92", "^3\\d{9}$"),
    CountryOption("IDN", "ID", "Indonesia", "+62", "^8\\d{8,11}$"),
    CountryOption("JPN", "JP", "Japan", "+81", "^(70|80|90)\\d{8}$"),
    CountryOption("PHL", "PH", "Philippines", "+63", "^9\\d{9}$"),
    CountryOption("VNM", "VN", "Vietnam", "+84", "^(3|5|7|8|9)\\d{8}$"),
    CountryOption("THA", "TH", "Thailand", "+66", "^[689]\\d{8}$"),
    CountryOption("MYS", "MY", "Malaysia", "+60", "^1\\d{8,9}$"),
    CountryOption("SGP", "SG", "Singapore", "+65", "^[689]\\d{7}$"),
    CountryOption("KOR", "KR", "South Korea", "+82", "^1\\d{9}$"),
    CountryOption("BGD", "BD", "Bangladesh", "+880", "^1[3-9]\\d{8}$"),
    CountryOption("AFG", "AF", "Afghanistan", "+93", "^7\\d{8}$"),
    CountryOption("NPL", "NP", "Nepal", "+977", "^9\\d{9}$"),
    CountryOption("LKA", "LK", "Sri Lanka", "+94", "^7\\d{8}$"),
    CountryOption("MMR", "MM", "Myanmar", "+95", "^9\\d{8}$"),
    CountryOption("KHM", "KH", "Cambodia", "+855", "^[1-9]\\d{7}$"),
    CountryOption("LAO", "LA", "Laos", "+856", "^[2-9]\\d{7}$"),
    CountryOption("MNG", "MN", "Mongolia", "+976", "^[5-9]\\d{7}$"),
    CountryOption("TWN", "TW", "Taiwan", "+886", "^9\\d{8}$"),
    CountryOption("HKG", "HK", "Hong Kong", "+852", "^[569]\\d{7}$"),
    CountryOption("MAC", "MO", "Macau", "+853", "^6\\d{7}$"),
    CountryOption("BRN", "BN", "Brunei", "+673", "^[2-9]\\d{6}$"),
    CountryOption("MDV", "MV", "Maldives", "+960", "^[7-9]\\d{6}$"),
    CountryOption("BTN", "BT", "Bhutan", "+975", "^[17]\\d{7}$"),

    // Oceania
    CountryOption("AUS", "AU", "Australia", "+61", "^(4\\d{8}|[2378]\\d{8,9})$"),
    CountryOption("NZL", "NZ", "New Zealand", "+64", "^(2\\d{7,9}|[34679]\\d{7,9})$"),
    CountryOption("PNG", "PG", "Papua New Guinea", "+675", "^[7-9]\\d{7}$"),
    CountryOption("FJI", "FJ", "Fiji", "+679", "^[7-9]\\d{6}$"),
    CountryOption("SLB", "SB", "Solomon Islands", "+677", "^[7-9]\\d{6}$"),
    CountryOption("VUT", "VU", "Vanuatu", "+678", "^[5-9]\\d{6}$"),
    CountryOption("WSM", "WS", "Samoa", "+685", "^[7-9]\\d{6}$"),
    CountryOption("TON", "TO", "Tonga", "+676", "^[7-9]\\d{6}$"),

    // Central Asia
    CountryOption("KAZ", "KZ", "Kazakhstan", "+7", "^[67]\\d{9}$"),
    CountryOption("UZB", "UZ", "Uzbekistan", "+998", "^[679]\\d{8}$"),
    CountryOption("KGZ", "KG", "Kyrgyzstan", "+996", "^[5-7]\\d{8}$"),
    CountryOption("TJK", "TJ", "Tajikistan", "+992", "^[9]\\d{8}$"),
    CountryOption("TKM", "TM", "Turkmenistan", "+993", "^[6-8]\\d{7}$")
]


