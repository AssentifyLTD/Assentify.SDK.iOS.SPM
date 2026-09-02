import Foundation
import CryptoKit

// MARK: - Character-indexed String helpers (mirrors Java's substring/charAt semantics)

private extension String {
    /// Java-style substring(from, to) — exclusive end, Character-indexed.
    /// Out-of-range requests return "" instead of crashing (candidates that don't
    /// fit a slot are simply treated as non-matching rather than throwing, which
    /// is what the Java code's surrounding try/catch(Exception) accomplished).
    func mrzSub(_ from: Int, _ to: Int? = nil) -> String {
        let chars = Array(self)
        let end = to ?? chars.count
        guard from >= 0, end <= chars.count, from <= end else { return "" }
        return String(chars[from..<end])
    }

    func mrzChar(_ i: Int) -> Character {
        let chars = Array(self)
        guard i >= 0, i < chars.count else { return "\0" }
        return chars[i]
    }

    /// Java's `split(sep, 2)` — split on only the FIRST occurrence of `sep`.
    func mrzSplitOnce(_ sep: String) -> [String] {
        if let r = range(of: sep) {
            return [String(self[startIndex..<r.lowerBound]), String(self[r.upperBound...])]
        }
        return [self]
    }
}

// MARK: - Result

/// Holds one parsed MRZ candidate plus its check-digit validation state.
/// A reference type (like the Java inner class) since `validateTd3`/`validateTd1`
/// patch fields in place while attempting OCR repair.
public final class MrzResult {
    public var lines: [String] = []
    public var docType: String = ""
    public var docNum = false
    public var dob = false
    public var expiry = false
    public var optional = false
    public var finalCd = false
    public var line2Only = false
    public var repaired = false

    public func allValid() -> Bool { docNum && dob && expiry && optional && finalCd }
    public func bacReady() -> Bool { docNum && dob && expiry }

    public func score() -> Int {
        (docNum ? 1 : 0) + (dob ? 1 : 0) + (expiry ? 1 : 0)
            + (optional ? 1 : 0) + (finalCd ? 1 : 0) + (line2Only ? 0 : 1)
    }

    /// True only when every output field is actually present: all check digits
    /// valid, AND (for the TD3 fallback path) line 1 was read so first/last name
    /// exist. Use this — not `allValid()` — to decide whether a scan result can
    /// be accepted, since `allValid()` alone can still pass with the name missing
    /// (the TD3 `line2Only` fallback, which only ever carries line 2's data).
    public func isComplete() -> Bool {
        guard allValid(), !line2Only else { return false }
        let props = toOutputProperties()
        let keys = [
            MrzKeys.KEY_DOCUMENT_TYPE, MrzKeys.KEY_COUNTRY, MrzKeys.KEY_DOCUMENT_NUMBER,
            MrzKeys.KEY_NATIONALITY, MrzKeys.KEY_BIRTH_DATE, MrzKeys.KEY_SEX,
            MrzKeys.KEY_EXPIRY_DATE, MrzKeys.KEY_LAST_NAME, MrzKeys.KEY_FIRST_NAME,
        ]
        for key in keys {
            guard let v = props[key] as? String,
                  !v.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        }
        return true
    }

    public func mrzInformation() -> String {
        if docType == "td3" {
            let l2 = lines[1]
            return l2.mrzSub(0, 10) + l2.mrzSub(13, 20) + l2.mrzSub(21, 28)
        }
        let l1 = lines[0], l2 = lines[1]
        return l1.mrzSub(5, 15) + l2.mrzSub(0, 7) + l2.mrzSub(8, 15)
    }

    public func failSummary() -> String {
        var f: [String] = []
        if !docNum { f.append("doc#") }
        if !dob { f.append("dob") }
        if !expiry { f.append("expiry") }
        if !optional { f.append("opt") }
        if !finalCd { f.append("final") }
        var s = f.isEmpty ? "all checks OK" : "fail: " + f.joined(separator: ",")
        if line2Only { s += " [line 1 not read]" }
        if repaired { s += " [auto-repaired]" }
        return s
    }

    /// Display-oriented rows: [label, value].
    public func fields() -> [[String]] {
        if docType != "td3" {
            let l1 = lines[0], l2 = lines[1], l3 = lines[2]
            return [
                ["Document", l1.mrzSub(0, 2).replacingOccurrences(of: "<", with: "")],
                ["Issuing state", l1.mrzSub(2, 5).replacingOccurrences(of: "<", with: "")],
                ["Document no.", l1.mrzSub(5, 14).replacingOccurrences(of: "<", with: "")],
                ["Birth date", MrzResult.fmtDate(l2.mrzSub(0, 6))],
                ["Sex", l2.mrzSub(7, 8)],
                ["Expiry date", MrzResult.fmtDate(l2.mrzSub(8, 14))],
                ["Nationality", l2.mrzSub(15, 18).replacingOccurrences(of: "<", with: "")],
                ["Name", MrzResult.name(l3, 0)],
            ]
        }
        let l1 = lines[0], l2 = lines[1]
        return [
            ["Document", l1.mrzSub(0, 2).replacingOccurrences(of: "<", with: "")],
            ["Issuing state", l1.mrzSub(2, 5).replacingOccurrences(of: "<", with: "")],
            ["Name", line2Only ? "(line 1 not read)" : MrzResult.name(l1, 5)],
            ["Document no.", l2.mrzSub(0, 9).replacingOccurrences(of: "<", with: "")],
            ["Nationality", l2.mrzSub(10, 13).replacingOccurrences(of: "<", with: "")],
            ["Birth date", MrzResult.fmtDate(l2.mrzSub(13, 19))],
            ["Sex", l2.mrzSub(20, 21)],
            ["Expiry date", MrzResult.fmtDate(l2.mrzSub(21, 27))],
            ["Personal no.", l2.mrzSub(28, 42)
                .replacingOccurrences(of: "<", with: " ")
                .trimmingCharacters(in: .whitespaces)],
        ]
    }

    /// Same underlying data as `fields()`, but keyed by `MrzKeys` instead of display
    /// labels, with surname/given name split into two separate values. On a TD1 back
    /// page that wasn't read (`line2Only`), first/last name are simply omitted.
    public func toOutputProperties() -> [String: Any] {
        var out: [String: Any] = [:]
        if docType == "td3" {
            let l1 = lines[0], l2 = lines[1]
            out[MrzKeys.KEY_DOCUMENT_TYPE] = l1.mrzSub(0, 2).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_COUNTRY] = l1.mrzSub(2, 5).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_DOCUMENT_NUMBER] = l2.mrzSub(0, 9).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_NATIONALITY] = l2.mrzSub(10, 13).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_BIRTH_DATE] = MrzResult.isoDate(l2.mrzSub(13, 19), isExpiry: false)
            out[MrzKeys.KEY_SEX] = l2.mrzSub(20, 21)
            out[MrzKeys.KEY_EXPIRY_DATE] = MrzResult.isoDate(l2.mrzSub(21, 27), isExpiry: true)
            if !line2Only {
                let (last, first) = MrzResult.splitNameParts(l1, 5)
                out[MrzKeys.KEY_LAST_NAME] = last
                out[MrzKeys.KEY_FIRST_NAME] = first
            }
        } else {
            let l1 = lines[0], l2 = lines[1]
            out[MrzKeys.KEY_DOCUMENT_TYPE] = l1.mrzSub(0, 2).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_COUNTRY] = l1.mrzSub(2, 5).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_DOCUMENT_NUMBER] = l1.mrzSub(5, 14).replacingOccurrences(of: "<", with: "")
            out[MrzKeys.KEY_BIRTH_DATE] = MrzResult.isoDate(l2.mrzSub(0, 6), isExpiry: false)
            out[MrzKeys.KEY_SEX] = l2.mrzSub(7, 8)
            out[MrzKeys.KEY_EXPIRY_DATE] = MrzResult.isoDate(l2.mrzSub(8, 14), isExpiry: true)
            out[MrzKeys.KEY_NATIONALITY] = l2.mrzSub(15, 18).replacingOccurrences(of: "<", with: "")
            if !line2Only {
                let l3 = lines[2]
                let (last, first) = MrzResult.splitNameParts(l3, 0)
                out[MrzKeys.KEY_LAST_NAME] = last
                out[MrzKeys.KEY_FIRST_NAME] = first
            }
        }
        return out
    }

    static func name(_ line: String, _ from: Int) -> String {
        let parts = line.mrzSub(from).mrzSplitOnce("<<")
        let surname = parts[0].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
        let given = parts.count > 1 ? parts[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) : ""
        return collapseSpaces("\(surname), \(given)")
    }

    /// Surname/given name split apart (`fields()` combines them into one display string).
    static func splitNameParts(_ line: String, _ from: Int) -> (String, String) {
        let parts = line.mrzSub(from).mrzSplitOnce("<<")
        let surname = collapseSpaces(parts[0].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces))
        let given = parts.count > 1 ? collapseSpaces(parts[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)) : ""
        return (surname, given)
    }

    private static func collapseSpaces(_ s: String) -> String {
        s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// NOTE: the Android source's `fmtDate` does `yymmdd.substring(6, 10)` on a
    /// 6-char string, which is out of bounds and throws in Java every time this
    /// runs. That's fixed here: dd-mm-yy from the raw MRZ digits, no century
    /// (this is display-only; `isoDate` below is the one used for real output).
    static func fmtDate(_ yymmdd: String) -> String {
        guard yymmdd.count == 6 else { return yymmdd }
        let dd = yymmdd.mrzSub(4, 6)
        let mm = yymmdd.mrzSub(2, 4)
        let yy = yymmdd.mrzSub(0, 2)
        return "\(dd)-\(mm)-\(yy) (DD/MM/YY)"
    }

    /// YYMMDD -> DD/MM/YYYY. MRZ years are two digits, so the century is a guess:
    /// expiry dates are treated as 20xx; birth dates use (current year + 10) as the
    /// pivot — a yy above that is assumed 19xx, otherwise 20xx. Adjust the pivot if
    /// your users skew noticeably older or younger than that.
    static func isoDate(_ yymmdd: String, isExpiry: Bool) -> String {
        guard yymmdd.count == 6,
              let yy = Int(yymmdd.mrzSub(0, 2)),
              let mm = Int(yymmdd.mrzSub(2, 4)),
              let dd = Int(yymmdd.mrzSub(4, 6)) else { return yymmdd }
        let century: Int
        if isExpiry {
            century = 2000
        } else {
            let currentYY = Calendar.current.component(.year, from: Date()) % 100
            let pivot = (currentYY + 10) % 100
            century = yy > pivot ? 1900 : 2000
        }
        return String(format: "%02d/%02d/%04d", dd, mm, century + yy)
    }
}

// MARK: - Mrz

/// ICAO 9303 MRZ parsing, check-digit validation, OCR repair, and BAC key derivation.
public enum Mrz {

    static let CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<"

    public static func clean(_ line: String) -> String {
        var s = line.uppercased()
        s = s.replacingOccurrences(of: "«", with: "<<")
            .replacingOccurrences(of: "‹", with: "<")
            .replacingOccurrences(of: "›", with: "<")
            .replacingOccurrences(of: "≪", with: "<<")
            .replacingOccurrences(of: "≤", with: "<")
        s = s.components(separatedBy: .whitespacesAndNewlines).joined()
        var b = ""
        for c in s where CHARSET.contains(c) { b.append(c) }
        return b
    }

    static func charVal(_ c: Character) -> Int {
        if c == "<" { return 0 }
        if let a = c.asciiValue {
            if a >= 48, a <= 57 { return Int(a - 48) }          // '0'...'9'
            if a >= 65, a <= 90 { return Int(a - 65) + 10 }     // 'A'...'Z'
        }
        return 0
    }

    static func checkDigit(_ data: String, _ cd: Character) -> Bool {
        let weights = [7, 3, 1]
        var sum = 0
        for (i, c) in data.enumerated() { sum += charVal(c) * weights[i % 3] }
        if cd == "<" { return sum % 10 == 0 }
        guard let a = cd.asciiValue, a >= 48, a <= 57 else { return false }
        return sum % 10 == Int(a - 48)
    }

    // ---------- coercion of strictly-typed positions ----------

    static let TO_D_FROM = Array("OQDIZSBG")
    static let TO_D_TO = Array("00012586")
    static let TO_A_FROM = Array("012586")
    static let TO_A_TO = Array("OIZSBG")

    static func coerceRange(_ ln: String, _ from: Int, _ to: Int, toDigit: Bool) -> String {
        var c = Array(ln)
        let upper = min(to, c.count)
        guard from < upper else { return ln }
        let f = toDigit ? TO_D_FROM : TO_A_FROM
        let t = toDigit ? TO_D_TO : TO_A_TO
        for p in from..<upper {
            if c[p] == "<" { continue }
            if let i = f.firstIndex(of: c[p]) { c[p] = t[i] }
        }
        return String(c)
    }

    static func coerce(_ lines: [String], _ docType: String) -> [String] {
        var out: [String] = []
        if docType == "td3" {
            out.append(coerceRange(lines[0], 2, 44, toDigit: false))
            var l2 = lines[1]
            l2 = coerceRange(l2, 9, 10, toDigit: true)
            l2 = coerceRange(l2, 10, 13, toDigit: false)
            l2 = coerceRange(l2, 13, 20, toDigit: true)
            l2 = coerceRange(l2, 21, 28, toDigit: true)
            l2 = coerceRange(l2, 42, 44, toDigit: true)
            out.append(l2)
        } else {
            let l1 = coerceRange(coerceRange(lines[0], 2, 5, toDigit: false), 14, 15, toDigit: true)
            var l2 = lines[1]
            l2 = coerceRange(l2, 0, 7, toDigit: true)
            l2 = coerceRange(l2, 8, 15, toDigit: true)
            l2 = coerceRange(l2, 15, 18, toDigit: false)
            l2 = coerceRange(l2, 29, 30, toDigit: true)
            out.append(l1)
            out.append(l2)
            out.append(coerceRange(lines[2], 0, 30, toDigit: false))
        }
        return out
    }

    // ---------- check-digit-guided repair of alphanumeric fields (doc number) ----------

    /// OCR lookalike swaps, both directions.
    static func alt(_ c: Character) -> Character {
        switch c {
        case "O", "Q", "D": return "0"
        case "0": return "O"
        case "I": return "1"
        case "1": return "I"
        case "Z": return "2"
        case "2": return "Z"
        case "S": return "5"
        case "5": return "S"
        case "B": return "8"
        case "8": return "B"
        case "G": return "6"
        case "6": return "G"
        default: return c
        }
    }

    /// If `checkDigit(field, cd)` fails, search lookalike-swap combinations for a
    /// variant that passes. Returns the repaired field, or nil when none found.
    static func repairField(_ field: String, _ cd: Character) -> String? {
        let chars = Array(field)
        var amb: [Int] = []
        for i in 0..<chars.count where alt(chars[i]) != chars[i] { amb.append(i) }
        let n = min(amb.count, 10)
        var masks: [Int] = []
        if n > 0 { for m in 1..<(1 << n) { masks.append(m) } }
        masks.sort { $0.nonzeroBitCount < $1.nonzeroBitCount } // fewest swaps first
        for mask in masks {
            var c = chars
            for b in 0..<n where mask & (1 << b) != 0 {
                let p = amb[b]
                c[p] = alt(c[p])
            }
            let cand = String(c)
            if checkDigit(cand, cd) { return cand }
        }
        return nil
    }

    // ---------- validation (with repair) ----------

    static func validateTd3(_ lines: [String]) -> MrzResult {
        var l2 = lines[1]
        let r = MrzResult()
        r.lines = lines
        r.docType = "td3"
        r.docNum = checkDigit(l2.mrzSub(0, 9), l2.mrzChar(9))
        if !r.docNum, let fixed = repairField(l2.mrzSub(0, 9), l2.mrzChar(9)) {
            l2 = fixed + l2.mrzSub(9)
            r.lines[1] = l2
            r.docNum = true
            r.repaired = true
        }
        r.dob = checkDigit(l2.mrzSub(13, 19), l2.mrzChar(19))
        r.expiry = checkDigit(l2.mrzSub(21, 27), l2.mrzChar(27))
        r.optional = checkDigit(l2.mrzSub(28, 42), l2.mrzChar(42))
        let comp = l2.mrzSub(0, 10) + l2.mrzSub(13, 20) + l2.mrzSub(21, 43)
        r.finalCd = checkDigit(comp, l2.mrzChar(43))
        return r
    }

    static func validateTd1(_ lines: [String]) -> MrzResult {
        var l1 = lines[0]
        let l2 = lines[1]
        let r = MrzResult()
        r.lines = lines
        r.docType = "td1"
        r.docNum = checkDigit(l1.mrzSub(5, 14), l1.mrzChar(14))
        if !r.docNum, let fixed = repairField(l1.mrzSub(5, 14), l1.mrzChar(14)) {
            l1 = l1.mrzSub(0, 5) + fixed + l1.mrzSub(14)
            r.lines[0] = l1
            r.docNum = true
            r.repaired = true
        }
        r.dob = checkDigit(l2.mrzSub(0, 6), l2.mrzChar(6))
        r.expiry = checkDigit(l2.mrzSub(8, 14), l2.mrzChar(14))
        r.optional = true
        let comp = l1.mrzSub(5, 30) + l2.mrzSub(0, 7) + l2.mrzSub(8, 15) + l2.mrzSub(18, 29)
        r.finalCd = checkDigit(comp, l2.mrzChar(29))
        return r
    }

    // ---------- line-length normalization ----------

    /// Longest run of '<' in s: (start, length), or nil.
    static func longestFillerRun(_ s: String) -> (start: Int, length: Int)? {
        let chars = Array(s)
        var bestStart = -1, bestLen = 0, i = 0
        while i < chars.count {
            if chars[i] == "<" {
                var j = i
                while j < chars.count && chars[j] == "<" { j += 1 }
                if j - i > bestLen { bestLen = j - i; bestStart = i }
                i = j
            } else {
                i += 1
            }
        }
        return bestLen > 0 ? (bestStart, bestLen) : nil
    }

    /// Variants of `ln` normalized to exactly `len` chars: trim/pad at the ends, and
    /// shrink/grow the longest '<' run (fixes OCR inserting/dropping fillers mid-line).
    static func lengthVariants(_ ln: String, _ len: Int) -> [String] {
        var out: [String] = []
        if ln.count == len {
            out.append(ln)
            return out
        }
        let run = longestFillerRun(ln)
        if ln.count > len {
            let excess = ln.count - len
            if let run = run, run.length > excess {
                out.append(ln.mrzSub(0, run.start) + ln.mrzSub(run.start + excess))
            }
            out.append(ln.mrzSub(0, len))
            out.append(ln.mrzSub(ln.count - len))
        } else {
            let missing = len - ln.count
            if let run = run {
                let fill = String(repeating: "<", count: missing)
                out.append(ln.mrzSub(0, run.start) + fill + ln.mrzSub(run.start))
            }
            var b = ln
            while b.count < len { b += "<" }
            out.append(b)
        }
        var ded: [String] = []
        for s in out where !ded.contains(s) { ded.append(s) }
        return ded
    }

    // ---------- candidate search ----------

    static func better(_ a: MrzResult?, _ b: MrzResult?) -> MrzResult? {
        guard let a = a else { return b }
        guard let b = b else { return a }
        return b.score() > a.score() ? b : a
    }

    /// Best MRZ interpretation of recognized text, or nil when no MRZ-like lines.
    public static func bestCandidate(rawText: String) -> MrzResult? {
        var raw: [String] = []
        for ln in rawText.components(separatedBy: "\n") {
            let c = clean(ln)
            if c.count >= 20 { raw.append(c) }
        }
        if raw.isEmpty { return nil }

        var best: MrzResult? = nil
        let anyLong = raw.contains { $0.count >= 38 }
        let types = anyLong ? ["td3", "td1"] : ["td1", "td3"]

        for dt in types {
            let n = dt == "td3" ? 2 : 3
            let len = dt == "td3" ? 44 : 30
            guard raw.count >= n else { continue }

            var i = raw.count - n
            while i >= 0 {
                var perLine: [[String]] = []
                for j in 0..<n { perLine.append(lengthVariants(raw[i + j], len)) }

                var idx = [Int](repeating: 0, count: n)
                var more = true
                while more {
                    var cand: [String] = []
                    for j in 0..<n { cand.append(perLine[j][idx[j]]) }
                    for c in [cand, coerce(cand, dt)] {
                        let r = dt == "td3" ? validateTd3(c) : validateTd1(c)
                        best = better(best, r)
                        if best!.isComplete() { return best }
                    }
                    // advance cartesian index
                    var k = n - 1
                    idx[k] += 1
                    while k >= 0 && idx[k] >= perLine[k].count {
                        idx[k] = 0
                        k -= 1
                        if k >= 0 { idx[k] += 1 }
                    }
                    more = k >= 0
                }
                i -= 1
            }
        }

        // fallback: TD3 line 2 alone carries every check digit and the whole BAC input
        if best == nil || !best!.bacReady() {
            var ph = "P<"
            while ph.count < 44 { ph += "<" }
            let placeholder = ph
            var i = raw.count - 1
            while i >= 0 {
                if raw[i].count >= 40 {
                    for v in lengthVariants(raw[i], 44) {
                        let cand = [placeholder, v]
                        for c in [cand, coerce(cand, "td3")] {
                            let r = validateTd3(c)
                            r.line2Only = true
                            best = better(best, r)
                        }
                    }
                }
                i -= 1
            }
        }
        return best
    }

    // ---------- BAC key derivation (ICAO 9303 part 11) ----------

    public static func hex(_ bytes: [UInt8], _ len: Int) -> String {
        bytes.prefix(len).map { String(format: "%02X", $0) }.joined()
    }

    static func adjustDesParity(_ key: [UInt8]) -> [UInt8] {
        key.map { byte in
            let b = byte & 0xFE
            let bit: UInt8 = (b.nonzeroBitCount % 2 == 0) ? 1 : 0
            return b | bit
        }
    }

    static func kdf(kseed: [UInt8], c: UInt8) -> [UInt8] {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data(kseed))
        hasher.update(data: Data([0, 0, 0, c]))
        let digest = Array(hasher.finalize())
        return adjustDesParity(Array(digest.prefix(16)))
    }

    /// Returns (mrz_information, Kseed, Kenc, Kmac) as hex strings.
    public static func bacKeys(_ r: MrzResult) -> (mrzInfo: String, kseed: String, kenc: String, kmac: String) {
        let mrzInfo = r.mrzInformation()
        let digest = Array(Insecure.SHA1.hash(data: Data(mrzInfo.utf8)))
        let kseed = Array(digest.prefix(16))
        let kenc = kdf(kseed: kseed, c: 1)
        let kmac = kdf(kseed: kseed, c: 2)
        return (mrzInfo, hex(kseed, 16), hex(kenc, 16), hex(kmac, 16))
    }
}
