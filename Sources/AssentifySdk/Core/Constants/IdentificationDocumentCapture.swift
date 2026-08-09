import Foundation

struct IdentificationDocumentCaptureKeys{
    static let name = "OnBoardMe_IdentificationDocumentCapture_name"
    static let surname = "OnBoardMe_IdentificationDocumentCapture_surname"
    static let documentType = "OnBoardMe_IdentificationDocumentCapture_Document_Type"
    static let birthDate = "OnBoardMe_IdentificationDocumentCapture_Birth_Date"
    static let documentNumber = "OnBoardMe_IdentificationDocumentCapture_Document_Number"
    static let sex = "OnBoardMe_IdentificationDocumentCapture_Sex"
    static let expiryDate = "OnBoardMe_IdentificationDocumentCapture_Expiry_Date"
    static let country = "OnBoardMe_IdentificationDocumentCapture_Country"
    static let nationality = "OnBoardMe_IdentificationDocumentCapture_Nationality"
    static let idType = "OnBoardMe_IdentificationDocumentCapture_IDType"
    static let faceCapture = "OnBoardMe_IdentificationDocumentCapture_FaceCapture"
    static let image = "OnBoardMe_IdentificationDocumentCapture_Image"
    static let isSkippedAfterNFails = "OnBoardMe_IdentificationDocumentCapture_IsSkippedAfterNFails"
    static let isFailedFront = "OnBoardMe_IdentificationDocumentCapture_IsFailedFront"
    static let isFailedBack = "OnBoardMe_IdentificationDocumentCapture_IsFailedBack"
    static let skippedStatus = "OnBoardMe_IdentificationDocumentCapture_SkippedStatus"
    static let capturedVideoFront = "OnBoardMe_IdentificationDocumentCapture_CapturedVideoFront"
    static let capturedVideoBack = "OnBoardMe_IdentificationDocumentCapture_CapturedVideoBack"
    static let livenessStatus = "OnBoardMe_IdentificationDocumentCapture_LivenessStatus"
    static let isFrontAuth = "OnBoardMe_IdentificationDocumentCapture_IsFrontAuth"
    static let isBackAuth = "OnBoardMe_IdentificationDocumentCapture_IsBackAuth"
    static let isExpired = "OnBoardMe_IdentificationDocumentCapture_IsExpired"
    static let isTampering = "OnBoardMe_IdentificationDocumentCapture_IsTampering"
    static let tamperHeatMap = "OnBoardMe_IdentificationDocumentCapture_TamperHeatMap"
    static let isBackTampering = "OnBoardMe_IdentificationDocumentCapture_IsBackTampering"
    static let backTamperHeatmap = "OnBoardMe_IdentificationDocumentCapture_BackTamperHeatmap"
    static let originalFrontImage = "OnBoardMe_IdentificationDocumentCapture_OriginalFrontImage"
    static let originalBackImage = "OnBoardMe_IdentificationDocumentCapture_OriginalBackImage"
    static let ghostImage = "OnBoardMe_IdentificationDocumentCapture_GhostImage"
    static let idMaritalStatus = "OnBoardMe_IdentificationDocumentCapture_ID_MaritalStatus"
    static let idDateOfIssuance = "OnBoardMe_IdentificationDocumentCapture_ID_DateOfIssuance"
    static let idCivilRegisterNumber = "OnBoardMe_IdentificationDocumentCapture_ID_CivilRegisterNumber"
    static let idPlaceOfResidence = "OnBoardMe_IdentificationDocumentCapture_ID_PlaceOfResidence"
    static let idProvince = "OnBoardMe_IdentificationDocumentCapture_ID_Province"
    static let idGovernorate = "OnBoardMe_IdentificationDocumentCapture_ID_Governorate"
    static let idMothersName = "OnBoardMe_IdentificationDocumentCapture_ID_MothersName"
    static let idFathersName = "OnBoardMe_IdentificationDocumentCapture_ID_FathersName"
    static let idPlaceOfBirth = "OnBoardMe_IdentificationDocumentCapture_ID_PlaceOfBirth"
    static let idBackImage = "OnBoardMe_IdentificationDocumentCapture_ID_BackImage"
    static let idBloodType = "OnBoardMe_IdentificationDocumentCapture_ID_BloodType"
    static let idDrivingCategory = "OnBoardMe_IdentificationDocumentCapture_ID_DrivingCategory"
    static let idIssuanceAuthority = "OnBoardMe_IdentificationDocumentCapture_ID_IssuanceAuthority"
    static let idArmyStatus = "OnBoardMe_IdentificationDocumentCapture_ID_ArmyStatus"
    static let idProfession = "OnBoardMe_IdentificationDocumentCapture_ID_Profession"
    static let idUniqueNumber = "OnBoardMe_IdentificationDocumentCapture_ID_UniqueNumber"
    static let idDocumentTypeNumber = "5OnBoardMe_IdentificationDocumentCapture_ID_DocumentTypeNumber"
    static let idFees = "OnBoardMe_IdentificationDocumentCapture_ID_Fees"
    static let idReference = "OnBoardMe_IdentificationDocumentCapture_ID_Reference"
    static let idRegion = "OnBoardMe_IdentificationDocumentCapture_ID_Region"
    static let idRegistrationLocation = "OnBoardMe_IdentificationDocumentCapture_ID_RegistrationLocation"
    static let idFaceColor = "OnBoardMe_IdentificationDocumentCapture_ID_FaceColor"
    static let idEyeColor = "OnBoardMe_IdentificationDocumentCapture_ID_EyeColor"
    static let idSpecialMarks = "OnBoardMe_IdentificationDocumentCapture_ID_SpecialMarks"
    static let idCountryOfStay = "OnBoardMe_IdentificationDocumentCapture_ID_CountryOfStay"
    static let idIdentityNumber = "OnBoardMe_IdentificationDocumentCapture_ID_IdentityNumber"
    static let idPresentAddress = "OnBoardMe_IdentificationDocumentCapture_ID_PresentAddress"
    static let idPermanentAddress = "OnBoardMe_IdentificationDocumentCapture_ID_PermanentAddress"
    static let idFamilyNumber = "OnBoardMe_IdentificationDocumentCapture_ID_FamilyNumber"
    static let identityNumberBack = "OnBoardMe_IdentificationDocumentCapture_ID_IdentityNumberBack"
}

@objc public class IdentificationDocumentCapture : NSObject {
    public var name: Any?
    public var surname:  Any?
    public var Document_Type:  Any?
    public var Birth_Date:  Any?
    public var Document_Number:  Any?
    public var Sex:  Any?
    public var Expiry_Date:  Any?
    public var Country:  Any?
    public var Nationality:  Any?
    public var IDType:  Any?
    public var FaceCapture:  Any?
    public var Image:  Any?
    public var IsSkippedAfterNFails:  Any?
    public var IsFailedFront:  Any?
    public var IsFailedBack:  Any?
    public var SkippedStatus:  Any?
    public var CapturedVideoFront:  Any?
    public var CapturedVideoBack:  Any?
    public var LivenessStatus:  Any?
    public var IsFrontAuth:  Any?
    public var IsBackAuth:  Any?
    public var IsExpired:  Any?
    public var IsTampering:  Any?
    public var TamperHeatMap:  Any?
    public var IsBackTampering:  Any?
    public var BackTamperHeatmap:  Any?
    public var OriginalFrontImage:  Any?
    public var OriginalBackImage:  Any?
    public var GhostImage:  Any?
    public var ID_MaritalStatus:  Any?
    public var ID_DateOfIssuance:  Any?
    public var ID_CivilRegisterNumber:  Any?
    public var ID_PlaceOfResidence:  Any?
    public var ID_Province:  Any?
    public var ID_Governorate:  Any?
    public var ID_MothersName:  Any?
    public var ID_FathersName:  Any?
    public var ID_PlaceOfBirth:  Any?
    public var ID_BackImage:  Any?
    public var ID_BloodType:  Any?
    public var ID_DrivingCategory:  Any?
    public var ID_IssuanceAuthority:  Any?
    public var ID_ArmyStatus:  Any?
    public var ID_Profession:  Any?
    public var ID_UniqueNumber:  Any?
    public var ID_DocumentTypeNumber:  Any?
    public var ID_Fees:  Any?
    public var ID_Reference:  Any?
    public var ID_Region:  Any?
    public var ID_RegistrationLocation:  Any?
    public var ID_FaceColor:  Any?
    public var ID_EyeColor: Any?
    public var ID_SpecialMarks:  Any?
    public var ID_GuardianName:  Any?
    public var ID_CountryOfStay:  Any?
    public var ID_IdentityNumber:  Any?
    public var ID_PresentAddress:  Any?
    public var ID_PermanentAddress:  Any?
    public var ID_FamilyNumber:  Any?
    public var ID_IdentityNumberBack:  Any?
    
    public override init() {
        
    }
}
func fillIdentificationDocumentCapture(outputProperties: [String: Any]?) -> IdentificationDocumentCapture {
    var identificationDocumentCapture = IdentificationDocumentCapture()
    
    outputProperties?.forEach { (key, value) in
        if key.contains(IdentificationDocumentCaptureKeys.name) {
            identificationDocumentCapture.name = value
        } else if key.contains(IdentificationDocumentCaptureKeys.surname) {
            identificationDocumentCapture.surname = value
        } else if key.contains(IdentificationDocumentCaptureKeys.documentType) {
            identificationDocumentCapture.Document_Type = value
        } else if key.contains(IdentificationDocumentCaptureKeys.birthDate) {
            identificationDocumentCapture.Birth_Date = value
        } else if key.contains(IdentificationDocumentCaptureKeys.documentNumber) {
            identificationDocumentCapture.Document_Number = value
        } else if key.contains(IdentificationDocumentCaptureKeys.sex) {
            identificationDocumentCapture.Sex = value
        } else if key.contains(IdentificationDocumentCaptureKeys.expiryDate) {
            identificationDocumentCapture.Expiry_Date = value
        } else if key.contains(IdentificationDocumentCaptureKeys.country) {
            identificationDocumentCapture.Country = value
        } else if key.contains(IdentificationDocumentCaptureKeys.nationality) {
            identificationDocumentCapture.Nationality = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idType) {
            identificationDocumentCapture.IDType = value
        } else if key.contains(IdentificationDocumentCaptureKeys.faceCapture) {
            identificationDocumentCapture.FaceCapture = value
        } else if key.contains(IdentificationDocumentCaptureKeys.image) {
            identificationDocumentCapture.Image = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isSkippedAfterNFails) {
            identificationDocumentCapture.IsSkippedAfterNFails = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isFailedFront) {
            identificationDocumentCapture.IsFailedFront = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isFailedBack) {
            identificationDocumentCapture.IsFailedBack = value
        } else if key.contains(IdentificationDocumentCaptureKeys.skippedStatus) {
            identificationDocumentCapture.SkippedStatus = value
        } else if key.contains(IdentificationDocumentCaptureKeys.capturedVideoFront) {
            identificationDocumentCapture.CapturedVideoFront = value
        } else if key.contains(IdentificationDocumentCaptureKeys.capturedVideoBack) {
            identificationDocumentCapture.CapturedVideoBack = value
        } else if key.contains(IdentificationDocumentCaptureKeys.livenessStatus) {
            identificationDocumentCapture.LivenessStatus = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isFrontAuth) {
            identificationDocumentCapture.IsFrontAuth = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isBackAuth) {
            identificationDocumentCapture.IsBackAuth = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isExpired) {
            identificationDocumentCapture.IsExpired = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isTampering) {
            identificationDocumentCapture.IsTampering = value
        } else if key.contains(IdentificationDocumentCaptureKeys.tamperHeatMap) {
            identificationDocumentCapture.TamperHeatMap = value
        } else if key.contains(IdentificationDocumentCaptureKeys.isBackTampering) {
            identificationDocumentCapture.IsBackTampering = value
        } else if key.contains(IdentificationDocumentCaptureKeys.backTamperHeatmap) {
            identificationDocumentCapture.BackTamperHeatmap = value
        } else if key.contains(IdentificationDocumentCaptureKeys.originalFrontImage) {
            identificationDocumentCapture.OriginalFrontImage = value
        } else if key.contains(IdentificationDocumentCaptureKeys.originalBackImage) {
            identificationDocumentCapture.OriginalBackImage = value
        } else if key.contains(IdentificationDocumentCaptureKeys.ghostImage) {
            identificationDocumentCapture.GhostImage = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idMaritalStatus) {
            identificationDocumentCapture.ID_MaritalStatus = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idDateOfIssuance) {
            identificationDocumentCapture.ID_DateOfIssuance = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idCivilRegisterNumber) {
            identificationDocumentCapture.ID_CivilRegisterNumber = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idPlaceOfResidence) {
            identificationDocumentCapture.ID_PlaceOfResidence = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idProvince) {
            identificationDocumentCapture.ID_Province = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idGovernorate) {
            identificationDocumentCapture.ID_Governorate = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idMothersName) {
            identificationDocumentCapture.ID_MothersName = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idFathersName) {
            identificationDocumentCapture.ID_FathersName = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idPlaceOfBirth) {
            identificationDocumentCapture.ID_PlaceOfBirth = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idBackImage) {
            identificationDocumentCapture.ID_BackImage = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idBloodType) {
            identificationDocumentCapture.ID_BloodType = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idDrivingCategory) {
            identificationDocumentCapture.ID_DrivingCategory = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idIssuanceAuthority) {
            identificationDocumentCapture.ID_IssuanceAuthority = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idArmyStatus) {
            identificationDocumentCapture.ID_ArmyStatus = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idProfession) {
            identificationDocumentCapture.ID_Profession = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idUniqueNumber) {
            identificationDocumentCapture.ID_UniqueNumber = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idDocumentTypeNumber) {
            identificationDocumentCapture.ID_DocumentTypeNumber = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idFees) {
            identificationDocumentCapture.ID_Fees = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idReference) {
            identificationDocumentCapture.ID_Reference = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idRegion) {
            identificationDocumentCapture.ID_Region = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idRegistrationLocation) {
            identificationDocumentCapture.ID_RegistrationLocation = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idFaceColor) {
            identificationDocumentCapture.ID_FaceColor = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idEyeColor) {
            identificationDocumentCapture.ID_EyeColor = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idSpecialMarks) {
            identificationDocumentCapture.ID_SpecialMarks = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idCountryOfStay) {
            identificationDocumentCapture.ID_CountryOfStay = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idIdentityNumber) {
            identificationDocumentCapture.ID_IdentityNumber = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idPresentAddress) {
            identificationDocumentCapture.ID_PresentAddress = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idPermanentAddress) {
            identificationDocumentCapture.ID_PermanentAddress = value
        } else if key.contains(IdentificationDocumentCaptureKeys.idFamilyNumber) {
            identificationDocumentCapture.ID_FamilyNumber = value
        } else if key.contains(IdentificationDocumentCaptureKeys.identityNumberBack) {
            identificationDocumentCapture.ID_IdentityNumberBack = value
        }
    }
    
    return identificationDocumentCapture
}



public func getLanguageTransformationEnum(key: String) -> Int  {
    let transliterationKeys = [
        IdentificationDocumentCaptureKeys.name,
        IdentificationDocumentCaptureKeys.surname,
        IdentificationDocumentCaptureKeys.idPlaceOfResidence,
        IdentificationDocumentCaptureKeys.idProvince,
        IdentificationDocumentCaptureKeys.idGovernorate,
        IdentificationDocumentCaptureKeys.idMothersName,
        IdentificationDocumentCaptureKeys.idFathersName,
        IdentificationDocumentCaptureKeys.idPlaceOfBirth,
        IdentificationDocumentCaptureKeys.idIssuanceAuthority,
        IdentificationDocumentCaptureKeys.idReference,
        IdentificationDocumentCaptureKeys.idRegistrationLocation,
        IdentificationDocumentCaptureKeys.idPresentAddress,
        IdentificationDocumentCaptureKeys.idPermanentAddress
    ]
    
    
    let translationKeys = [
        IdentificationDocumentCaptureKeys.idType,
        IdentificationDocumentCaptureKeys.idArmyStatus,
        IdentificationDocumentCaptureKeys.idCountryOfStay,
        IdentificationDocumentCaptureKeys.idRegion,
        IdentificationDocumentCaptureKeys.idMaritalStatus,
        IdentificationDocumentCaptureKeys.documentType,
        IdentificationDocumentCaptureKeys.country,
        IdentificationDocumentCaptureKeys.nationality,
        IdentificationDocumentCaptureKeys.sex,
        IdentificationDocumentCaptureKeys.idDateOfIssuance,
        IdentificationDocumentCaptureKeys.documentNumber,
        IdentificationDocumentCaptureKeys.birthDate,
        IdentificationDocumentCaptureKeys.expiryDate,
        IdentificationDocumentCaptureKeys.idFamilyNumber,
        IdentificationDocumentCaptureKeys.identityNumberBack,
        IdentificationDocumentCaptureKeys.idIdentityNumber,
        IdentificationDocumentCaptureKeys.idFaceColor,
        IdentificationDocumentCaptureKeys.idEyeColor,
        IdentificationDocumentCaptureKeys.idSpecialMarks,
        IdentificationDocumentCaptureKeys.idDocumentTypeNumber,
        IdentificationDocumentCaptureKeys.idFees,
        IdentificationDocumentCaptureKeys.idUniqueNumber,
        IdentificationDocumentCaptureKeys.idProfession,
        IdentificationDocumentCaptureKeys.idDrivingCategory,
        IdentificationDocumentCaptureKeys.idBloodType,
        IdentificationDocumentCaptureKeys.idCivilRegisterNumber,
        IdentificationDocumentCaptureKeys.faceCapture,
        IdentificationDocumentCaptureKeys.image,
        IdentificationDocumentCaptureKeys.capturedVideoFront,
        IdentificationDocumentCaptureKeys.capturedVideoBack,
        IdentificationDocumentCaptureKeys.livenessStatus,
        IdentificationDocumentCaptureKeys.isFrontAuth,
        IdentificationDocumentCaptureKeys.isBackAuth,
        IdentificationDocumentCaptureKeys.isExpired,
        IdentificationDocumentCaptureKeys.isTampering,
        IdentificationDocumentCaptureKeys.tamperHeatMap,
        IdentificationDocumentCaptureKeys.isBackTampering,
        IdentificationDocumentCaptureKeys.backTamperHeatmap,
        IdentificationDocumentCaptureKeys.originalFrontImage,
        IdentificationDocumentCaptureKeys.originalBackImage,
        IdentificationDocumentCaptureKeys.ghostImage,
        IdentificationDocumentCaptureKeys.isSkippedAfterNFails,
        IdentificationDocumentCaptureKeys.isFailedFront,
        IdentificationDocumentCaptureKeys.isFailedBack,
        IdentificationDocumentCaptureKeys.skippedStatus
    ]
    
    if transliterationKeys.contains(where: key.contains) {
        return LanguageTransformationEnum.Transliteration
    } else if translationKeys.contains(where: key.contains) {
        return LanguageTransformationEnum.Translation
    } else {
        return LanguageTransformationEnum.Transliteration
    }
}


public func getLDataType(key: String) -> String {
    let textKeys = [
        IdentificationDocumentCaptureKeys.name,
        IdentificationDocumentCaptureKeys.surname,
        IdentificationDocumentCaptureKeys.documentType,
        IdentificationDocumentCaptureKeys.country,
        IdentificationDocumentCaptureKeys.nationality,
        IdentificationDocumentCaptureKeys.idType,
        IdentificationDocumentCaptureKeys.idMaritalStatus,
        IdentificationDocumentCaptureKeys.idPlaceOfResidence,
        IdentificationDocumentCaptureKeys.idProvince,
        IdentificationDocumentCaptureKeys.idGovernorate,
        IdentificationDocumentCaptureKeys.idMothersName,
        IdentificationDocumentCaptureKeys.idFathersName,
        IdentificationDocumentCaptureKeys.idPlaceOfBirth,
        IdentificationDocumentCaptureKeys.idDrivingCategory,
        IdentificationDocumentCaptureKeys.idIssuanceAuthority,
        IdentificationDocumentCaptureKeys.idArmyStatus,
        IdentificationDocumentCaptureKeys.idProfession,
        IdentificationDocumentCaptureKeys.idFees,
        IdentificationDocumentCaptureKeys.idReference,
        IdentificationDocumentCaptureKeys.idRegion,
        IdentificationDocumentCaptureKeys.idRegistrationLocation,
        IdentificationDocumentCaptureKeys.idFaceColor,
        IdentificationDocumentCaptureKeys.idEyeColor,
        IdentificationDocumentCaptureKeys.idSpecialMarks,
        IdentificationDocumentCaptureKeys.idCountryOfStay,
        IdentificationDocumentCaptureKeys.idPresentAddress,
        IdentificationDocumentCaptureKeys.idPermanentAddress,
        IdentificationDocumentCaptureKeys.sex,
        IdentificationDocumentCaptureKeys.faceCapture,
        IdentificationDocumentCaptureKeys.image,
        IdentificationDocumentCaptureKeys.isSkippedAfterNFails,
        IdentificationDocumentCaptureKeys.isFailedFront,
        IdentificationDocumentCaptureKeys.isFailedBack,
        IdentificationDocumentCaptureKeys.skippedStatus,
        IdentificationDocumentCaptureKeys.capturedVideoFront,
        IdentificationDocumentCaptureKeys.capturedVideoBack,
        IdentificationDocumentCaptureKeys.livenessStatus,
        IdentificationDocumentCaptureKeys.isFrontAuth,
        IdentificationDocumentCaptureKeys.isBackAuth,
        IdentificationDocumentCaptureKeys.isExpired,
        IdentificationDocumentCaptureKeys.isTampering,
        IdentificationDocumentCaptureKeys.tamperHeatMap,
        IdentificationDocumentCaptureKeys.isBackTampering,
        IdentificationDocumentCaptureKeys.backTamperHeatmap,
        IdentificationDocumentCaptureKeys.originalFrontImage,
        IdentificationDocumentCaptureKeys.originalBackImage,
        IdentificationDocumentCaptureKeys.ghostImage
    ]
    
    let dateKeys = [
        IdentificationDocumentCaptureKeys.birthDate,
        IdentificationDocumentCaptureKeys.expiryDate,
        IdentificationDocumentCaptureKeys.idDateOfIssuance
    ]
    
    let numberKeys = [
        IdentificationDocumentCaptureKeys.idIdentityNumber,
        IdentificationDocumentCaptureKeys.idUniqueNumber,
        IdentificationDocumentCaptureKeys.idFamilyNumber,
        IdentificationDocumentCaptureKeys.identityNumberBack,
        IdentificationDocumentCaptureKeys.idDocumentTypeNumber,
        IdentificationDocumentCaptureKeys.idCivilRegisterNumber,
        IdentificationDocumentCaptureKeys.documentNumber
    ]
    
    if textKeys.contains(where: key.contains) {
        return DataType.Text
    } else if dateKeys.contains(where: key.contains) {
        return  DataType.Date
    } else if numberKeys.contains(where: key.contains) {
        return  DataType.Text // Should be number
    } else {
        return DataType.Text
    }
}

public func ignoredKeys(key: String) -> Bool {
    let ignoredKeys = [
        IdentificationDocumentCaptureKeys.capturedVideoFront,
        IdentificationDocumentCaptureKeys.capturedVideoBack,
        IdentificationDocumentCaptureKeys.livenessStatus,
        IdentificationDocumentCaptureKeys.isFrontAuth,
        IdentificationDocumentCaptureKeys.isBackAuth,
        IdentificationDocumentCaptureKeys.isExpired,
        IdentificationDocumentCaptureKeys.isTampering,
        IdentificationDocumentCaptureKeys.tamperHeatMap,
        IdentificationDocumentCaptureKeys.isBackTampering,
        IdentificationDocumentCaptureKeys.backTamperHeatmap,
        IdentificationDocumentCaptureKeys.originalFrontImage,
        IdentificationDocumentCaptureKeys.originalBackImage,
        IdentificationDocumentCaptureKeys.ghostImage,
        IdentificationDocumentCaptureKeys.isSkippedAfterNFails,
        IdentificationDocumentCaptureKeys.isFailedFront,
        IdentificationDocumentCaptureKeys.isFailedBack,
        IdentificationDocumentCaptureKeys.skippedStatus,
        IdentificationDocumentCaptureKeys.image,
        IdentificationDocumentCaptureKeys.faceCapture
    ]
    
    return ignoredKeys.contains(where: key.contains)
}

public func getIgnoredProperties(properties: [String: Any]) -> [String: String] {
    var ignoredProperties: [String: String] = [:]
    for (key, value) in properties {
        if ignoredKeys(key: key) {
            ignoredProperties[key] = "\(value)"
        }
    }
    return ignoredProperties
}


public func preparePropertiesToTranslate(language: String, properties: [String: Any]?) -> TransformationModel {
    var languageTransformationModels: [LanguageTransformationModel] = []
    var name = "";
    var surname = "";
    for (key, value) in properties! {
        if (key.contains(IdentificationDocumentCaptureKeys.name)) {
            name = "\(value)";
        }
        if (key.contains(IdentificationDocumentCaptureKeys.surname)) {
            surname = "\(value)";
        }
    }
    var  fulName =  name+" "+surname
    for (key, value) in properties! {
        if !ignoredKeys(key: key) {
            if (!key.contains(IdentificationDocumentCaptureKeys.name) && !key.contains(
                IdentificationDocumentCaptureKeys.surname)) {
                let model = LanguageTransformationModel(
                    languageTransformationEnum: getLanguageTransformationEnum(key: key),
                    key: key,
                    value: "\(value)",
                    language: language,
                    dataType: getLDataType(key: key)
                )
                languageTransformationModels.append(model)
            }else{
                let model = LanguageTransformationModel(
                    languageTransformationEnum: LanguageTransformationEnum.Transliteration,
                    key: FullNameKey,
                    value: fulName,
                    language: language,
                    dataType: getLDataType(key: key)
                )
                languageTransformationModels.append(model)
            }
           
        }
    }
    return TransformationModel(languageTransformationModels: languageTransformationModels)
}
