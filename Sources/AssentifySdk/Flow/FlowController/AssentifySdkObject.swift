//
//  AssentifySdkObject.swift
//  Pods
//
//  Created by TariQ on 11/02/2026.
//

import Foundation



public final class InteractionObject {
    
    public static let shared = InteractionObject()
    private init() {}
    
    private var interactio: String?
    
    public func set(_ key: String) {
        self.interactio = key
    }
    
    public func get() -> String? {
        return interactio
    }
    
    public func clear() {
        interactio = nil
    }
}


public final class AssentifySdkObject {
    
    public static let shared = AssentifySdkObject()
    private init() {}
    
    private var sssentifySdk: AssentifySdk?
    
    public func set(_ key: AssentifySdk) {
        self.sssentifySdk = key
    }
    
    public func get() -> AssentifySdk? {
        return sssentifySdk
    }
    
    public func clear() {
        sssentifySdk = nil
    }
}

public final class ApiKeyObject {
    
    public static let shared = ApiKeyObject()
    private init() {}
    
    private var apiKey: String?
    
    public func set(_ key: String) {
        self.apiKey = key
    }
    
    public func get() -> String? {
        return apiKey
    }
    
    public func clear() {
        apiKey = nil
    }
}


public final class FlowEnvironmentalConditionsObject {
    
    public static let shared = FlowEnvironmentalConditionsObject()
    private init() {}
    
    private var value: FlowEnvironmentalConditions?
    
    public func set(_ conditions: FlowEnvironmentalConditions) {
        self.value = conditions
    }
    
    public func get() -> FlowEnvironmentalConditions? {
        return value
    }
    
    public func clear() {
        value = nil
    }
}

public final class ConfigModelObject {

    public static let shared = ConfigModelObject()
    private init() {}

    private let PREF_NAME = "assentify_sdk_prefs"

    private func key() -> String {
        return "ConfigModelObject_\(String(describing: InteractionObject.shared.get()))"
    }

    public func set(_ model: ConfigModel?) {

        guard let model else {
            UserDefaults.standard.removeObject(forKey: key())
            return
        }

        do {
            let data = try JSONEncoder().encode(model)
            UserDefaults.standard.set(data, forKey: key())
        } catch {
            print("ConfigModelObject encode error:", error)
        }
    }

    public func get() -> ConfigModel? {

        guard let data = UserDefaults.standard.data(forKey: key()) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ConfigModel.self, from: data)
        } catch {
            print("ConfigModelObject decode error:", error)
            return nil
        }
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: key())
    }
}


public final class LocalStepsObject {

    public static let shared = LocalStepsObject()
    private init() {}

    private let PREF_NAME = "assentify_sdk_prefs"

    private func key() -> String {
        return "LocalStepsObject_\(String(describing: InteractionObject.shared.get()))"
    }

    public func set(_ steps: [LocalStepModel]) {

        do {
            let data = try JSONEncoder().encode(steps)
            UserDefaults.standard.set(data, forKey: key())
        } catch {
            print("LocalStepsObject encode error:", error)
        }
    }

    public func get() -> [LocalStepModel] {

        guard let data = UserDefaults.standard.data(forKey: key()) else {
            return []
        }

        do {
            return try JSONDecoder().decode([LocalStepModel].self, from: data)
        } catch {
            print("LocalStepsObject decode error:", error)
            return []
        }
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: key())
    }
}

public final class ContentHashObject {

    public static let shared = ContentHashObject()
    private init() {}

    private func key(interaction: String) -> String {
        return "ContentHashObject_\(interaction)"
    }

    public func set(_ value: String?, instanceHash: String) {
        UserDefaults.standard.set(value, forKey: key(interaction: instanceHash))
    }

    public func get(instanceHash: String) -> String? {
        return UserDefaults.standard.string(forKey: key(interaction: instanceHash))
    }

    public func clear(instanceHash: String) {
        UserDefaults.standard.removeObject(forKey: key(interaction: instanceHash))
    }
}






public final class SelectedTemplatesObject {
    
    public static let shared = SelectedTemplatesObject()
    private init() {}
    
    private var templates: Templates?
    
    public func set(_ model: Templates) {
        self.templates = model
    }
    
    public func get() -> Templates? {
        return templates
    }
    
    public func clear() {
        templates = nil
    }
}

public final class IDImageObject {

    public static let shared = IDImageObject()
    private init() {}

    private func key() -> String {
        return "IDImageObject_\(String(describing: InteractionObject.shared.get()))"
    }

    public func setImage(_ value: String?) {
        UserDefaults.standard.set(value, forKey: key())
    }

    public func getImage() -> String? {
        return UserDefaults.standard.string(forKey: key())
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: key())
    }
}


public final class OnCompleteScreenData {
    
    public static let shared = OnCompleteScreenData()
    private init() {}
    
    private var data: [String: String]! = [:]
    
    public func set(_ data: [String: String]) {
        self.data = data
    }
    
    public func get() -> [String: String]? {
        return data
    }
    
    public func clear() {
        data = [:]
    }
}


public final class NfcPassportResponseModelObject {
    
    public static let shared = NfcPassportResponseModelObject()
    private init() {}
    
    private var passportResponseModel:PassportResponseModel?
    
    public func set(_ passportResponseModel: PassportResponseModel) {
        self.passportResponseModel = passportResponseModel
    }
    
    public func get() -> PassportResponseModel? {
        return passportResponseModel
    }
    
    public func clear() {
        passportResponseModel =  nil
    }
}

public final class QrIDResponseModelObject {
    
    public static let shared = QrIDResponseModelObject()
    private init() {}
    
    private var iDResponseModel:IDResponseModel?
    
    public func set(_ iDResponseModel: IDResponseModel) {
        self.iDResponseModel = iDResponseModel
    }
    
    public func get() -> IDResponseModel? {
        return iDResponseModel
    }
    
    public func clear() {
        iDResponseModel =  nil
    }
}

public final class AssistedDataEntryPagesObject {
    
    public static let shared = AssistedDataEntryPagesObject()
    private init() {}
    
    private var assistedDataEntryModel:AssistedDataEntryModel?
    
    public func set(_ assistedDataEntryModel: AssistedDataEntryModel) {
        self.assistedDataEntryModel = assistedDataEntryModel
        let steps = LocalStepsObject.shared.get()
        let currentStep =  steps.first { $0.isDone == false }
        AssistedDataEntryPagesObjectJson.shared.set(self.assistedDataEntryModel, stepId: (currentStep?.stepDefinition!.stepId)!)
    }
    
    public func get() -> AssistedDataEntryModel? {
        return assistedDataEntryModel
    }
    
    public func clear() {
        assistedDataEntryModel =  nil
    }
}


public final class AssistedDataEntryPagesObjectJson {

    public static let shared = AssistedDataEntryPagesObjectJson()
    private init() {}

    private func key(stepId: Int) -> String {
        return "AssistedDataEntryPagesObject_\(InteractionObject.shared.get())_\(stepId)"
    }

    public func set(_ model: AssistedDataEntryModel?, stepId: Int) {
        guard let model else {
            UserDefaults.standard.removeObject(forKey: key(stepId: stepId))
            return
        }

        do {
            let data = try JSONEncoder().encode(model)
            UserDefaults.standard.set(data, forKey: key(stepId: stepId))
        } catch {
            print("AssistedDataEntryPagesObject encode error:", error)
        }
    }

    public func get(stepId: Int) -> AssistedDataEntryModel? {
        guard let data = UserDefaults.standard.data(forKey: key(stepId: stepId)) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(AssistedDataEntryModel.self, from: data)
        } catch {
            print("AssistedDataEntryPagesObject decode error:", error)
            return nil
        }
    }

    // Clears all keys that belong to the current InteractionObject session
    public func clear() {
        let prefix = "AssistedDataEntryPagesObject_\(InteractionObject.shared.get())_"
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}

public final class CreateUserDocumentObject {

    public static let shared = CreateUserDocumentObject()
    private init() {}

    private func key(stepId: Int) -> String {
        return "CreateUserDocumentObject_\(InteractionObject.shared.get())_\(stepId)"
    }

    public func set(_ model: CreateUserDocumentResponseModel?, stepId: Int) {
        guard let model else {
            UserDefaults.standard.removeObject(forKey: key(stepId: stepId))
            return
        }

        do {
            let data = try JSONEncoder().encode(model)
            UserDefaults.standard.set(data, forKey: key(stepId: stepId))
        } catch {
            print("CreateUserDocumentObject encode error:", error)
        }
    }

    public func get(stepId: Int) -> CreateUserDocumentResponseModel? {
        guard let data = UserDefaults.standard.data(forKey: key(stepId: stepId)) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CreateUserDocumentResponseModel.self, from: data)
        } catch {
            print("CreateUserDocumentObject decode error:", error)
            return nil
        }
    }

    // Clears all keys that belong to the current InteractionObject session
    public func clear() {
        let prefix = "CreateUserDocumentObject_\(InteractionObject.shared.get())_"
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}


public final class SignatureResponseObject {

    public static let shared = SignatureResponseObject()
    private init() {}

    private func key(stepId: Int) -> String {
        return "SignatureResponseObject_\(InteractionObject.shared.get())_\(stepId)"
    }

    public func set(_ model: SignatureResponseModel?, stepId: Int) {
        guard let model else {
            UserDefaults.standard.removeObject(forKey: key(stepId: stepId))
            return
        }

        do {
            let data = try JSONEncoder().encode(model)
            UserDefaults.standard.set(data, forKey: key(stepId: stepId))
        } catch {
            print("SignatureResponseObject encode error:", error)
        }
    }

    public func get(stepId: Int) -> SignatureResponseModel? {
        guard let data = UserDefaults.standard.data(forKey: key(stepId: stepId)) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SignatureResponseModel.self, from: data)
        } catch {
            print("SignatureResponseObject decode error:", error)
            return nil
        }
    }

    // Clears all keys that belong to the current InteractionObject session
    public func clear() {
        let prefix = "SignatureResponseObject_\(InteractionObject.shared.get())_"
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}


public final class HasSubmittedObject {

    public static let shared = HasSubmittedObject()
    private init() {}

    private func key() -> String {
        return "HasSubmittedObject_\(String(describing: InteractionObject.shared.get()))"
    }

    public func set(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key())
    }

    public func get() -> Bool {
        return UserDefaults.standard.bool(forKey: key())
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: key())
    }
}
