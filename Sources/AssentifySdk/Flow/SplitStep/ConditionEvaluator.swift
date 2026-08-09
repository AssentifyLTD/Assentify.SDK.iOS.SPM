import Foundation

final class ConditionEvaluator {
    
     private static let tag = "ConditionEvaluator"

      private static func debugLog(_ message: String) {
          #if DEBUG
          print("\(tag): \(message)")
          #endif
      }
    
    static func evaluateBranch(
        branch: Branch,
        flowController:FlowController
    ) -> Bool {
        
        debugLog("\(tag): ==================== evaluateBranch START ====================")
        debugLog("\(tag): Branch received: \(branch)")
        
        let conditions = branch.conditions

        if conditions.isEmpty {
            debugLog("Branch has no conditions -> returning true")
            debugLog("==================== evaluateBranch END ======================")
            return true
        }
        
        debugLog("\(tag): Conditions count = \(conditions.count)")
        
        var result: Bool? = nil
        
        for (index, condition) in conditions.enumerated() {
            debugLog("\(tag): -------------------------------------------------------------")
            debugLog("\(tag): Evaluating condition #\(index)")
            debugLog("\(tag): Condition object = \(condition)")
            debugLog("\(tag): Condition operator = \(String(describing: condition.operator))")
            debugLog("\(tag): Condition conditionOperator = \(String(describing: condition.conditionOperator))")
            debugLog("\(tag): Condition compare value = \(String(describing: condition.value))")
            
            var inputValue = ""
            
            let doneList = flowController.getAllDoneSteps()
            debugLog("\(tag): Done steps count = \(doneList.count)")
            
            for step in doneList {
                let outputProperties = step.stepDefinition?.customization.outputProperties ?? []
                
                for outputProperty in outputProperties {
                    if outputProperty.keyIdentifier == condition.inputPropertyKey {
                        let extractedInfo = step.submitRequestModel?.extractedInformation
                        inputValue = "\(extractedInfo?[outputProperty.key] ?? "")"
                        debugLog("\(tag): \(outputProperty.key) = \(inputValue)")
                    }
                }
            }
            
            let ruleResult = evaluateCondition(condition: condition, inputValue: inputValue)
            debugLog("\(tag): ruleResult for condition #\(index) = \(ruleResult)")
            
            let logicalOperator = LogicalOperator.from(condition.conditionOperator)
            debugLog("\(tag): Resolved logical operator = \(logicalOperator)")
            debugLog("\(tag): Previous accumulated result = \(String(describing: result))")
            
            if result == nil {
                result = ruleResult
            } else if logicalOperator == .and {
                result = (result ?? false) && ruleResult
            } else {
                result = (result ?? false) || ruleResult
            }
            
            debugLog("\(tag): New accumulated result after condition #\(index) = \(String(describing: result))")
        }
        
        let finalResult = result ?? false
        debugLog("\(tag): Final branch result = \(finalResult)")
        debugLog("\(tag): ==================== evaluateBranch END ======================")
        
        return finalResult
    }
    
    static func evaluateCondition(condition: Condition, inputValue: String?) -> Bool {
        debugLog("\(tag): ******************** evaluateCondition START *****************")
        debugLog("\(tag): Condition = \(condition)")
        debugLog("\(tag): Raw inputValue = '\(inputValue ?? "nil")'")
        
        guard let compareValue = condition.value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            debugLog("\(tag): compareValue is nil -> returning false")
            debugLog("\(tag): ******************** evaluateCondition END *******************")
            return false
        }
        
        debugLog("\(tag): Trimmed compareValue = '\(compareValue)'")
        
        guard let actualValue = inputValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            debugLog("\(tag): actualValue is nil -> returning false")
            debugLog("\(tag): ******************** evaluateCondition END *******************")
            return false
        }
        
        debugLog("\(tag): Trimmed actualValue = '\(actualValue)'")
        
        let a = Parsed(kind: .text, raw: actualValue)
        let b = Parsed(kind: .text, raw: compareValue)
        
        debugLog("\(tag): Parsed actualValue -> bool=\(String(describing: a.bool)), num=\(String(describing: a.num)), date=\(String(describing: a.date))")
        debugLog("\(tag): Parsed compareValue -> bool=\(String(describing: b.bool)), num=\(String(describing: b.num)), date=\(String(describing: b.date))")
        
        let op = ComparisonOperatorSplit.from(condition.operator)
        debugLog("\(tag): Resolved comparison operator = \(op)")
        
        if op == .contains {
            let result = actualValue.localizedCaseInsensitiveContains(compareValue)
            debugLog("\(tag): Text CONTAINS result = \(result)")
            debugLog("\(tag): ******************** evaluateCondition END *******************")
            return result
        }
        
        if op == .startsWith {
            let result = actualValue.lowercased().hasPrefix(compareValue.lowercased())
            debugLog("\(tag): Text STARTS_WITH result = \(result)")
            debugLog("\(tag): ******************** evaluateCondition END *******************")
            return result
        }
        
        if op == .endsWith {
            let result = actualValue.lowercased().hasSuffix(compareValue.lowercased())
            debugLog("\(tag): Text ENDS_WITH result = \(result)")
            debugLog("\(tag): ******************** evaluateCondition END *******************")
            return result
        }
        
        let kind = detectKind(a: a, b: b)
        debugLog("\(tag): Detected ValueKind = \(kind)")
        
        let result: Bool = {
            switch op {
            case .equal:
                switch kind {
                case .boolean:
                    let r = a.bool == b.bool
                    debugLog("\(tag): BOOLEAN EQUAL -> \(String(describing: a.bool)) == \(String(describing: b.bool)) => \(r)")
                    return r
                case .number:
                    let r = a.num == b.num
                    debugLog("\(tag): NUMBER EQUAL -> \(String(describing: a.num)) == \(String(describing: b.num)) => \(r)")
                    return r
                case .date:
                    let r = a.date == b.date
                    debugLog("\(tag): DATE EQUAL -> \(String(describing: a.date)) == \(String(describing: b.date)) => \(r)")
                    return r
                case .text:
                    let r = actualValue.caseInsensitiveCompare(compareValue) == .orderedSame
                    debugLog("\(tag): TEXT EQUAL -> '\(actualValue)' == '\(compareValue)' => \(r)")
                    return r
                }
                
            case .notEqual:
                switch kind {
                case .boolean:
                    let r = a.bool != b.bool
                    debugLog("\(tag): BOOLEAN NOT_EQUAL -> \(String(describing: a.bool)) != \(String(describing: b.bool)) => \(r)")
                    return r
                case .number:
                    let r = a.num != b.num
                    debugLog("\(tag): NUMBER NOT_EQUAL -> \(String(describing: a.num)) != \(String(describing: b.num)) => \(r)")
                    return r
                case .date:
                    let r = a.date != b.date
                    debugLog("\(tag): DATE NOT_EQUAL -> \(String(describing: a.date)) != \(String(describing: b.date)) => \(r)")
                    return r
                case .text:
                    let r = actualValue.caseInsensitiveCompare(compareValue) != .orderedSame
                    debugLog("\(tag): TEXT NOT_EQUAL -> '\(actualValue)' != '\(compareValue)' => \(r)")
                    return r
                }
                
            case .greaterThan, .greaterThanOrEqual, .lessThan, .lessThanOrEqual:
                switch kind {
                case .number:
                    guard let x = a.num, let y = b.num else {
                        debugLog("\(tag): One of number values is nil -> returning false")
                        return false
                    }
                    
                    debugLog("\(tag): NUMBER comparison values -> x=\(x), y=\(y)")
                    
                    switch op {
                    case .greaterThan:
                        let r = x > y
                        debugLog("\(tag): NUMBER GREATER_THAN -> \(x) > \(y) => \(r)")
                        return r
                    case .greaterThanOrEqual:
                        let r = x >= y
                        debugLog("\(tag): NUMBER GREATER_THAN_OR_EQUAL -> \(x) >= \(y) => \(r)")
                        return r
                    case .lessThan:
                        let r = x < y
                        debugLog("\(tag): NUMBER LESS_THAN -> \(x) < \(y) => \(r)")
                        return r
                    case .lessThanOrEqual:
                        let r = x <= y
                        debugLog("\(tag): NUMBER LESS_THAN_OR_EQUAL -> \(x) <= \(y) => \(r)")
                        return r
                    default:
                        return false
                    }
                    
                case .date:
                    guard let x = a.date, let y = b.date else {
                        debugLog("\(tag): One of date values is nil -> returning false")
                        return false
                    }
                    
                    debugLog("\(tag): DATE comparison values -> x=\(x), y=\(y)")
                    
                    switch op {
                    case .greaterThan:
                        let r = x > y
                        debugLog("\(tag): DATE GREATER_THAN -> \(x) > \(y) => \(r)")
                        return r
                    case .greaterThanOrEqual:
                        let r = x >= y
                        debugLog("\(tag): DATE GREATER_THAN_OR_EQUAL -> \(x) >= \(y) => \(r)")
                        return r
                    case .lessThan:
                        let r = x < y
                        debugLog("\(tag): DATE LESS_THAN -> \(x) < \(y) => \(r)")
                        return r
                    case .lessThanOrEqual:
                        let r = x <= y
                        debugLog("\(tag): DATE LESS_THAN_OR_EQUAL -> \(x) <= \(y) => \(r)")
                        return r
                    default:
                        return false
                    }
                    
                default:
                    debugLog("\(tag): Kind is \(kind), cannot safely use > < operators -> returning false")
                    return false
                }
                
            case .contains, .startsWith, .endsWith:
                debugLog("\(tag): Operator already handled above -> returning false")
                return false
            }
        }()
        
        debugLog("\(tag): evaluateCondition final result = \(result)")
        debugLog("\(tag): ******************** evaluateCondition END *******************")
        return result
    }
    
    private enum ValueKind {
        case boolean
        case number
        case date
        case text
    }
    
    private struct Parsed {
        let kind: ValueKind
        let raw: String
        
        var bool: Bool? {
            switch raw.lowercased() {
            case "true": return true
            case "false": return false
            default: return nil
            }
        }
        
        var num: Double? {
            Double(raw)
        }
        
        var date: Date? {
            ConditionEvaluator.parseDateOrNull(raw)
        }
    }
    
    private static func parseDateOrNull(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy"
        ]
        
        debugLog("\(tag): Trying to parse date from '\(s)'")
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) {
                debugLog("\(tag): Date parsed successfully with format '\(format)' -> \(parsed)")
                return parsed
            } else {
                debugLog("\(tag): Failed parsing '\(s)' with format '\(format)'")
            }
        }
        
        debugLog("\(tag): Could not parse date from '\(s)'")
        return nil
    }
    
    private static func detectKind(a: Parsed, b: Parsed) -> ValueKind {
        debugLog("\(tag): detectKind() -> a.raw='\(a.raw)', b.raw='\(b.raw)'")
        debugLog("\(tag): a.bool=\(String(describing: a.bool)), b.bool=\(String(describing: b.bool))")
        debugLog("\(tag): a.num=\(String(describing: a.num)), b.num=\(String(describing: b.num))")
        debugLog("\(tag): a.date=\(String(describing: a.date)), b.date=\(String(describing: b.date))")
        
        if a.bool != nil && b.bool != nil {
            debugLog("\(tag): Detected BOOLEAN")
            return .boolean
        }
        
        if a.num != nil && b.num != nil {
            debugLog("\(tag): Detected NUMBER")
            return .number
        }
        
        if a.date != nil && b.date != nil {
            debugLog("\(tag): Detected DATE")
            return .date
        }
        
        debugLog("\(tag): Falling back to TEXT")
        return .text
    }
}
