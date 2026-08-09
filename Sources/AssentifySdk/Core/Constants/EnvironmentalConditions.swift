

import Foundation



public class EnvironmentalConditions {


    /**Detect**/
    var enableDetect: Bool
    var enableGuide: Bool

    
    var HoldHandColor: String
    var CountDownNumbersColor: String


    var MotionLimit : Int
    var MotionLimitFace : Int
    
    
    var BRIGHTNESS_HIGH_THRESHOLD: Double
    var BRIGHTNESS_LOW_THRESHOLD: Double
    

    var activeLiveType: ActiveLiveType
    
    var activeLivenessCheckCount:Int
    
    var faceLivenessRetryCount : Int = 2

    var minRam : Int = 2
    var minCPUCores : Int = 6
    
    var flowUiLanguage: String = UiLanguage.English


    public  init(
        enableDetect: Bool = true,
        CountDownNumbersColor: String = "#00FFFFFF",
        HoldHandColor: String,
        BRIGHTNESS_HIGH_THRESHOLD :Double  = 255.0,
        BRIGHTNESS_LOW_THRESHOLD:Double = 50.0,
        MotionLimit:Int = 30,
        MotionLimitFace:Int = 5,
        activeLiveType:ActiveLiveType = ActiveLiveType.NONE,
        activeLivenessCheckCount:Int = 0,
        faceLivenessRetryCount:Int = 2,
        minRam:Int = 8,
        minCPUCores:Int = 6,
        flowUiLanguage:String = UiLanguage.English
    ) {
        self.enableDetect = enableDetect
        self.enableGuide = true
        self.CountDownNumbersColor = CountDownNumbersColor
        self.HoldHandColor = HoldHandColor
        self.BRIGHTNESS_HIGH_THRESHOLD = BRIGHTNESS_HIGH_THRESHOLD
        self.BRIGHTNESS_LOW_THRESHOLD = BRIGHTNESS_LOW_THRESHOLD
        self.MotionLimit = MotionLimit
        self.MotionLimitFace = MotionLimitFace
        self.activeLiveType = activeLiveType
        self.activeLivenessCheckCount = activeLivenessCheckCount
        self.faceLivenessRetryCount = faceLivenessRetryCount
        self.minRam = minRam
        self.minCPUCores = minCPUCores
        self.flowUiLanguage = flowUiLanguage

        // Perform validation checks
        precondition(!self.HoldHandColor.isEmpty, "Invalid HoldHandColor value")
    }

    func checkConditions(brightness: Double) -> BrightnessEvents {
        if brightness < BRIGHTNESS_LOW_THRESHOLD {
            return BrightnessEvents.TooDark
        } else if brightness > BRIGHTNESS_HIGH_THRESHOLD {
            return BrightnessEvents.TooBright
        } else {
            return BrightnessEvents.Good
        }
    }


    func isPredictionValid(confidence: Float) -> Bool {
        let isValid = (confidence * 100) >= ConstantsValues.PREDICTION_LOW_PERCENTAGE && (confidence * 100) <= ConstantsValues.PREDICTION_HIGH_PERCENTAGE
        return isValid
    }

    func chekMotionValid(motion: Double) -> Bool {
        let MOTION_LOW_THRESHOLD = 0.0
        let MOTION_HIGH_THRESHOLD = 5.0

        return motion >= MOTION_LOW_THRESHOLD && motion <= MOTION_HIGH_THRESHOLD || motion == 0.0
    }
}


