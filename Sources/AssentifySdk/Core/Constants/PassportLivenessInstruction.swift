import Foundation

/// What the user should do now during the passport liveness, sent with the tilt meter (0..100) through
/// ScanPassportDelegate.onLivenessInstruction(instruction:progress:). Same 15 cases as PassportLivenessInstruction.kt.
/// The three pause cases are shown for a few seconds; the SDK continues by itself.
@objc public enum PassportLivenessInstruction: Int {
    case placeDocument      // position: show the photo page
    case keepSteady         // flat hold: hold still
    case keepFlat           // flat hold: hold it flat
    case adjustPosition     // flat hold: glare, tilt it slightly
    case doNotMove          // light: the light is on
    case liftBottom         // tilt: lift the bottom edge (the meter shows how far)
    case moveALittleMore    // tilt reached, colours awaited: "A bit more"
    case holdThere          // tilt held open, the page at the picture's edge
    case otherSide          // tilt: the other edge
    case holdItUp           // tilt: not moving, hold it in your hand
    case placeFlatAgain     // (not sent by rc17)
    case keepHolding        // done: the photo is being sent
    case holdInHand         // pause: on a table
    case phoneTurned        // pause: the phone turned in the tilt
    case tooBright          // pause: sun
}
