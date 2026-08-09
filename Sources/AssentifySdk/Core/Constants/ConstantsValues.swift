
import Foundation

//static let BRIGHTNESS_HIGH_THRESHOLD: Double = 255.0
//static let BRIGHTNESS_LOW_THRESHOLD: Double = 50.0

struct ConstantsValues {
    static let DetectColor = "#00FF00"
    static let InputFaceModelSize = 224
    static let ModelLivenessFileName = "check-liveness"
    static let PREDICTION_LOW_PERCENTAGE: Float = 00.0
    static let PREDICTION_HIGH_PERCENTAGE: Float = 100.0
    static let LIVENESS_THRESHOLD  = 0.9;
    static let FaceCheckQualityThresholdPositive = 15.0;
    static let FaceCheckQualityThresholdNegative = -15.0;
    static let FaceCheckQualityThresholdNPositivePitch = 15.0;
    static let FaceCheckQualityThresholdNegativePitch = -15.0;
    static let AudioFaceSuccess = "audio_face_success.mp3";
    static let AudioCardSuccess = "audio_card_success.mp3";
    static let AudioWrong = "audio_wrong.mp3";
    static let ClarityProjectId = "spm0s4tjn6";
    static let BugsnagApiKey = "c43ad13958ab6db91b5a46670021a2f4";
    static let providedFaceImageKey = "OnBoardMe_IdentificationDocumentCapture_Image";
}


public struct StepsNames {
    public   static let wrapUp = "WrapUp"
    public   static let blockLoader = "BlockLoader"
    public   static let termsConditions = "TermsConditions"
    public   static let assistedDataEntry = "AssistedDataEntry"
    public   static let faceImageAcquisition = "FaceImageAcquisition"
    public   static let identificationDocumentCapture = "IdentificationDocumentCapture"
    public   static let contextAwareSigning = "ContextAwareSigning"
    public   static let split = "Split"
}

public struct WrapUpKeys {
    public   static let timeEnded = "OnBoardMe_WrapUp_TimeEnded"
}


public struct EventsErrorMessages {
    public   static let OnErrorMessage = "Your internet connection seems unstable. Please check your connection and try again"

    public   static let OnWrongTemplateMessage = "Please double-check that you selected the correct ID type and presenting this ID type"
    public   static let OnRetryCardMessage = "We could not read your card. Try again in better lighting and make sure the card is clear and visible"
    public   static let OnLivenessCardUpdateMessage = "Please use your original physical ID card, not a photo or copy"

    public   static let OnRetryFaceMessage = "We could not complete your request"
    public   static let OnLivenessFaceUpdateMessage = "Please make sure your face is well lit, look directly at the camera, and avoid using photos or videos"
    public   static let OnExpiredPassportMessage = "Expired Passport Detected"
}


public struct BlockLoaderKeys {
    public  static let deviceName = "OnBoardMe_BlockLoader_DeviceName"
    public   static let flowName = "OnBoardMe_BlockLoader_FlowName"
    public   static let timeStarted = "OnBoardMe_BlockLoader_TimeStarted"
    public   static let application = "OnBoardMe_BlockLoader_Application"
    public   static let userAgent = "OnBoardMe_BlockLoader_UserAgent"
    public   static let instanceHash = "OnBoardMe_BlockLoader_InstanceHash"
    public   static let interactionID = "OnBoardMe_BlockLoader_Interaction"
}


public func getTimeUTC() -> String {
      let currentDate = Date()
      let formatter = DateFormatter()
      formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
      formatter.timeZone = TimeZone(abbreviation: "UTC")
      formatter.locale = Locale(identifier: "en_US_POSIX")
      let utcTime = formatter.string(from: currentDate)
      return utcTime
  }

public func getIDTag(configModel: ConfigModel, templateName: String) -> String {
    return "\(configModel.tenantIdentifier)/\(configModel.instanceId),\(templateName)"
}


public struct IDQrKeys {

    public static let faceCapture =
        "OnBoardMe_IdentificationDocumentCapture_FaceCapture"

    public static let capturedVideoFront =
        "OnBoardMe_IdentificationDocumentCapture_CapturedVideoFront"

    public static let image =
        "OnBoardMe_IdentificationDocumentCapture_Image"

    public static let originalFrontImage =
        "OnBoardMe_IdentificationDocumentCapture_OriginalFrontImage"

    public static let ghostImage =
        "OnBoardMe_IdentificationDocumentCapture_GhostImage"

    private init() {} // prevent initialization
}

public  func getCurrentDateTimeForTracking() -> String {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [
          .withInternetDateTime,
          .withFractionalSeconds
      ]
      return formatter.string(from: Date())
  }
