import Foundation

/// What the user should do now during the local liveness of a CARD (Lebanese civil ID front / back, driving licence,
/// residence permit), sent with the tilt meter (0..100) through ScanIDCardDelegate.onLivenessInstruction(instruction:progress:).
/// The three pause items are shown for a few seconds; the SDK continues by itself. Port of IdLivenessInstruction.kt.
@objc public enum IdLivenessInstruction: Int {
    case placeCard          // position: show the card in the frame
    case keepSteady         // baseline: hold still
    case keepFlat           // baseline: hold it flat, facing the camera
    case adjustPosition     // baseline: glare on the card, tilt it slightly
    case doNotMove          // light: the light is on for a few seconds (ID front: the cedar is being read)
    case liftRight          // tilt, ID front: lift the RIGHT edge toward you
    case liftTop            // tilt, licence / permit (random): lift the TOP edge toward you
    case liftBottom         // tilt, licence / permit (random): lift the BOTTOM edge toward you
    case aBitMore           // tilt reached, held open: ID front a little further (cedar), licence rock it gently (colours)
    case holdThere          // tilt held open, the card at the picture's edge
    case otherEdge          // tilted the wrong edge
    case pickUp             // not moving: hold the card in your hand
    case keepHolding        // done: the check passed, the photo is being sent
    case readingBarcode     // ID back, after its photo: reading the barcode; goes on read or not
    case barcodeRead        // ID back: the barcode was read

    // ---- pauses (the SDK continues by itself) ----
    case holdInHand         // on a table: hold the card in your hand
    case phoneTurned        // the phone turned in the tilt: move the card, not the phone
    case tooBright          // sun: too much light here

    /// The tilt meter is shown under the instruction for these (it shows 100% at the end); hidden otherwise.
    public var showsTiltMeter: Bool {
        switch self {
        case .liftRight, .liftTop, .liftBottom, .aBitMore, .holdThere, .otherEdge, .pickUp, .keepHolding: return true
        default: return false
        }
    }

    /// The liveness owns the instruction text while it runs (not once the photo is being sent / the barcode is read).
    public var livenessActive: Bool {
        self != .keepHolding && self != .barcodeRead
    }
}
