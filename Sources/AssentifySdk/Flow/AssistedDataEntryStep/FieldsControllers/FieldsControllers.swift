import Foundation

public enum AssistedFormHelper {
    
    // MARK: Default Value
    public static func getDefaultValueValueToCheckIsDirty(
        _ key: String,
        _ page: Int,
        flowController: FlowController
    ) -> String? {
        
        guard var model = AssistedDataEntryPagesObject.shared.get() else {
            return nil
        }
        
        guard model.assistedDataEntryPages.indices.contains(page) else { return nil }
        
        let pageElements = model.assistedDataEntryPages[page].dataEntryPageElements
        guard let idx = pageElements.firstIndex(where: { $0.inputKey == key }) else { return nil }
        
        let field = model.assistedDataEntryPages[page].dataEntryPageElements[idx]
    
        
        // If no identifiers list => return ""
        let identifiers = field.inputPropertyIdentifierList ?? []
        if identifiers.isEmpty {
            return ""
        }
        
        var defaultValue = ""
        let doneList = flowController.getAllDoneSteps()
        
        for step in doneList {
            
            let outputProps = step.stepDefinition!.customization.outputProperties
            
            let extractedAny = step.submitRequestModel?.extractedInformation ?? [:]
            
            for keyID in identifiers {
                for outputProperty in outputProps where outputProperty.keyIdentifier == keyID {
                    
                    if let raw = extractedAny[outputProperty.key] {
                        let val = String(describing: raw)
                        
                        if !val.isEmpty {
                            if defaultValue.isEmpty {
                                defaultValue = val
                            } else {
                                defaultValue += ",\(val)"
                            }
                        }
                    }
                }
            }
        }
        
        // Kotlin updates model too
        return defaultValue
    }
    
    // MARK: Default Value
    public static func getDefaultValueValue(
        _ key: String,
        _ page: Int,
        flowController: FlowController
    ) -> String? {
        
        guard var model = AssistedDataEntryPagesObject.shared.get() else {
            return nil
        }
        
        guard model.assistedDataEntryPages.indices.contains(page) else { return nil }
        
        let pageElements = model.assistedDataEntryPages[page].dataEntryPageElements
        guard let idx = pageElements.firstIndex(where: { $0.inputKey == key }) else { return nil }
        
        let field = model.assistedDataEntryPages[page].dataEntryPageElements[idx]
        
        // If field already has value, return it
        if let v = field.value, !v.isEmpty {
            return v
        }
        
        // If no identifiers list => return ""
        let identifiers = field.inputPropertyIdentifierList ?? []
        if identifiers.isEmpty {
            return ""
        }
        
        var defaultValue = ""
        let doneList = flowController.getAllDoneSteps()
        
        for step in doneList {
            
            let outputProps = step.stepDefinition!.customization.outputProperties
            
            let extractedAny = step.submitRequestModel?.extractedInformation ?? [:]
            
            for keyID in identifiers {
                for outputProperty in outputProps where outputProperty.keyIdentifier == keyID {
                    
                    if let raw = extractedAny[outputProperty.key] {
                        let val = String(describing: raw)
                        
                        if !val.isEmpty {
                            if defaultValue.isEmpty {
                                defaultValue = val
                            } else {
                                defaultValue += ",\(val)"
                            }
                        }
                    }
                }
            }
        }
        
        // Kotlin updates model too
        changeValue(key, defaultValue, page)
        return defaultValue
    }
    
    // MARK: Change Value (+ Children)
    public static func changeValue(_ key: String, _ value: String, _ page: Int) {
        guard var model = AssistedDataEntryPagesObject.shared.get() else { return }
        guard model.assistedDataEntryPages.indices.contains(page) else { return }

        guard let idx = model.assistedDataEntryPages[page].dataEntryPageElements.firstIndex(where: { $0.inputKey == key }) else {
            return
        }

        let parentIdentifier = model.assistedDataEntryPages[page].dataEntryPageElements[idx].elementIdentifier

        if let children = model.assistedDataEntryPages[page].dataEntryPageElements[idx].children,
           !children.isEmpty {

            for (childKey, list) in children {
                if childKey == value, !list.isEmpty {
                    var pageList = model.assistedDataEntryPages[page].dataEntryPageElements

                    
                    guard let parentIdx = pageList.firstIndex(where: { $0.elementIdentifier == parentIdentifier }) else {
                        continue
                    }

                    var insertPosition = parentIdx + 1
                    for element in list {
                        if !pageList.contains(where: { $0.elementIdentifier == element.elementIdentifier }) {
                            pageList.insert(element, at: insertPosition)
                            insertPosition += 1
                        }
                    }

                    model.assistedDataEntryPages[page].dataEntryPageElements = pageList
                } else {
                    let removeIds = Set(list.map { $0.elementIdentifier })
                    model.assistedDataEntryPages[page].dataEntryPageElements.removeAll { removeIds.contains($0.elementIdentifier) }
                }
            }
        }

        if let finalIdx = model.assistedDataEntryPages[page].dataEntryPageElements.firstIndex(where: { $0.elementIdentifier == parentIdentifier }) {
            model.assistedDataEntryPages[page].dataEntryPageElements[finalIdx].value = value
        }

        AssistedDataEntryPagesObject.shared.set(model)
    }
    
    // MARK: Change Regex
    public static func changeRegex(_ key: String, _ regex: String, _ defaultDial: String, _ page: Int) {
        guard var model = AssistedDataEntryPagesObject.shared.get() else { return }
        guard model.assistedDataEntryPages.indices.contains(page) else { return }
        
        guard let idx = model.assistedDataEntryPages[page].dataEntryPageElements.firstIndex(where: { $0.inputKey == key }) else {
            return
        }
        
        model.assistedDataEntryPages[page].dataEntryPageElements[idx].applyRegex = true
        model.assistedDataEntryPages[page].dataEntryPageElements[idx].regexDescriptor = regex
        model.assistedDataEntryPages[page].dataEntryPageElements[idx].defaultCountryCode = defaultDial
        
        AssistedDataEntryPagesObject.shared.set(model)
    }
    
    // MARK: Validate Field
    public static func validateField(_ key: String, _ page: Int) -> String? {
        guard let model = AssistedDataEntryPagesObject.shared.get() else { return nil }
        guard model.assistedDataEntryPages.indices.contains(page) else { return nil }
        
        guard let field = model.assistedDataEntryPages[page].dataEntryPageElements.first(where: { $0.inputKey == key }) else {
            return nil
        }
        
        let fieldValue = field.value ?? ""
        let fieldType = InputTypes.fromString(field.inputType)
        
        // Mandatory
        if (field.mandatory ?? false) && fieldValue.isEmpty {
            return FlowStrings.fieldRequired
        }

        if fieldValue.isEmpty { return nil }

        // Min/Max
        if let min = field.minLength, fieldValue.count < min {
            return FlowStrings.minCharactersRequired(min)
        }
        if let max = field.maxLength, fieldValue.count > max {
            return FlowStrings.maxCharactersAllowed(max)
        }

        // Email regex
        if fieldType == .email, !fieldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
            if !matchesRegex(fieldValue, pattern: emailPattern, ignoreCase: true) {
                return (field.regexErrorMessage?.isEmpty == false)
                ? field.regexErrorMessage
                : FlowStrings.invalidEmail
            }
        }

        // Custom regex
        if field.applyRegex ?? false {
            let pattern = field.regexDescriptor ?? ""
            if !pattern.isEmpty {
                if !matchesRegex(fieldValue, pattern: pattern, ignoreCase: true) {
                    return (field.regexErrorMessage?.isEmpty == false)
                    ? field.regexErrorMessage
                    : FlowStrings.pleaseEnterValidValue
                }
            }
        }
        
        return nil
    }
    
    // MARK: Change Local OTP Valid
    public static func changeLocalOtpValid(_ key: String, _ value: Bool, _ page: Int) {
        guard var model = AssistedDataEntryPagesObject.shared.get() else { return }
        guard model.assistedDataEntryPages.indices.contains(page) else { return }
        
        guard let idx = model.assistedDataEntryPages[page].dataEntryPageElements.firstIndex(where: { $0.inputKey == key }) else {
            return
        }
        
        model.assistedDataEntryPages[page].dataEntryPageElements[idx].isLocalOtpValid = value
        AssistedDataEntryPagesObject.shared.set(model)
    }
    
    // MARK: Validate Page
    public static func validatePage(_ page: Int) -> Bool {
        guard let model = AssistedDataEntryPagesObject.shared.get() else { return false }
        guard model.assistedDataEntryPages.indices.contains(page) else { return false }
        
        let fields = model.assistedDataEntryPages[page].dataEntryPageElements
        
        for f in fields {
            guard let k = f.inputKey else { continue }
            if let err = validateField(k, page), !err.isEmpty {
                return false
            }
        }
        
        for f in fields {
            let t = InputTypes.fromString(f.inputType)
            if t == .emailWithOTP || t == .phoneNumberWithOTP {
                if f.isLocalOtpValid == false { return false }
            }
        }
        
        return true
    }
    
    public static func valueTransformation(
        language: String,
        transformationModel: TransformationModel,
        onResult: @escaping (LanguageTransformationModel?) -> Void
    ) {
       
        transformData(apiKey:  ApiKeyObject.shared.get()!, language: language, request: transformationModel) { result in
            switch result {
            case .success(let transformedData):
                 onResult(transformedData.first)
            case .failure(let _error):
                onResult(nil)
            }
        }
        
        
    }
    
    
    // MARK: - Regex helper
    private static func matchesRegex(_ text: String, pattern: String, ignoreCase: Bool) -> Bool {
        do {
            let options: NSRegularExpression.Options = ignoreCase ? [.caseInsensitive] : []
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    static func changeValueSecureDropdownWithDataSource(
        key: String,
        dataSourceAttribute: [DataSourceAttribute],
        outputKeys: [String: String],
        page: Int
    ) {
        guard var model = AssistedDataEntryPagesObject.shared.get() else { return }

        var pages = model.assistedDataEntryPages              // ✅ must be var
        guard pages.indices.contains(page) else { return }

        guard let fieldIndex = pages[page].dataEntryPageElements
            .firstIndex(where: { $0.inputKey == key }) else { return }

        var field = pages[page].dataEntryPageElements[fieldIndex]   // ✅ var copy (struct)
        let parentIdentifier = field.elementIdentifier

        /** Check IF Has Children **/
        if let children = field.children, !children.isEmpty {

            let displayValue = dataSourceAttribute
                .first(where: { $0.mappedKey == "Display Value" })?
                .value ?? ""

            children.forEach { (childKey, list) in

                if !dataSourceAttribute.isEmpty,
                   childKey == displayValue,
                   !list.isEmpty {

                    var pageList = pages[page].dataEntryPageElements

                    // Re-locate the parent's *current* index — earlier
                    // insert/remove calls in this loop may have shifted it.
                    guard let parentIdx = pageList.firstIndex(where: { $0.elementIdentifier == parentIdentifier }) else {
                        return
                    }

                    var insertPosition = parentIdx + 1
                    list.forEach { element in
                        let exists = pageList.contains(where: { $0.elementIdentifier == element.elementIdentifier })
                        if !exists {
                            pageList.insert(element, at: insertPosition)
                            insertPosition += 1
                        }
                    }

                    pages[page].dataEntryPageElements = pageList

                } else {
                    var pageList = pages[page].dataEntryPageElements
                    let removeIds = Set(list.map { $0.elementIdentifier })
                    pageList.removeAll(where: { removeIds.contains($0.elementIdentifier) })
                    pages[page].dataEntryPageElements = pageList
                }
            }
        }
        /** **/

        if !dataSourceAttribute.isEmpty {

            field.value = dataSourceAttribute
                .first(where: { $0.mappedKey == "Display Value" })?
                .value ?? ""

            field.dataSourceValues = [:]

            dataSourceAttribute.forEach { item in
                let outKey = outputKeys[String(item.id)] ?? ""
                if !outKey.isEmpty {
                    field.dataSourceValues?[outKey] = item.value
                }
            }

            // ✅ re-locate the field's current index before writing back —
            // it may have shifted due to inserts/removals above
            if let currentFieldIndex = pages[page].dataEntryPageElements
                .firstIndex(where: { $0.elementIdentifier == parentIdentifier }) {
                pages[page].dataEntryPageElements[currentFieldIndex] = field
            }

            // ✅ write back pages to model and save
            model.assistedDataEntryPages = pages
            AssistedDataEntryPagesObject.shared.set(model)
        } else {
            // still save children changes if any happened
            model.assistedDataEntryPages = pages
            AssistedDataEntryPagesObject.shared.set(model)
        }
    }
    
    
    public static func getDataSourceValues(
          apiKey: String,
          config: ConfigModel,
          elementIdentifier: String,
          stepId: Int,
          endpointId: Int,
          filterKeyValues :[String: String] = [:],
          completion: @escaping (BaseResult<DataSourceResponse, Error>) -> Void
      ) {

          // Build URL with query params
        //  var components = URLComponents(string: BaseUrls.baseURLGateway + "v1/DataSource/DataSourceValues")
          var components = URLComponents(string: BaseUrls.baseURLGateway + "v1/DataSource/DataSourceValues")
          components?.queryItems = [
              URLQueryItem(name: "elementIdentifier", value: elementIdentifier),
              URLQueryItem(name: "stepId", value: String(stepId)),
              URLQueryItem(name: "endpointId", value: String(endpointId))
          ]

          guard let url = components?.url else {
              completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

          // ✅ headers (same as Kotlin)
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
          request.setValue("iOS SDK", forHTTPHeaderField: "X-Source-Agent")
          request.setValue(config.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
          request.setValue(config.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
          request.setValue(config.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
          request.setValue(config.instanceId, forHTTPHeaderField: "X-Instance-Id")
          request.setValue(config.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
          request.setValue(config.instanceHash, forHTTPHeaderField: "X-Instance-Hash")

          let body = DataSourceRequestBody(
              filterKeyValues: filterKeyValues,
              inputKeyValues: [:]
          )

          do {
              let encoder = JSONEncoder()
              request.httpBody = try encoder.encode(body)
          } catch {
              completion(.failure(error))
              return
          }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in

              if let error {
                  completion(.failure(error))
                  return
              }

              guard let http = response as? HTTPURLResponse else {
                  completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                  return
              }

              guard (200...299).contains(http.statusCode) else {
                  // if you want: parse error body here
                  completion(.failure(NSError(domain: "HTTP \(http.statusCode)", code: http.statusCode, userInfo: nil)))
                  return
              }

              guard let data else {
                  completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                  return
              }

              do {
                  let decoder = JSONDecoder()
                  let result = try decoder.decode(DataSourceResponse.self, from: data)
                  completion(.success(result))
              } catch {
                  completion(.failure(error))
              }
          }

          task.resume()
      }
    
    static func getFilterValue(dataSourceData: DataSourceData?) -> [String: String] {
        var resultMap: [String: String] = [:]

        guard let dataSourceData = dataSourceData else {
            return resultMap
        }

        guard let model = AssistedDataEntryPagesObject.shared.get() else {
            return resultMap
        }

        let pages = model.assistedDataEntryPages

        for page in pages {
            for item in page.dataEntryPageElements {
                if let dataSourceValues = item.dataSourceValues {
                    for filterKey in dataSourceData.filterKeys {
                        if dataSourceValues.keys.contains(filterKey),
                           let value = dataSourceValues[filterKey] {
                            resultMap[filterKey] = value
                        }
                    }
                }
            }
        }

        return resultMap
    }

}
