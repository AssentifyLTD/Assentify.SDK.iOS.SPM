# AssentifySdk

[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/cocoapods/l/AssentifySdk.svg?style=flat)](https://cocoapods.org/pods/AssentifySdk)
[![Platform](https://img.shields.io/cocoapods/p/AssentifySdk.svg?style=flat)](https://cocoapods.org/pods/AssentifySdk)

## Example

[To run the example project](https://github.com/AssentifyLTD/Assentify.IOS.Demo)

## Documentation 
[Assentify Sdk Documentation](https://drive.google.com/file/d/1nd_KjBy-9NXs0-ub2YCb4YTlJW650Po3/view?usp=sharing)

## Requirements

- iOS 15.0+
- Swift 5.7+

## Installation

AssentifySdk is available through [Swift Package Manager](https://swift.org/package-manager/).

### Using Xcode

1. Go to **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/AssentifyLTD/Assentify.SDK.iOS.SPM.git
   ```
3. Choose the version rule (e.g. **Up to Next Major** or an **Exact** version)
4. Add the `AssentifySdk` library to your target

### Using Package.swift

Add the following to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/AssentifyLTD/Assentify.SDK.iOS.SPM.git", from: "1.0.0-Beta.21")
]
```

Then add `AssentifySdk` to your target's dependencies:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            "AssentifySdk"
        ]
    )
]
```

## Dependencies

AssentifySdk pulls in the following packages automatically via SPM:

- [SVGKit](https://github.com/SVGKit/SVGKit)
- [NFCPassportReader](https://github.com/AndyQ/NFCPassportReader)
- [Bugsnag](https://github.com/bugsnag/bugsnag-cocoa)
- [BugsnagPerformance](https://github.com/bugsnag/bugsnag-cocoa-performance)
- [TensorFlowLiteSwift](https://github.com/kewlbear/TensorFlowLiteSwift)

## Versions

**1.0.0-Beta.21**
1.⁠ ⁠*Support Local Passport Scan*

**1.0.0-Beta.20**
1.⁠ ⁠*iOS 15+ support.*

**1.0.0-Beta.19**

1.⁠ ⁠*Added full RTL (Right-to-Left) and LTR (Left-to-Right) , Arabic and English layout support.*
2.⁠ ⁠*Enhanced the slider click animation*

**1.0.0-Beta.18**
1. *Support for initializing the SDK using a file path*

**1.0.0-Beta.17**
1. *"Assisted Data Entry Step" Improvements*

**1.0.0-Beta.16**
1. *Enhanced Flow Design*

**1.0.0-Beta.15**
1. *Optimized OTP Delivery Process*

**1.0.0-Beta.14**
1. *Optimized Face Match Experience*

**1.0.0-Beta.13**
1. *Support for new button design*

**1.0.0-Beta.12**
1. *Support for new button design*

**1.0.0-Beta.11**
1. *Enhanced Flow Design*

**1.0.0-Beta.10**
1. *Enhanced User Experience*
2. *Auto Generated Signature*

**1.0.0-Beta.9**
1. *Enhanced User Experience*
2. *Auto Generated Signature*

**1.0.0-Beta.8**
1. *Enhanced User Experience

**1.0.0-Beta.7**
1. *Enhanced The Overall User Experience*

**1.0.0-Beta.6**
1. *Support Clean Flow And Start Again*

**1.0.0-Beta.5**
1. *Support Clean Flow And Start Again*

**1.0.0-Beta.4**
1. *Support SDK initialization from local configuration file*
2. *Support email and phone number OTP verification on the signing step*
 
**1.0.0-Beta.3**
 1. *Support filters for Assisted Data Entry*
 2. *Support events on step completion*

 
**1.0.0-Beta.2**
 1. *Support split step*

**1.0.0-Beta.1**
 1. *Support split step*

**1.0.0-alpha.3**
 1. *Support multiple flows*
 
**1.0.0-alpha.2**
 1. *Full Flows integration*

**1.0.0-alpha.1**
 1. *Full Flows integration*

**0.0.79**
 1. *Update MLKit Face Detection *  

**0.0.78**
 1. *Error Message handling*  

**0.0.77**
 1. *Ability to add transparent color in the initialization*  
 
**0.0.76**
 1. *Improved Submit Flow Handling , When calling start SubmitData, it is no longer necessary to include the BlockLoader or WrapUp steps in the submitList.*  

**0.0.75**
 1. *Add "applicationId" to the Config Model*  
 2. *Change idType and idArmyStatus from Transliteration to Translation*  
  
**0.0.74**
 1. *Fixes issues related to old swift versions*  

**0.0.73**
1. *Simplified SDK Initialization*  
   - You no longer need to pass the following parameters when initializing the SDK:  
     - `processMrz`  
     - `performLivenessDocument`  
     - `performPassiveLivenessFace`  
     - `saveCapturedVideo`  
     - `storeCapturedDocument`  
     - `storeImageStream`  
   - These options are now fully configurable from the **portal**, removing the need for extra code changes.  

2. *New Feature: Manual QR Scan*  
   - Added support for **manual QR code scanning**, allowing users to scan QR codes manually on low-capability devices.  

**0.0.72**
- Face Liveness Improvements

**0.0.71**
- Callbacks Improvements
- Captured Image Improvements

**0.0.70**
- Manual Capture
- Retry Logic
- Support Low Capabilities Devices

**0.0.69**
- Bug fixes 

**0.0.68**
- Supports iOS 18.6

**0.0.67**
- Logs Improvements

**0.0.66**
- Blink Improvements

**0.0.65**
- Blink Liveness
- Adding Logs

**0.0.64**
- Face Liveness Improvements

**0.0.63**
- Wink Liveness
- Liveness Controller
- Motion Controller
- Brightness Controller

**0.0.62**
- Swift Versions Handling

**0.0.61**
- NFC Scanning

**0.0.60**
- Qr improvements
- Face improvements

**0.0.59**
- Qr Scanning

**0.0.58**
- Face Liveness flags control

**0.0.57**
- Pods update

**0.0.56**
- Detect improvements

**0.0.55**
- Active liveness Design improvements
- Adding Steps Map

**0.0.54**
- Active liveness improvements
- Multiple Steps handling

**0.0.53**
- UI enhancement

**0.0.52**
- Active liveness

**0.0.51**
- Detect improvements

**0.0.50**
- Face match improvements

**0.0.49**
- Face events threshold improvements

**0.0.48**
- Face detect improvements

**0.0.47**
- Face match improvements

**0.0.46**
- Face liveness improvements
- Parameters change :onEnvironmentalConditionsChange 
- Parameters change :EnvironmentalConditions

**0.0.45**
- Face events improvements
- Face zoom improvements
- Face brightness improvements
- Face liveness improvements


**0.0.44**
- Bug Fixes

**0.0.43**
- UI Fixes

**0.0.42**
- Context Aware Signing Step

**0.0.41**
- Improve scanning speed

**0.0.40**
- Face match improvements

**0.0.39**
- Adding the face liveness check parameter
- Adding the Document liveness check parameter
- Enhance the translate feature
- Null check for the initialization parameters

**0.0.38**
- Improve scan time performance

**0.0.37**
- Handel the intermittent internet connectivity

**0.0.36.1** Alpha Version
- Local face liveness check

**0.0.36**
- Matching The Templates With The Admin Portal Selected  Templates

**0.0.35**
- Removing The Detect And Guide during The Transmitting Process

**0.0.34**
- Enhance The Translation / Transliteration Feature

**0.0.33**
- bug fixes and performance improvements

**0.0.32**
- bug fixes and performance improvements

**0.0.31**
- Image lossless compression

**0.0.30**
- Face Match Countdown

**0.0.29**
- Face freezing : Resolved the issue

**0.0.28**
- Image Size : Improved image size .
- Templates Update: Change the Templates implementation from callback to normal function .
- Motion : Optimized motion handling for smoother performance during face and ID scanning.
- Memory Check: Check memory usage during scanning to prevent performance issues.
- Face Freeze Bug Fix: Resolved the issue where face freezing occurred during the face matching process.

**0.0.27**
- bug fixes and performance improvements

**0.0.26**
- bug fixes and performance improvements

**0.0.25**
- bug fixes and performance improvements

## Author

Assentify, info.assentify@gmail.com

## License

AssentifySdk is available under the MIT license. See the LICENSE file for more info.
