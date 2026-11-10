import Foundation

/// Document-liveness thresholds, read from rectifier_config_file.json (the same policy file the web uses),
/// bundled INSIDE THE SDK: a Swift Package's Resources (Bundle.module), else the framework's own bundle.
/// In an SDK, Bundle.main is the HOST app's bundle, so it is only the last fallback.
///
///     let cfg = try LivenessConfig.load(kind: "lb_passport")
///     cfg.lossMs, cfg.upDown.tiltMin, cfg.profile.aspect, cfg.laminatePolicy() ...
///
/// The document kind is always a parameter: it must be a key under "profiles" in the file.
/// Times are milliseconds (Int). Port of LivenessConfig.kt.
public final class LivenessConfig {

    public enum ConfigError: Error {
        case fileNotFound(String)
        case unreadable(String)
        case unknownKind(String, available: [String])
    }

    public var policyVersion: String = "2026-10-22.10"
    public var packageVariant: String = "rc17+lb-passport-spread"
    public var batteryLowBelow: Double = 0.05
    public var analysisLongEdge: Int = 720
    public var minQuadAreaFrac: Double = 0.08
    public var tiltOverflow: Double = 0.15
    public var frameMarginPx: Double = 4.0
    public var stableMs: Int = 300
    public var baselineHoldMs: Int = 400
    public var finalHoldMs: Int = 400
    public var lossMs: Int = 1500
    public var phaseTimeoutMs: Int = 15000
    public var maxAttempts: Int = 3
    public var maxRestarts: Int = 8
    public var edgeMargin: Double = 0.02
    public var maxEarlyRestarts: Int = 40
    public var frontalMax: Double = 0.16
    public var shapeTol: Double = 0.1
    public var angleMax: Double = 0.17
    public var secondDocFrac: Double = 0.25
    public var samePlaceMax: Double = 0.08
    public var initTimeoutMs: Int = 300000
    public var initStallMs: Int = 60000
    public var loadSlowMs: Int = 20000
    public var stallMs: Int = 6000
    public var tiltHoldMs: Int = 4000
    public var stuckMs: Int = 3000
    public var wrongWayFrames: Int = 4
    public var hintAfterMs: Int = 3000
    public var repeatAfterMs: Int = 6000
    public var autoBackMs: Int = 1800
    public var turnMs: Int = 2500
    public var reviewMs: Int = 10000
    public var turnAfterReviewMs: Int = 900
    public var slowCheckMs: Int = 8000
    public var checkStepsMs: Int = 8000
    public var longerLineMs: Int = 4500
    public var verifyTimeoutMs: Int = 45000
    public var endOnTilt: Bool = true
    public var sweeps: Int = 1
    public var tiltMin: Double = 0.05
    public var tiltNoiseK: Double = 3.0
    public var sweepFrames: Int = 3
    public var returnTol: Double = 0.05
    public var returnFrames: Int = 2
    public var jitterMax: Double = 0.015
    public var driftMax: Double = 0.03
    public var aspectJumpMax: Double = 0.15
    public var tiltAspectJumpMax: Double = 0.35
    public var tiltStepMin: Double = 0.1
    public var areaJumpMax: Double = 1.6
    public var sharpnessMin: Double = 60.0
    public var glareFracMax: Double = 0.04
    public var otherPassportLaminatePolicy: String = "shadow"
    public var spreadCutMax: Double = 0.05

    public let hands = Hands()
    public let sendPhoto = SendPhoto()
    public let back = Back()
    public let upDown = UpDown()
    public let laminate = Laminate()
    public let civilExtract = CivilExtract()
    public let overlay = Overlay()
    public let backShown = BackShown()
    public let idBarcode = IdBarcode()
    public let drivingLicence = LaminateDoc()
    public let residencePermit: LaminateDoc = { let d = LaminateDoc(); d.evidence = "licence trials"; return d }()
    public let optical = Optical()
    public let reflection = Reflection()
    public let light = Light()
    public let emblem = Emblem()
    public let face = Face()
    public let evidence = Evidence()

    /// The profile for the requested document kind (lb_passport, other_passport, ...).
    public var profile = Profile()

    public final class Hands {
        public var flatDeg: Double = 10.0
        public var flatMs: Int = 800
        public var tableCard: Bool = true
        public var turnDeg: Double = 20.0
        public var maxPauses: Int = 1
    }

    public final class SendPhoto {
        public var maxSide: Int = 1920
        public var quality: Double = 0.9
    }

    public final class Back {
        public var sweeps: Int = 0
        public var policy: String = "shadow"
        public var glareWaitMs: Int = 3000
    }

    public final class UpDown {
        public var tiltMin: Double = 0.08
        public var holdFrames: Int = 6
        public var pageDirection: String = "bottom"
    }

    public final class Laminate {
        public var minLitFrames: Int = 3
        public var minHues: Int = 3
        public var minPeak: Double = 0.001
        public var minFrames: Int = 6
        public var strongHues: Int = 5
        public var strongPeak: Double = 0.003
        public var passportStrong: Bool = true
        public var passportHues: Int = 4
        public var policy: String = "enforce"
    }

    public final class CivilExtract {
        public var holdMs: Int = 300
        public var lightMs: Int = 900
        public var minFill: Double = 0.18
        public var steadyMs: Int = 700
        public var steadyMove: Double = 0.02
        public var buttonAfterMs: Int = 10000
        public var codeMs: Int = 25000
        public var codeEveryMs: Int = 350
        public var maxRestarts: Int = 2
    }

    public final class Overlay {
        public var policy: String = "enforce"
        public var bar: Double = 4.5
        public var barSeveral: Double = 3.5
        public var waitMs: Int = 1500
    }

    public final class BackShown {
        public var policy: String = "shadow"
        public var bar: Double = 0.3
        public var everyMs: Int = 300
        public var withinMs: Int = 12000
        public var hintAfterMs: Int = 1500
    }

    public final class IdBarcode {
        public var everyMs: Int = 250
        public var waitMs: Int = 8000
    }

    public final class LaminateDoc {
        public var laminatePolicy: String = "enforce"
        public var holdMs: Int = 6000
        public var tiltShare: Double = 0.6
        public var evidence: String = ""
    }

    public final class Optical {
        public var minFrames: Int = 6
        public var supportRatio: Double = 2.0
        public var staticRatio: Double = 1.2
        public var controlMax: Double = 20.0
        public var policy: String = "shadow"
    }

    public final class Reflection {
        public var flareMin: Double = 0.0002
        public var whiteoutMax: Double = 0.3
        public var chromaMin: Double = 0.03
        public var minLitFrames: Int = 2
        public var liftMin: Double = 1.02
        public var brightLift: Double = 1.25
        public var sunMax: Double = 3.0
        public var policy: String = "enforce"
    }

    public final class Light {
        public var frames: Int = 5
        public var settleMs: Int = 300
        public var maxMs: Int = 2500
        public var offSettleMs: Int = 500
        public var offMaxMs: Int = 4000
        public var barcodeMs: Int = 3000
    }

    public final class Emblem {
        public var litMin: Double = 7.0
        public var jumpMin: Double = 8.0
        public var strongLit: Double = 16.0
        public var testTilt: Double = 0.12
        public var tiltTarget: Double = 0.15
        public var holdMs: Int = 8000
        public var minFrames: Int = 2
        public var extraMs: Int = 3000
        public var darkMax: Double = 0.6
        public var minTiltFrames: Int = 3
        public var tiltSide: Double = 0.05
        public var direction: String = "right"
        public var policy: String = "enforce"
    }

    public final class Face {
        public var strongChroma: Double = 50.0
        public var strongColourMax: Double = 0.7
        public var inset: Double = 0.06
        public var policy: String = "enforce"
    }

    public final class Evidence {
        public var maxFrames: Int = 80
        public var maxBytes: Int = 20971520
    }

    /// Normalised rectangle on the straightened document (0..1).
    public struct Roi {
        public let x: Double, y: Double, w: Double, h: Double
    }

    public final class Profile {
        public var id: String = ""
        public var kind: String = ""
        public var aspect: Double = 0.0
        public var featureKind: String = "none"          // laminate_hologram / cedar / none
        public var featureRoi = Roi(x: 0.35, y: 0.3, w: 0.3, h: 0.3)
        public var controls: [Roi] = []
        public var iridescent: Bool = false
        public var page: Bool = false                    // passport data page
        public var spread: Bool = false                  // open booklet (two pages) may be in view
        public var sheet: Bool = false                   // civil extract
        public var minFill: Double = 0.0                 // lb_civil_id only (0 when absent)
        public var raw: [String: Any] = [:]              // full profile JSON (emblem, orient, ...)
    }

    /// Laminate policy for this document kind ("enforce" / "shadow").
    public func laminatePolicy() -> String {
        switch profile.kind {
        case LivenessConfig.KIND_OTHER_PASSPORT: return otherPassportLaminatePolicy
        case LivenessConfig.KIND_LB_DRIVING_LICENCE: return drivingLicence.laminatePolicy
        case LivenessConfig.KIND_LB_RESIDENCE_PERMIT: return residencePermit.laminatePolicy
        default: return laminate.policy
        }
    }

    /// True when the tilt is up/down (passport: lift the bottom edge).
    public func isUpDown() -> Bool { upDown.pageDirection == "bottom" || upDown.pageDirection == "top" }

    /// Tilt threshold for the configured page direction (passport: up/down -> bottom).
    public func tiltMinForPage() -> Double { isUpDown() ? upDown.tiltMin : tiltMin }

    /// Frames the tilt must be held for (up/down uses its own count).
    public func holdFramesForPage() -> Int { isUpDown() ? upDown.holdFrames : sweepFrames }

    // ---------------------------------------------------------------------------------------------
    // Loading
    // ---------------------------------------------------------------------------------------------

    public static let FILE_NAME = "rectifier_config_file"
    public static let KIND_LB_PASSPORT = "lb_passport"
    public static let KIND_OTHER_PASSPORT = "other_passport"
    public static let KIND_LB_CIVIL_ID = "lb_civil_id"
    public static let KIND_LB_CIVIL_ID_BACK = "lb_civil_id_back"
    public static let KIND_LB_DRIVING_LICENCE = "lb_driving_licence"
    public static let KIND_LB_CIVIL_EXTRACT = "lb_civil_extract"
    public static let KIND_LB_RESIDENCE_PERMIT = "lb_residence_permit"

    private static var cache: [String: LivenessConfig] = [:]
    private static let lock = NSLock()

    /// Loads (once, cached) the config for a document kind (a key under "profiles").
    public static func load(kind: String) throws -> LivenessConfig {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[kind] { return c }
        let root = try readRoot()
        let c = try parse(root, kind: kind)
        cache[kind] = c
        return c
    }

    /// All document kinds in the file (the keys under "profiles").
    public static func availableKinds() throws -> [String] {
        Array(((try readRoot())["profiles"] as? [String: Any] ?? [:]).keys)
    }

    /// Drops the cache (e.g. after downloading a newer policy file).
    public static func clearCache() { lock.lock(); cache.removeAll(); lock.unlock() }

    private static func readRoot() throws -> [String: Any] {
        guard let url = resourceURL(FILE_NAME, "json") else {
            throw ConfigError.fileNotFound(FILE_NAME + ".json")
        }
        guard let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ConfigError.unreadable(FILE_NAME + ".json at \(url.path)")
        }
        return root
    }

    /// A resource of the SDK: the Swift Package's resource bundle first (Bundle.module), then the framework's own
    /// bundle (CocoaPods / xcframework, and its resource bundles), then the host app's.
    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let u = Bundle.module.url(forResource: name, withExtension: ext) { return u }
        #endif
        let sdk = Bundle(for: LivenessConfig.self)
        if let u = sdk.url(forResource: name, withExtension: ext) { return u }
        for b in sdk.urls(forResourcesWithExtension: "bundle", subdirectory: nil) ?? [] {
            if let u = Bundle(url: b)?.url(forResource: name, withExtension: ext) { return u }
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    private static func readLaminateDoc(_ o: [String: Any], _ d: LaminateDoc) {
        d.laminatePolicy = o.str("laminatePolicy", d.laminatePolicy)
        d.holdMs = o.int("holdMs", d.holdMs)
        d.tiltShare = o.dbl("tiltShare", d.tiltShare)
        d.evidence = o.str("evidence", d.evidence)
    }

    private static func parse(_ root: [String: Any], kind: String) throws -> LivenessConfig {
        let c = LivenessConfig()
        let j = root.obj("config")

        c.packageVariant = root.str("packageVariant", c.packageVariant)
        c.policyVersion = j.str("policyVersion", root.str("policyVersion", c.policyVersion))

        c.batteryLowBelow = j.dbl("batteryLowBelow", c.batteryLowBelow)
        c.analysisLongEdge = j.int("analysisLongEdge", c.analysisLongEdge)
        c.minQuadAreaFrac = j.dbl("minQuadAreaFrac", c.minQuadAreaFrac)
        c.tiltOverflow = j.dbl("tiltOverflow", c.tiltOverflow)
        c.frameMarginPx = j.dbl("frameMarginPx", c.frameMarginPx)
        c.stableMs = j.int("stableMs", c.stableMs)
        c.baselineHoldMs = j.int("baselineHoldMs", c.baselineHoldMs)
        c.finalHoldMs = j.int("finalHoldMs", c.finalHoldMs)
        c.lossMs = j.int("lossMs", c.lossMs)
        c.phaseTimeoutMs = j.int("phaseTimeoutMs", c.phaseTimeoutMs)
        c.maxAttempts = j.int("maxAttempts", c.maxAttempts)
        c.maxRestarts = j.int("maxRestarts", c.maxRestarts)
        c.edgeMargin = j.dbl("edgeMargin", c.edgeMargin)
        c.maxEarlyRestarts = j.int("maxEarlyRestarts", c.maxEarlyRestarts)
        c.frontalMax = j.dbl("frontalMax", c.frontalMax)
        c.shapeTol = j.dbl("shapeTol", c.shapeTol)
        c.angleMax = j.dbl("angleMax", c.angleMax)
        c.secondDocFrac = j.dbl("secondDocFrac", c.secondDocFrac)
        c.samePlaceMax = j.dbl("samePlaceMax", c.samePlaceMax)
        c.initTimeoutMs = j.int("initTimeoutMs", c.initTimeoutMs)
        c.initStallMs = j.int("initStallMs", c.initStallMs)
        c.loadSlowMs = j.int("loadSlowMs", c.loadSlowMs)
        c.stallMs = j.int("stallMs", c.stallMs)
        c.tiltHoldMs = j.int("tiltHoldMs", c.tiltHoldMs)
        c.stuckMs = j.int("stuckMs", c.stuckMs)
        c.wrongWayFrames = j.int("wrongWayFrames", c.wrongWayFrames)
        c.hintAfterMs = j.int("hintAfterMs", c.hintAfterMs)
        c.repeatAfterMs = j.int("repeatAfterMs", c.repeatAfterMs)
        c.autoBackMs = j.int("autoBackMs", c.autoBackMs)
        c.turnMs = j.int("turnMs", c.turnMs)
        c.reviewMs = j.int("reviewMs", c.reviewMs)
        c.turnAfterReviewMs = j.int("turnAfterReviewMs", c.turnAfterReviewMs)
        c.slowCheckMs = j.int("slowCheckMs", c.slowCheckMs)
        c.checkStepsMs = j.int("checkStepsMs", c.checkStepsMs)
        c.longerLineMs = j.int("longerLineMs", c.longerLineMs)
        c.verifyTimeoutMs = j.int("verifyTimeoutMs", c.verifyTimeoutMs)
        c.endOnTilt = j.bool("endOnTilt", c.endOnTilt)
        c.sweeps = j.int("sweeps", c.sweeps)
        c.tiltMin = j.dbl("tiltMin", c.tiltMin)
        c.tiltNoiseK = j.dbl("tiltNoiseK", c.tiltNoiseK)
        c.sweepFrames = j.int("sweepFrames", c.sweepFrames)
        c.returnTol = j.dbl("returnTol", c.returnTol)
        c.returnFrames = j.int("returnFrames", c.returnFrames)
        c.jitterMax = j.dbl("jitterMax", c.jitterMax)
        c.driftMax = j.dbl("driftMax", c.driftMax)
        c.aspectJumpMax = j.dbl("aspectJumpMax", c.aspectJumpMax)
        c.tiltAspectJumpMax = j.dbl("tiltAspectJumpMax", c.tiltAspectJumpMax)
        c.tiltStepMin = j.dbl("tiltStepMin", c.tiltStepMin)
        c.areaJumpMax = j.dbl("areaJumpMax", c.areaJumpMax)
        c.sharpnessMin = j.dbl("sharpnessMin", c.sharpnessMin)
        c.glareFracMax = j.dbl("glareFracMax", c.glareFracMax)

        do { let o = j.obj("hands")
            c.hands.flatDeg = o.dbl("flatDeg", c.hands.flatDeg)
            c.hands.flatMs = o.int("flatMs", c.hands.flatMs)
            c.hands.tableCard = o.bool("tableCard", c.hands.tableCard)
            c.hands.turnDeg = o.dbl("turnDeg", c.hands.turnDeg)
            c.hands.maxPauses = o.int("maxPauses", c.hands.maxPauses)
        }
        do { let o = j.obj("sendPhoto")
            c.sendPhoto.maxSide = o.int("maxSide", c.sendPhoto.maxSide)
            c.sendPhoto.quality = o.dbl("quality", c.sendPhoto.quality)
        }
        do { let o = j.obj("back")
            c.back.sweeps = o.int("sweeps", c.back.sweeps)
            c.back.policy = o.str("policy", c.back.policy)
            c.back.glareWaitMs = o.int("glareWaitMs", c.back.glareWaitMs)
        }
        do { let o = j.obj("upDown")
            c.upDown.tiltMin = o.dbl("tiltMin", c.upDown.tiltMin)
            c.upDown.holdFrames = o.int("holdFrames", c.upDown.holdFrames)
            c.upDown.pageDirection = o.str("pageDirection", c.upDown.pageDirection)
        }
        do { let o = j.obj("laminate")
            c.laminate.minLitFrames = o.int("minLitFrames", c.laminate.minLitFrames)
            c.laminate.minHues = o.int("minHues", c.laminate.minHues)
            c.laminate.minPeak = o.dbl("minPeak", c.laminate.minPeak)
            c.laminate.minFrames = o.int("minFrames", c.laminate.minFrames)
            c.laminate.strongHues = o.int("strongHues", c.laminate.strongHues)
            c.laminate.strongPeak = o.dbl("strongPeak", c.laminate.strongPeak)
            c.laminate.passportStrong = o.bool("passportStrong", c.laminate.passportStrong)
            c.laminate.passportHues = o.int("passportHues", c.laminate.passportHues)
            c.laminate.policy = o.str("policy", c.laminate.policy)
        }
        c.otherPassportLaminatePolicy = j.obj("otherPassport").str("laminatePolicy", c.otherPassportLaminatePolicy)
        do { let o = j.obj("civilExtract")
            c.civilExtract.holdMs = o.int("holdMs", c.civilExtract.holdMs)
            c.civilExtract.lightMs = o.int("lightMs", c.civilExtract.lightMs)
            c.civilExtract.minFill = o.dbl("minFill", c.civilExtract.minFill)
            c.civilExtract.steadyMs = o.int("steadyMs", c.civilExtract.steadyMs)
            c.civilExtract.steadyMove = o.dbl("steadyMove", c.civilExtract.steadyMove)
            c.civilExtract.buttonAfterMs = o.int("buttonAfterMs", c.civilExtract.buttonAfterMs)
            c.civilExtract.codeMs = o.int("codeMs", c.civilExtract.codeMs)
            c.civilExtract.codeEveryMs = o.int("codeEveryMs", c.civilExtract.codeEveryMs)
            c.civilExtract.maxRestarts = o.int("maxRestarts", c.civilExtract.maxRestarts)
        }
        do { let o = j.obj("overlay")
            c.overlay.policy = o.str("policy", c.overlay.policy)
            c.overlay.bar = o.dbl("bar", c.overlay.bar)
            c.overlay.barSeveral = o.dbl("barSeveral", c.overlay.barSeveral)
            c.overlay.waitMs = o.int("waitMs", c.overlay.waitMs)
        }
        do { let o = j.obj("backShown")
            c.backShown.policy = o.str("policy", c.backShown.policy)
            c.backShown.bar = o.dbl("bar", c.backShown.bar)
            c.backShown.everyMs = o.int("everyMs", c.backShown.everyMs)
            c.backShown.withinMs = o.int("withinMs", c.backShown.withinMs)
            c.backShown.hintAfterMs = o.int("hintAfterMs", c.backShown.hintAfterMs)
        }
        do { let o = j.obj("idBarcode")
            c.idBarcode.everyMs = o.int("everyMs", c.idBarcode.everyMs)
            c.idBarcode.waitMs = o.int("waitMs", c.idBarcode.waitMs)
        }
        readLaminateDoc(j.obj("drivingLicence"), c.drivingLicence)
        readLaminateDoc(j.obj("residencePermit"), c.residencePermit)
        c.spreadCutMax = j.obj("spread").dbl("cutMax", c.spreadCutMax)
        do { let o = j.obj("optical")
            c.optical.minFrames = o.int("minFrames", c.optical.minFrames)
            c.optical.supportRatio = o.dbl("supportRatio", c.optical.supportRatio)
            c.optical.staticRatio = o.dbl("staticRatio", c.optical.staticRatio)
            c.optical.controlMax = o.dbl("controlMax", c.optical.controlMax)
            c.optical.policy = o.str("policy", c.optical.policy)
        }
        do { let o = j.obj("reflection")
            c.reflection.flareMin = o.dbl("flareMin", c.reflection.flareMin)
            c.reflection.whiteoutMax = o.dbl("whiteoutMax", c.reflection.whiteoutMax)
            c.reflection.chromaMin = o.dbl("chromaMin", c.reflection.chromaMin)
            c.reflection.minLitFrames = o.int("minLitFrames", c.reflection.minLitFrames)
            c.reflection.liftMin = o.dbl("liftMin", c.reflection.liftMin)
            c.reflection.brightLift = o.dbl("brightLift", c.reflection.brightLift)
            c.reflection.sunMax = o.dbl("sunMax", c.reflection.sunMax)
            c.reflection.policy = o.str("policy", c.reflection.policy)
        }
        do { let o = j.obj("light")
            c.light.frames = o.int("frames", c.light.frames)
            c.light.settleMs = o.int("settleMs", c.light.settleMs)
            c.light.maxMs = o.int("maxMs", c.light.maxMs)
            c.light.offSettleMs = o.int("offSettleMs", c.light.offSettleMs)
            c.light.offMaxMs = o.int("offMaxMs", c.light.offMaxMs)
            c.light.barcodeMs = o.int("barcodeMs", c.light.barcodeMs)
        }
        do { let o = j.obj("emblem")
            c.emblem.litMin = o.dbl("litMin", c.emblem.litMin)
            c.emblem.jumpMin = o.dbl("jumpMin", c.emblem.jumpMin)
            c.emblem.strongLit = o.dbl("strongLit", c.emblem.strongLit)
            c.emblem.testTilt = o.dbl("testTilt", c.emblem.testTilt)
            c.emblem.tiltTarget = o.dbl("tiltTarget", c.emblem.tiltTarget)
            c.emblem.holdMs = o.int("holdMs", c.emblem.holdMs)
            c.emblem.minFrames = o.int("minFrames", c.emblem.minFrames)
            c.emblem.extraMs = o.int("extraMs", c.emblem.extraMs)
            c.emblem.darkMax = o.dbl("darkMax", c.emblem.darkMax)
            c.emblem.minTiltFrames = o.int("minTiltFrames", c.emblem.minTiltFrames)
            c.emblem.tiltSide = o.dbl("tiltSide", c.emblem.tiltSide)
            c.emblem.direction = o.str("direction", c.emblem.direction)
            c.emblem.policy = o.str("policy", c.emblem.policy)
        }
        do { let o = j.obj("face")
            c.face.strongChroma = o.dbl("strongChroma", c.face.strongChroma)
            c.face.strongColourMax = o.dbl("strongColourMax", c.face.strongColourMax)
            c.face.inset = o.dbl("inset", c.face.inset)
            c.face.policy = o.str("policy", c.face.policy)
        }
        do { let o = j.obj("evidence")
            c.evidence.maxFrames = o.int("maxFrames", c.evidence.maxFrames)
            c.evidence.maxBytes = o.int("maxBytes", c.evidence.maxBytes)
        }

        c.profile = try parseProfile(root.obj("profiles"), kind: kind)
        return c
    }

    private static func parseProfile(_ profiles: [String: Any], kind: String) throws -> Profile {
        guard let p = profiles[kind] as? [String: Any] else {
            throw ConfigError.unknownKind(kind, available: Array(profiles.keys))
        }
        let feature = p["feature"] as? [String: Any]
        let def = Roi(x: 0.35, y: 0.3, w: 0.3, h: 0.3)
        let pr = Profile()
        pr.raw = p
        pr.id = p.str("id", kind)
        pr.kind = p.str("kind", kind)
        pr.aspect = p.dbl("aspect", 0.0)
        pr.featureKind = feature?.str("kind", "none") ?? "none"
        pr.featureRoi = (feature?["roi"] as? [String: Any]).map { roi($0, def) } ?? def
        pr.controls = (p["controls"] as? [[String: Any]] ?? []).map { roi($0, Roi(x: 0, y: 0, w: 0, h: 0)) }
        pr.iridescent = p.bool("iridescent", false)
        pr.page = p.bool("page", false)
        pr.spread = p.bool("spread", false)
        pr.sheet = p.bool("sheet", false)
        pr.minFill = p.dbl("minFill", 0.0)
        return pr
    }

    private static func roi(_ o: [String: Any], _ d: Roi) -> Roi {
        Roi(x: o.dbl("x", d.x), y: o.dbl("y", d.y), w: o.dbl("w", d.w), h: o.dbl("h", d.h))
    }
}

// JSON helpers: a missing or wrongly typed value falls back to the default (like org.json's opt*()).
extension Dictionary where Key == String, Value == Any {
    func obj(_ k: String) -> [String: Any] { self[k] as? [String: Any] ?? [:] }
    func dbl(_ k: String, _ d: Double) -> Double { (self[k] as? NSNumber)?.doubleValue ?? d }
    func int(_ k: String, _ d: Int) -> Int { (self[k] as? NSNumber)?.intValue ?? d }
    func bool(_ k: String, _ d: Bool) -> Bool { self[k] as? Bool ?? d }
    func str(_ k: String, _ d: String) -> String { self[k] as? String ?? d }
}
