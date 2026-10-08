import Foundation

import UIKit
import AVFoundation
import Accelerate
import CoreImage
import Vision
import CoreVideo
import NFCPassportReader
import CoreNFC


public class ScanNfc: LanguageTransformationDelegate {

    // MARK: - Debug

    /// Set to false to silence the logs (they are also compiled out of release builds)
    private static let debugEnabled = true

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard Self.debugEnabled else { return }
        print("[ScanNfc] \(message())")
        #endif
    }

    private func debugDump<T>(_ title: String, _ value: T?) {
        #if DEBUG
        guard Self.debugEnabled else { return }
        guard let value = value else {
            print("[ScanNfc] \(title): nil (missing / not readable / empty)")
            return
        }
        var text = ""
        dump(value, to: &text)
        print("[ScanNfc] \(title):\n\(text)")
        #endif
    }


    // MARK: - Constants

    private enum Nfc {
        static let nameSeparator = "#"

        // ICAO tags as listed in EF.COM (also the outer tag of each file)
        static let dg11Tag = 0x6B
        static let dg12Tag = 0x6C
        static let dg13Tag = 0x6D

        // TLV structure tags
        static let tagList = 0x5C       // list of tags present, ignored when extracting
        static let templateTag = 0xA0   // wraps repeated names (DG11 other names, DG12 other persons)
        static let countTag = 0x02      // count inside the A0 template

        // DG11 field tags (ICAO)
        static let dg11NameOfHolder = 0x5F0E
        static let dg11OtherName = 0x5F0F
        static let dg11PersonalNumber = 0x5F10
        static let dg11PlaceOfBirth = 0x5F11
        static let dg11Telephone = 0x5F12
        static let dg11Profession = 0x5F13
        static let dg11Title = 0x5F14
        static let dg11PersonalSummary = 0x5F15
        static let dg11OtherTdNumbers = 0x5F17
        static let dg11Custody = 0x5F18
        static let dg11FullDateOfBirth = 0x5F2B
        static let dg11PermanentAddress = 0x5F42

        // DG12 field tags (ICAO)
        static let dg12IssuingAuthority = 0x5F19
        static let dg12OtherPerson = 0x5F1A
        static let dg12Endorsements = 0x5F1B
        static let dg12TaxExit = 0x5F1C
        static let dg12DateOfIssue = 0x5F26
        static let dg12PersonalizationTime = 0x5F55
        static let dg12PersonalizationSerial = 0x5F56

        // DG13 is issuer-defined: this table is ONLY valid for Lebanese passports
        static let lebanon = "LBN"
        static let lbGivenNames = 0x9F1A
        static let lbSurname = 0x9F1B
        static let lbGivenNamesAr = 0x9F0E
        static let lbSurnameAr = 0x9F0F
        static let lbFather = 0x9F2D
        static let lbFatherAr = 0x9F1D
        static let lbMother = 0x9F2E
        static let lbMotherAr = 0x9F1E
        static let lbMotherFamily = 0x9F34
        static let lbMotherFamilyAr = 0x9F33
        static let lbMotherFull = 0x9F36
        static let lbMotherFullAr = 0x9F35
        static let lbPlaceOfBirthAr = 0x9F11
        static let lbNationalityAr = 0x9F12
        static let lbSexAr = 0x9F13
        static let lbRecordId = 0x9F32
    }

    // MARK: - Data models (all optional: chips fill only what the issuer chose)

    /// Everything readable from DG11
    private struct NfcDg11Data {
        var nameOfHolder: String? = nil
        var otherNames: String? = nil          // only set when the parent split is not possible
        var fatherName: String? = nil
        var fatherNameArabic: String? = nil
        var motherName: String? = nil
        var motherNameArabic: String? = nil
        var personalNumber: String? = nil
        var fullDateOfBirth: String? = nil
        var placeOfBirth: String? = nil
        var placeOfBirthArabic: String? = nil
        var permanentAddress: String? = nil
        var telephone: String? = nil
        var profession: String? = nil
        var title: String? = nil
        var personalSummary: String? = nil
        var otherValidTDNumbers: String? = nil
        var custodyInformation: String? = nil
    }

    /// Everything text-based readable from DG12
    private struct NfcDg12Data {
        var issuingAuthority: String? = nil
        var dateOfIssue: String? = nil
        var namesOfOtherPersons: String? = nil
        var endorsementsAndObservations: String? = nil
        var taxOrExitRequirements: String? = nil
        var dateAndTimeOfPersonalization: String? = nil
        var personalizationSystemSerialNumber: String? = nil
    }

    /// DG13 (issuer-defined). Named fields are filled only for Lebanese passports.
    /// For any other issuer every non-empty tag goes to `unrecognized` as "TAG=value; ...".
    private struct NfcDg13Data {
        var givenNames: String? = nil
        var surname: String? = nil
        var givenNamesArabic: String? = nil
        var surnameArabic: String? = nil
        var fatherName: String? = nil
        var fatherNameArabic: String? = nil
        var motherName: String? = nil
        var motherNameArabic: String? = nil
        var motherFamilyName: String? = nil
        var motherFamilyNameArabic: String? = nil
        var motherFullName: String? = nil
        var motherFullNameArabic: String? = nil
        var placeOfBirthArabic: String? = nil
        var nationalityArabic: String? = nil
        var sexArabic: String? = nil
        var recordId: String? = nil
        var unrecognized: String? = nil
    }

    private struct ParentNames {
        var fatherName: String? = nil
        var fatherNameArabic: String? = nil
        var motherName: String? = nil
        var motherNameArabic: String? = nil
        var otherNames: String? = nil   // whole value, only when the split is not possible
    }

    private struct LatinArabic {
        var main: String? = nil         // Latin part, or the whole value when not split
        var arabic: String? = nil
    }

    private struct Tlv {
        let tag: Int
        let value: [UInt8]
    }

    /// DG1 values read straight from the chip MRZ (same as JMRTD MRZInfo on Android).
    private struct MrzData {
        var surname: String?          // primaryIdentifier
        var givenNames: String?       // secondaryIdentifier
        var documentNumber: String?
        var nationality: String?
        var sex: String?
    }

    /// A resolved value plus where it came from ("DG13", "DG11", "DG12", "DG1"), for the logs
    private struct Picked {
        let value: String?
        let source: String
    }


    // MARK: - State

    private var scanNfcDelegate: ScanNfcDelegate?
    private var configModel: ConfigModel?
    private var apiKey: String
    private var language: String?
    private var passportResponseModel: PassportResponseModel?

    // nil when the DG is missing, not readable, or failed to parse
    private var nfcDg11: NfcDg11Data?
    private var nfcDg12: NfcDg12Data?
    private var nfcDg13: NfcDg13Data?

    // DG1 (MRZ) names: the source of truth for name / surname, also after translation
    private var dg1GivenNames: String?
    private var dg1Surname: String?


    init(configModel: ConfigModel!,
         apiKey: String,
         language: String,
         scanNfcDelegate: ScanNfcDelegate
    ) {
        self.configModel = configModel
        self.apiKey = apiKey
        self.language = language
        self.scanNfcDelegate = scanNfcDelegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    public func isNfcAvailable() -> Bool {
        return NFCTagReaderSession.readingAvailable
    }


    // MARK: - Read

    public func readPassport(dataModel: PassportResponseModel) async {
        self.passportResponseModel = dataModel
        self.nfcDg11 = nil
        self.nfcDg12 = nil
        self.nfcDg13 = nil
        self.dg1GivenNames = nil
        self.dg1Surname = nil

        let passportUtils = PassportUtils()
        let passportNumber = dataModel.passportExtractedModel?.identificationDocumentCapture?.Document_Number as? String
        let birthDate = self.formatDateToMRZ((dataModel.passportExtractedModel?.identificationDocumentCapture?.Birth_Date as? String)!)
        let expiryDate = self.formatDateToMRZ((dataModel.passportExtractedModel?.identificationDocumentCapture?.Expiry_Date as? String)!)
        let mrzKey = passportUtils.getMRZKey(
            passportNumber: passportNumber!,
            dateOfBirth: birthDate,
            dateOfExpiry: expiryDate)

        let reader = PassportReader()

        do {
            // DG1 / DG2 are mandatory. DG11 / DG12 / DG13 are optional (only read if listed in EF.COM).
            // DG14 enables Chip Authentication, like doChipAuth() on Android.
            let passportModel = try await reader.readPassport(
                mrzKey: mrzKey,
                tags: [.COM, .DG1, .DG2, .DG11, .DG12, .DG13, .DG14],
                customDisplayMessage: { displayMessage in
                    switch displayMessage {
                    case .requestPresentPassport:
                        return "Hold your iPhone near an NFC enabled passport."
                    case .authenticatingWithPassport:
                        self.scanNfcDelegate?.onStartNfcScan()
                        return "Authenticating..."
                    case .successfulRead:
                        return "Reading ..."
                    case .error(let error):
                        self.scanNfcDelegate?.onErrorNfcScan(dataModel: self.passportResponseModel!, message: error.errorDescription!)
                        return "Error: \(error.localizedDescription)"
                    default:
                        return nil
                    }
                }
            )

            if !passportModel.documentNumber.isEmpty {
                // Optional groups: never fail the scan because of them
                readOptionalDataGroups(passportModel)
                self.nfcScanComplete(nFCPassportModel: passportModel)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    /// DG11 / DG12 / DG13 are always decoded from the raw TLV bytes (same result as the Android path).
    private func readOptionalDataGroups(_ model: NFCPassportModel) {
        nfcDg11 = rawBytes(model, .DG11).flatMap { decodeDg11($0) }
        nfcDg12 = rawBytes(model, .DG12).flatMap { decodeDg12($0) }

        // DG13 meaning depends on the issuer, so pass the issuing state from DG1
        let issuingState = cleanNfcText(model.issuingAuthority)
        nfcDg13 = rawBytes(model, .DG13).flatMap { decodeDg13($0, issuingState: issuingState) }

        debugLog("========== DATA GROUPS ==========")
        debugLog("Issuing state (DG1): \(issuingState ?? "nil")")
        debugLog("Read: DG11=\(nfcDg11 != nil)  DG12=\(nfcDg12 != nil)  DG13=\(nfcDg13 != nil)")
        debugDump("DG11", nfcDg11)
        debugDump("DG12", nfcDg12)
        debugDump("DG13", nfcDg13)
    }

    private func rawBytes(_ model: NFCPassportModel, _ id: DataGroupId) -> [UInt8]? {
        guard let dg = model.dataGroupsRead[id] else { return nil }
        let bytes = dg.data
        return bytes.isEmpty ? nil : bytes
    }

    /// Parses the MRZ (tag 5F1F inside DG1, outer tag 61) ourselves.
    /// NFCPassportModel.firstName / lastName are NOT used: once DG11 is read, the library
    /// prefers DG11 "name of holder" (which can be Arabic, e.g. "عمر#محمد") over the MRZ.
    private func readMrz(_ model: NFCPassportModel) -> MrzData? {
        guard let raw = rawBytes(model, .DG1),
              let field = fileFields(raw, outerTag: 0x61).first(where: { $0.tag == 0x5F1F }),
              let text = String(bytes: field.value, encoding: .ascii) else { return nil }

        let mrz = Array(text.filter { $0 != "\n" && $0 != "\r" })
        func part(_ from: Int, _ to: Int) -> String? {
            guard from >= 0, to <= mrz.count, from < to else { return nil }
            return String(mrz[from..<to])
        }

        var nameField, documentNumber, nationality, sex: String?
        switch mrz.count {
        case 88: // TD3 (passport): 2 lines x 44
            nameField = part(5, 44)
            documentNumber = part(44, 53); nationality = part(54, 57); sex = part(64, 65)
        case 72: // TD2: 2 lines x 36
            nameField = part(5, 36)
            documentNumber = part(36, 45); nationality = part(46, 49); sex = part(56, 57)
        case 90: // TD1 (ID card): 3 lines x 30
            nameField = part(60, 90)
            documentNumber = part(5, 14); nationality = part(45, 48); sex = part(37, 38)
        default:
            return nil
        }

        // "MOHAMMAD<<OMAR<<<<<" → surname "MOHAMMAD", given names "OMAR"
        let names = (nameField ?? "").components(separatedBy: "<<")
        var data = MrzData()
        data.surname = cleanNfcText(names.first)
        data.givenNames = cleanNfcText(names.dropFirst().joined(separator: " "))
        data.documentNumber = cleanNfcText(documentNumber)
        data.nationality = cleanNfcText(nationality)
        data.sex = cleanNfcText(sex)
        return data
    }


    private func formatDateToMRZ(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "/")

        let day = parts[0].padding(toLength: 2, withPad: "0", startingAt: 0)
        let month = parts[1].padding(toLength: 2, withPad: "0", startingAt: 0)
        let year = parts[2].suffix(2)

        return "\(year)\(month)\(day)"
    }


    private func nfcScanComplete(nFCPassportModel: NFCPassportModel) {
        if let dg2 = nFCPassportModel.dataGroupsRead[.DG2] as? DataGroup2 {
            let byteArray = dg2.imageData
            let faceImageData = Data(byteArray)

            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "face_\(timestamp)"

            uploadImage(
                faceImageData: faceImageData,
                fileName: fileName,
                nFCPassportModel: nFCPassportModel
            )
        } else {
            // No face on the chip: still complete with the chip text data
            replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
        }
    }


    // MARK: - Upload (unchanged)

    private func uploadImage(
        faceImageData: Data,
        fileName: String,
        nFCPassportModel: NFCPassportModel
    ) {
        guard let config = self.configModel else {
            return
        }

        let fullPath = "\(config.tenantIdentifier)/\(config.blockIdentifier)/\(config.instanceId)/\(fileName)"
        guard let encodedPath = fullPath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
            return
        }

        let baseUrl = "\(BaseUrls.blobUrl)v2/Document/UploadFile/userfiles/\(encodedPath)?skipValidator=true"
        guard let url = URL(string: baseUrl) else {
            self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(config.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.setValue(config.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(config.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue("text/plain", forHTTPHeaderField: "accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"asset\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(faceImageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body


        let task = BlobSession.shared.dataTask(with: request) { data, response, error in

            if error != nil {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard let data = data, !data.isEmpty else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard let dict = json as? [String: Any], let uploadedUrl = dict["url"] as? String else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            self.passportResponseModel?.passportExtractedModel?.faces = [uploadedUrl]
            self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
        }

        task.resume()
    }


    // MARK: - Raw TLV decoding (BER-TLV, as described in ICAO 9303)

    /// Parses a sequence of TLVs. Tags are 1+ bytes, lengths are BER (short, 81 nn, 82 nn nn, 83 nn nn nn).
    /// Stops (without crashing) at the first truncated or invalid entry.
    private func parseTlvs(_ bytes: [UInt8]) -> [Tlv] {
        var out: [Tlv] = []
        var i = 0
        while i < bytes.count {
            var tag = Int(bytes[i]); i += 1
            if tag == 0x00 || tag == 0xFF { continue } // padding

            if (tag & 0x1F) == 0x1F {
                // multi-byte tag: continue while the high bit of the next byte is set
                while true {
                    guard i < bytes.count else { return out }
                    let next = Int(bytes[i]); i += 1
                    tag = (tag << 8) | next
                    if (next & 0x80) == 0 { break }
                }
            }

            guard i < bytes.count else { break }
            var length = Int(bytes[i]); i += 1
            if length >= 0x80 {
                let count = length & 0x7F
                guard count > 0, count <= 3, i + count <= bytes.count else { break }
                length = 0
                for _ in 0..<count {
                    length = (length << 8) | Int(bytes[i])
                    i += 1
                }
            }

            guard length >= 0, i + length <= bytes.count else { break }
            out.append(Tlv(tag: tag, value: Array(bytes[i..<(i + length)])))
            i += length
        }
        return out
    }

    /// Fields inside the file's outer tag. The 5C tag list is skipped.
    /// A0 templates (repeated names) are flattened, without their count.
    /// If the bytes don't start with the outer tag (body only), they are used as-is.
    private func fileFields(_ raw: [UInt8], outerTag: Int) -> [Tlv] {
        let content = parseTlvs(raw).first(where: { $0.tag == outerTag })?.value ?? raw
        var fields: [Tlv] = []
        for field in parseTlvs(content) {
            switch field.tag {
            case Nfc.tagList:
                continue
            case Nfc.templateTag:
                fields += parseTlvs(field.value).filter { $0.tag != Nfc.countTag }
            default:
                fields.append(field)
            }
        }
        return fields
    }

    /// UTF-8 text (never ASCII/Latin-1, which breaks Arabic). Not valid text → hex. Empty → nil.
    private func decodeText(_ bytes: [UInt8]) -> String? {
        guard !bytes.isEmpty else { return nil }
        guard let text = String(data: Data(bytes), encoding: .utf8) else {
            return toHex(bytes)
        }
        return cleanNfcText(text)
    }

    /// Dates are ASCII digits or BCD: ASCII if every byte is '0'..'9', otherwise hex-encode (BCD)
    private func decodeDate(_ bytes: [UInt8]) -> String? {
        guard !bytes.isEmpty else { return nil }
        let isAsciiDigits = bytes.allSatisfy { (0x30...0x39).contains($0) }
        let digits = isAsciiDigits ? (String(bytes: bytes, encoding: .ascii) ?? toHex(bytes)) : toHex(bytes)
        return formatNfcDate(digits)
    }

    private func toHex(_ bytes: [UInt8]) -> String {
        return bytes.map { String(format: "%02X", $0) }.joined()
    }


    // MARK: - DG11 / DG12 / DG13 decoders (none of these ever crash)

    private func decodeDg11(_ raw: [UInt8]) -> NfcDg11Data? {
        let fields = fileFields(raw, outerTag: Nfc.dg11Tag)
        guard !fields.isEmpty else { return nil }

        func text(_ tag: Int) -> String? {
            return fields.first(where: { $0.tag == tag }).flatMap { decodeText($0.value) }
        }
        func texts(_ tag: Int) -> [String] {
            return fields.filter { $0.tag == tag }.compactMap { decodeText($0.value) }
        }

        let parents = splitOtherNames(texts(Nfc.dg11OtherName))
        let placeOfBirth = splitPlaceOfBirth([text(Nfc.dg11PlaceOfBirth)].compactMap { $0 })

        var d = NfcDg11Data()
        d.nameOfHolder = text(Nfc.dg11NameOfHolder)
        d.otherNames = parents.otherNames
        d.fatherName = parents.fatherName
        d.fatherNameArabic = parents.fatherNameArabic
        d.motherName = parents.motherName
        d.motherNameArabic = parents.motherNameArabic
        d.personalNumber = text(Nfc.dg11PersonalNumber)
        d.fullDateOfBirth = fields.first(where: { $0.tag == Nfc.dg11FullDateOfBirth }).flatMap { decodeDate($0.value) }
        d.placeOfBirth = placeOfBirth.main
        d.placeOfBirthArabic = placeOfBirth.arabic
        d.permanentAddress = text(Nfc.dg11PermanentAddress)
        d.telephone = text(Nfc.dg11Telephone)
        d.profession = text(Nfc.dg11Profession)
        d.title = text(Nfc.dg11Title)
        d.personalSummary = text(Nfc.dg11PersonalSummary)
        d.otherValidTDNumbers = text(Nfc.dg11OtherTdNumbers)
        d.custodyInformation = text(Nfc.dg11Custody)
        return d
    }

    private func decodeDg12(_ raw: [UInt8]) -> NfcDg12Data? {
        let fields = fileFields(raw, outerTag: Nfc.dg12Tag)
        guard !fields.isEmpty else { return nil }

        func text(_ tag: Int) -> String? {
            return fields.first(where: { $0.tag == tag }).flatMap { decodeText($0.value) }
        }
        func date(_ tag: Int) -> String? {
            return fields.first(where: { $0.tag == tag }).flatMap { decodeDate($0.value) }
        }

        var d = NfcDg12Data()
        d.issuingAuthority = text(Nfc.dg12IssuingAuthority)
        d.dateOfIssue = date(Nfc.dg12DateOfIssue)
        d.namesOfOtherPersons = cleanNfcList(
            fields.filter { $0.tag == Nfc.dg12OtherPerson }.compactMap { decodeText($0.value) }
        )
        d.endorsementsAndObservations = text(Nfc.dg12Endorsements)
        d.taxOrExitRequirements = text(Nfc.dg12TaxExit)
        d.dateAndTimeOfPersonalization = date(Nfc.dg12PersonalizationTime)
        d.personalizationSystemSerialNumber = text(Nfc.dg12PersonalizationSerial)
        return d
    }

    /// DG13. The tag table is applied ONLY when DG1's issuing state is LBN.
    /// For other issuers (or unknown tags) non-empty values are kept raw in `unrecognized`.
    private func decodeDg13(_ raw: [UInt8], issuingState: String?) -> NfcDg13Data? {
        // Ordered, first value per tag wins
        var values: [(tag: Int, text: String)] = []
        for field in fileFields(raw, outerTag: Nfc.dg13Tag) {
            guard let text = decodeText(field.value) else { continue } // skip empty fields
            if !values.contains(where: { $0.tag == field.tag }) {
                values.append((tag: field.tag, text: text))
            }
        }
        guard !values.isEmpty else { return nil }

        guard issuingState == Nfc.lebanon else {
            var d = NfcDg13Data()
            d.unrecognized = formatUnrecognized(values)
            return d
        }

        func take(_ tag: Int) -> String? {
            guard let index = values.firstIndex(where: { $0.tag == tag }) else { return nil }
            return values.remove(at: index).text
        }

        var d = NfcDg13Data()
        d.givenNames = take(Nfc.lbGivenNames)
        d.surname = take(Nfc.lbSurname)
        d.givenNamesArabic = take(Nfc.lbGivenNamesAr)
        d.surnameArabic = take(Nfc.lbSurnameAr)
        d.fatherName = take(Nfc.lbFather)
        d.fatherNameArabic = take(Nfc.lbFatherAr)
        d.motherName = take(Nfc.lbMother)
        d.motherNameArabic = take(Nfc.lbMotherAr)
        d.motherFamilyName = take(Nfc.lbMotherFamily)
        d.motherFamilyNameArabic = take(Nfc.lbMotherFamilyAr)
        d.motherFullName = take(Nfc.lbMotherFull)
        d.motherFullNameArabic = take(Nfc.lbMotherFullAr)
        d.placeOfBirthArabic = take(Nfc.lbPlaceOfBirthAr)
        d.nationalityArabic = take(Nfc.lbNationalityAr)
        d.sexArabic = take(Nfc.lbSexAr)
        d.recordId = take(Nfc.lbRecordId)
        d.unrecognized = formatUnrecognized(values)   // whatever is left, e.g. "9F14=-"
        return d
    }

    private func formatUnrecognized(_ values: [(tag: Int, text: String)]) -> String? {
        let joined = values
            .map { "\(String($0.tag, radix: 16, uppercase: true))=\($0.text)" }
            .joined(separator: "; ")
        return joined.isEmpty ? nil : joined
    }


    // MARK: - DG11 split helpers

    /// Other names.
    /// Split ONLY when the value is exactly 4 '#'-separated parts forming two Latin/Arabic pairs:
    ///   "ZAHR#زاهر#RANIA#رانيا" → father ZAHR / زاهر, mother RANIA / رانيا
    ///   (Latin/Arabic order inside each pair doesn't matter; an empty part is allowed)
    /// Anything else → nothing is guessed, the whole value goes to otherNames.
    private func splitOtherNames(_ values: [String]) -> ParentNames {
        let entries = values.compactMap { cleanNfcText($0) }
        guard !entries.isEmpty else { return ParentNames() }

        let parts = entries.joined(separator: Nfc.nameSeparator)
            .components(separatedBy: Nfc.nameSeparator)
            .map { cleanNfcText($0) ?? "" }
        if parts.allSatisfy({ $0.isEmpty }) { return ParentNames() }

        if parts.count == 4,
           let father = pickLatinArabic(parts[0], parts[1]),
           let mother = pickLatinArabic(parts[2], parts[3]) {
            return ParentNames(
                fatherName: father.main,
                fatherNameArabic: father.arabic,
                motherName: mother.main,
                motherNameArabic: mother.arabic
            )
        }

        // Unknown format: keep it on one key, exactly as read
        return ParentNames(otherNames: entries.joined(separator: ", "))
    }

    /// Place of birth.
    /// Split ONLY when the value is 2 '#'-separated parts forming a Latin/Arabic pair:
    ///   "BEIRUT#بيروت" → BEIRUT / بيروت
    /// Anything else (no '#', ICAO "PARIS<FRANCE", 3+ parts, ...) → whole value on placeOfBirth.
    private func splitPlaceOfBirth(_ values: [String]) -> LatinArabic {
        guard let whole = cleanNfcText(values.joined(separator: " ")) else { return LatinArabic() }

        let parts = whole.components(separatedBy: Nfc.nameSeparator).map { cleanNfcText($0) ?? "" }
        if parts.allSatisfy({ $0.isEmpty }) { return LatinArabic() }

        if parts.count == 2,
           let pair = pickLatinArabic(parts[0], parts[1]),
           pair.main != nil || pair.arabic != nil {
            return pair
        }

        // Unknown format: keep it on one key
        return LatinArabic(main: whole)
    }

    /// DG11 "name of holder" when it is Arabic with a '#' separator: "عمر#محمد" → given "عمر", surname "محمد".
    /// (Matches the MRZ "MOHAMMAD<<OMAR": surname MOHAMMAD, given OMAR.)
    /// Latin or unseparated values are not guessed → (nil, nil).
    private func splitArabicHolderName(_ holder: String?) -> (given: String?, surname: String?) {
        guard let holder = cleanNfcText(holder),
              isArabic(holder),
              holder.contains(Nfc.nameSeparator) else { return (nil, nil) }
        let parts = holder.components(separatedBy: Nfc.nameSeparator)
        return (cleanNfcText(parts.first), cleanNfcText(parts.dropFirst().joined(separator: " ")))
    }

    /// Two values are a valid pair when there is at most one Latin and at most one Arabic value.
    /// Returns nil when both are Latin or both are Arabic.
    private func pickLatinArabic(_ a: String, _ b: String) -> LatinArabic? {
        let values = [a, b].filter { !$0.isEmpty }
        let arabic = values.filter { isArabic($0) }
        let latin = values.filter { !isArabic($0) }
        if arabic.count > 1 || latin.count > 1 { return nil }
        return LatinArabic(main: latin.first, arabic: arabic.first)
    }

    /// Arabic letters, incl. presentation forms
    private func isArabic(_ value: String) -> Bool {
        return value.unicodeScalars.contains { scalar in
            let v = scalar.value
            return (0x0600...0x06FF).contains(v)
                || (0x0750...0x077F).contains(v)
                || (0xFB50...0xFDFF).contains(v)
                || (0xFE70...0xFEFF).contains(v)
        }
    }


    // MARK: - Text helpers

    /// "<" → space, collapse spaces, trim; empty → nil
    private func cleanNfcText(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "<", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cleanNfcList(_ values: [String]?) -> String? {
        guard let cleaned = values?.compactMap({ cleanNfcText($0) }), !cleaned.isEmpty else { return nil }
        return cleaned.joined(separator: ", ")
    }

    /// "NADA" + "KHOURY" → "NADA KHOURY"; both nil → nil
    private func joinNames(_ first: String?, _ second: String?) -> String? {
        let joined = [first, second].compactMap { cleanNfcText($0) }.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    /// yyyyMMdd → dd/MM/yyyy, yyyyMMddHHmmss → dd/MM/yyyy HH:mm:ss.
    /// Anything else (e.g. partial dates) is returned cleaned but unchanged.
    private func formatNfcDate(_ raw: String?) -> String? {
        guard let v = cleanNfcText(raw) else { return nil }
        guard v.allSatisfy({ $0.isASCII && $0.isNumber }) else { return v }
        let c = Array(v)
        func s(_ from: Int, _ to: Int) -> String { String(c[from..<to]) }
        switch c.count {
        case 8:
            return "\(s(6, 8))/\(s(4, 6))/\(s(0, 4))"
        case 14:
            return "\(s(6, 8))/\(s(4, 6))/\(s(0, 4)) \(s(8, 10)):\(s(10, 12)):\(s(12, 14))"
        default:
            return v
        }
    }

    /// NFC value when present, otherwise the OCR value
    private func nfcOr(_ nfcValue: String?, _ fallback: Any) -> Any {
        if let nfcValue = nfcValue { return nfcValue }
        return fallback
    }

    /// A chip value that carries no information ("-", "--", ".") counts as empty,
    /// so a placeholder in DG13 never hides a real value in DG11.
    private func meaningful(_ value: String?) -> String? {
        guard let v = cleanNfcText(value) else { return nil }
        let placeholder = v.allSatisfy { $0 == "-" || $0 == "." || $0 == " " }
        return placeholder ? nil : v
    }

    /// First candidate with a meaningful value wins; the source is kept for the logs.
    private func pick(_ candidates: (String, String?)...) -> Picked {
        for (source, value) in candidates {
            if let v = meaningful(value) {
                return Picked(value: v, source: source)
            }
        }
        return Picked(value: nil, source: "none")
    }


    // MARK: - Key classification

    /// Which value an output key holds.
    /// `contains()` is order-sensitive: specific keys ("Surname", "Name_Arabic", "Fathers_Name"...)
    /// also contain the base names, so the specific ones are always checked first.
    /// Surname is checked BEFORE name ("Surname" contains "name").
    /// Used by BOTH replaceDataWithNfcData and onTranslatedSuccess, so they always agree
    /// (Swift dictionaries have a random order, so "last key that matched" is not reliable).
    private enum NfcField: String {
        case fathersNameArabic, mothersNameArabic, placeOfBirthArabic, surnameArabic, nameArabic,
             nationalityArabic, sexArabic, recordId, dg13Extra
        case otherNames, mothersName, fathersName, personalNumber, fullDateOfBirth, placeOfBirth,
             permanentAddress, telephone, profession, title, personalSummary, otherValidTDNumbers,
             custodyInformation
        case issuingAuthority, dateOfIssue, namesOfOtherPersons, endorsementsAndObservations,
             taxOrExitRequirements, dateOfPersonalization, personalizationSystemSerialNumber
        case surname, name, nationality, documentNumber, sex
        case other
    }

    private func classify(_ key: String) -> NfcField {
        let K = IdentificationDocumentCaptureKeys.self
        let ordered: [(String, NfcField)] = [
            // Arabic / DG13 FIRST (their keys contain the base key names)
            (K.idFathersNameArabic, .fathersNameArabic),
            (K.idMothersNameArabic, .mothersNameArabic),
            (K.idPlaceOfBirthArabic, .placeOfBirthArabic),
            (K.idSurnameArabic, .surnameArabic),
            (K.idNameArabic, .nameArabic),
            (K.idNationalityArabic, .nationalityArabic),
            (K.idSexArabic, .sexArabic),
            (K.idRecordId, .recordId),
            (K.idDg13Extra, .dg13Extra),
            // DG11
            (K.idOtherNames, .otherNames),
            (K.idMothersName, .mothersName),
            (K.idFathersName, .fathersName),
            (K.idPersonalNumber, .personalNumber),
            (K.idFullDateOfBirth, .fullDateOfBirth),
            (K.idPlaceOfBirth, .placeOfBirth),
            (K.idPermanentAddress, .permanentAddress),
            (K.idTelephone, .telephone),
            (K.idProfession, .profession),
            (K.idTitle, .title),
            (K.idPersonalSummary, .personalSummary),
            (K.idOtherValidTDNumbers, .otherValidTDNumbers),
            (K.idCustodyInformation, .custodyInformation),
            // DG12
            (K.idIssuingAuthority, .issuingAuthority),
            (K.idDateOfIssue, .dateOfIssue),
            (K.idNamesOfOtherPersons, .namesOfOtherPersons),
            (K.idEndorsementsAndObservations, .endorsementsAndObservations),
            (K.idTaxOrExitRequirements, .taxOrExitRequirements),
            (K.idDateOfPersonalization, .dateOfPersonalization),
            (K.idPersonalizationSystemSerialNumber, .personalizationSystemSerialNumber),
            // DG1 (MRZ) LAST — surname before name
            (K.surname, .surname),
            (K.name, .name),
            (K.nationality, .nationality),
            (K.documentNumber, .documentNumber),
            (K.sex, .sex),
        ]
        // 1) Exact field match, case / "_" / space / leading "ID_" insensitive:
        //    "..._ID_PlaceOfBirth" == "..._Place_Of_Birth" == K.idPlaceOfBirth
        let field = normalizedField(key)
        for (pattern, kind) in ordered where !pattern.isEmpty && normalizedField(pattern) == field {
            return kind
        }
        // 2) Fallback: contains(), specific keys first (same as Kotlin)
        for (pattern, kind) in ordered where !pattern.isEmpty && key.contains(pattern) {
            return kind
        }
        return .other
    }

    /// "IdentificationDocumentCapture_Last_Name"     → "lastname"
    /// "IdentificationDocumentCapture_ID_PlaceOfBirth" → "placeofbirth"
    /// "IdentificationDocumentCapture_Place_Of_Birth"  → "placeofbirth"
    /// Only an uppercase "ID" followed by "_" or " " is stripped, so "Identity..." is untouched.
    private func normalizedField(_ key: String) -> String {
        var field = key.components(separatedBy: "IdentificationDocumentCapture_").last ?? key
        for prefix in ["ID_", "ID "] where field.hasPrefix(prefix) {
            field = String(field.dropFirst(prefix.count))
            break
        }
        return field.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }


    // MARK: - Value resolution (one place decides DG13 vs DG11 vs DG12 vs DG1)

    /// Every NFC value, with the source it came from.
    /// Rule: DG13 first (Lebanese issuer data), then DG11. A source with no meaningful value is skipped,
    /// so a passport with only DG11 (case 2) or mostly DG13 (case 1) both resolve correctly.
    private func resolveNfcValues(mrz: MrzData?, model: NFCPassportModel) -> [NfcField: Picked] {
        let dg11 = nfcDg11
        let dg12 = nfcDg12
        let dg13 = nfcDg13
        let holder = splitArabicHolderName(dg11?.nameOfHolder)

        var r = [NfcField: Picked]()

        // ---------- Parents (DG13 → DG11) ----------
        r[.fathersName] = pick(("DG13", dg13?.fatherName),
                               ("DG11", dg11?.fatherName))
        r[.fathersNameArabic] = pick(("DG13", dg13?.fatherNameArabic),
                                     ("DG11", dg11?.fatherNameArabic))
        r[.mothersName] = pick(("DG13", dg13?.motherFullName),
                               ("DG13", joinNames(dg13?.motherName, dg13?.motherFamilyName)),
                               ("DG11", dg11?.motherName))
        r[.mothersNameArabic] = pick(("DG13", dg13?.motherFullNameArabic),
                                     ("DG13", joinNames(dg13?.motherNameArabic, dg13?.motherFamilyNameArabic)),
                                     ("DG11", dg11?.motherNameArabic))

        // ---------- Place of birth ----------
        r[.placeOfBirth] = pick(("DG11", dg11?.placeOfBirth))            // Latin only exists in DG11
        r[.placeOfBirthArabic] = pick(("DG13", dg13?.placeOfBirthArabic),
                                      ("DG11", dg11?.placeOfBirthArabic))

        // ---------- Arabic names (DG13 → DG11 "name of holder") ----------
        r[.nameArabic] = pick(("DG13", dg13?.givenNamesArabic),
                              ("DG11 holder", holder.given))
        r[.surnameArabic] = pick(("DG13", dg13?.surnameArabic),
                                 ("DG11 holder", holder.surname))

        // ---------- DG13 only ----------
        r[.nationalityArabic] = pick(("DG13", dg13?.nationalityArabic))
        r[.sexArabic] = pick(("DG13", dg13?.sexArabic))
        r[.recordId] = pick(("DG13", dg13?.recordId))
        r[.dg13Extra] = pick(("DG13", dg13?.unrecognized))

        // ---------- DG11 only ----------
        r[.otherNames] = pick(("DG11", dg11?.otherNames))
        r[.personalNumber] = pick(("DG11", dg11?.personalNumber))
        r[.fullDateOfBirth] = pick(("DG11", dg11?.fullDateOfBirth))
        r[.permanentAddress] = pick(("DG11", dg11?.permanentAddress))
        r[.telephone] = pick(("DG11", dg11?.telephone))
        r[.profession] = pick(("DG11", dg11?.profession))
        r[.title] = pick(("DG11", dg11?.title))
        r[.personalSummary] = pick(("DG11", dg11?.personalSummary))
        r[.otherValidTDNumbers] = pick(("DG11", dg11?.otherValidTDNumbers))
        r[.custodyInformation] = pick(("DG11", dg11?.custodyInformation))

        // ---------- DG12 ----------
        r[.issuingAuthority] = pick(("DG12", dg12?.issuingAuthority))
        r[.dateOfIssue] = pick(("DG12", dg12?.dateOfIssue))
        r[.namesOfOtherPersons] = pick(("DG12", dg12?.namesOfOtherPersons))
        r[.endorsementsAndObservations] = pick(("DG12", dg12?.endorsementsAndObservations))
        r[.taxOrExitRequirements] = pick(("DG12", dg12?.taxOrExitRequirements))
        r[.dateOfPersonalization] = pick(("DG12", dg12?.dateAndTimeOfPersonalization))
        r[.personalizationSystemSerialNumber] = pick(("DG12", dg12?.personalizationSystemSerialNumber))

        // ---------- DG1 (MRZ) ----------
        r[.surname] = pick(("DG1", mrz?.surname))
        r[.name] = pick(("DG1", mrz?.givenNames))
        r[.nationality] = pick(("DG1", mrz?.nationality), ("DG1 lib", model.nationality))
        r[.documentNumber] = pick(("DG1", mrz?.documentNumber), ("DG1 lib", model.documentNumber))
        r[.sex] = pick(("DG1", mrz?.sex), ("DG1 lib", model.gender))

        debugLogResolved(r, dg11: dg11, dg13: dg13)
        return r
    }

    private func debugLogResolved(_ r: [NfcField: Picked], dg11: NfcDg11Data?, dg13: NfcDg13Data?) {
        debugLog("========== RESOLVED NFC VALUES ==========")
        for (field, picked) in r.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let value = picked.value.map { "\"\($0)\"" } ?? "nil"
            debugLog(String(format: "%-36@ = %@  [%@]", field.rawValue as NSString, value as NSString, picked.source as NSString))
        }

        // Both DGs have a value but they differ: DG13 wins, show it so it can be checked
        let overlaps: [(String, String?, String?)] = [
            ("fathersName", dg13?.fatherName, dg11?.fatherName),
            ("fathersNameArabic", dg13?.fatherNameArabic, dg11?.fatherNameArabic),
            ("mothersName", dg13?.motherName, dg11?.motherName),
            ("mothersNameArabic", dg13?.motherNameArabic, dg11?.motherNameArabic),
            ("placeOfBirthArabic", dg13?.placeOfBirthArabic, dg11?.placeOfBirthArabic),
        ]
        for (name, v13, v11) in overlaps {
            if let a = meaningful(v13), let b = meaningful(v11), a != b {
                debugLog("⚠️ \(name): DG13=\"\(a)\" differs from DG11=\"\(b)\" → using DG13")
            }
        }
    }


    // MARK: - Replace Data With Nfc Data

    private func replaceDataWithNfcData(nFCPassportModel: NFCPassportModel) {
        // DG1 (MRZ): name / surname are ALWAYS taken from DG1, like Kotlin
        let mrz = readMrz(nFCPassportModel)
        debugDump("DG1 MRZ", mrz)

        let resolved = resolveNfcValues(mrz: mrz, model: nFCPassportModel)
        self.dg1GivenNames = resolved[.name]?.value ?? ""
        self.dg1Surname = resolved[.surname]?.value ?? ""

        var outputProperties = [String: Any]()
        var unmatchedKeys = [String]()

        debugLog("========== KEY MAPPING (key -> field | before -> after [source]) ==========")

        if let originalOutputProps = passportResponseModel?.passportExtractedModel?.outputProperties {
            for (key, value) in originalOutputProps.sorted(by: { $0.key < $1.key }) {
                let kind = classify(key)
                let picked = resolved[kind]
                let newValue: Any

                switch kind {
                case .other:
                    newValue = value
                    unmatchedKeys.append(key)

                case .surname:
                    // Always DG1 (primaryIdentifier) — never the OCR value
                    let v = picked?.value ?? ""
                    newValue = v
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.surname = v

                case .name:
                    // Always DG1 (secondaryIdentifier) — never the OCR value
                    let v = picked?.value ?? ""
                    newValue = v
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.name = v

                case .nationality:
                    newValue = nfcOr(picked?.value, value)
                    if let v = picked?.value {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Nationality = v
                    }

                case .documentNumber:
                    newValue = nfcOr(picked?.value, value)
                    if let v = picked?.value {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Document_Number = v
                    }

                case .sex:
                    newValue = nfcOr(picked?.value, value)
                    if let v = picked?.value {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Sex = v
                    }

                default:
                    // Every DG11 / DG12 / DG13 field: NFC value if any, otherwise keep OCR
                    newValue = nfcOr(picked?.value, value)
                }

                outputProperties[key] = newValue

                let source = kind == .other ? "kept" : (picked?.value != nil ? picked!.source : "OCR kept")
                debugLog("\(extractedKey(key)) -> .\(kind.rawValue) | \"\(value)\" -> \"\(newValue)\" [\(source)]")
            }
        } else {
            debugLog("⚠️ outputProperties is nil: nothing to replace")
        }

        if !unmatchedKeys.isEmpty {
            debugLog("Keys classified as .other (left as OCR): \(unmatchedKeys.map { extractedKey($0) })")
        }

        // NFC values that exist but have NO key in the template (they cannot appear in the result)
        let usedFields = Set(outputProperties.keys.map { classify($0) })
        let lost = resolved.filter { $0.value.value != nil && !usedFields.contains($0.key) }
        for (field, picked) in lost.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            debugLog("ℹ️ .\(field.rawValue) = \"\(picked.value!)\" [\(picked.source)] has no key in the template")
        }

        var extractedData = [String: Any]()
        for (key, value) in outputProperties {
            extractedData[extractedKey(key)] = value
        }

        passportResponseModel?.passportExtractedModel?.outputProperties = outputProperties
        passportResponseModel?.passportExtractedModel?.transformedProperties = outputProperties.mapValues { "\($0)" }
        passportResponseModel?.passportExtractedModel?.extractedData = extractedData

        if self.language == Language.NON || self.apiKey.isEmpty {
            debugLogFinal(extractedData, title: "FINAL (no translation)")
            completeScan()
        } else {
            debugLog("Sending \(outputProperties.count) properties to translation (\(self.language ?? "nil"))")
            let transformed = LanguageTransformation(apiKey: self.apiKey, languageTransformationDelegate: self)
            transformed.languageTransformation(
                langauge: self.language!,
                transformationModel: preparePropertiesToTranslate(
                    language: self.language!,
                    properties: self.passportResponseModel!.passportExtractedModel?.outputProperties
                )
            )
        }
    }

    /// "IdentificationDocumentCapture_Place_Of_Birth" → "Place Of Birth"
    private func extractedKey(_ key: String) -> String {
        guard let range = key.range(of: "IdentificationDocumentCapture_") else {
            return key.replacingOccurrences(of: "_", with: " ")
        }
        return key[range.upperBound...].replacingOccurrences(of: "_", with: " ")
    }

    private func debugLogFinal(_ extractedData: [String: Any], title: String) {
        debugLog("========== \(title): \(extractedData.count) keys ==========")
        for (key, value) in extractedData.sorted(by: { $0.key < $1.key }) {
            debugLog("\(key) = \"\(value)\"")
        }
    }

    /// Every successful scan ends here
    private func completeScan() {
        guard let model = self.passportResponseModel else { return }
        self.scanNfcDelegate?.onCompleteNfcScan(dataModel: model)
    }


    // MARK: - Language Transformation

    /// Words of a name: separated by spaces, "<" (MRZ filler) or "#" (name separator)
    private func nameWords(_ value: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "<#"))
        return value.components(separatedBy: separators).filter { !$0.isEmpty }
    }

    /// Splits the translated full name back into (given names, surname).
    ///  - "عمر#محمد"   → ("عمر", "محمد")      (the '#' separator wins when present)
    ///  - "عمر محمد"  → first `givenWordCount` words are the given names, the rest is the surname
    private func splitTranslatedFullName(_ fullName: String, givenWordCount: Int) -> (given: String, surname: String) {
        if fullName.contains(Nfc.nameSeparator) {
            let parts = fullName.components(separatedBy: Nfc.nameSeparator)
            let given = cleanNfcText(parts.first) ?? ""
            let surname = cleanNfcText(parts.dropFirst().joined(separator: " ")) ?? ""
            return (given, surname)
        }
        let words = nameWords(fullName)
        let count = min(max(givenWordCount, 0), words.count)
        return (words.prefix(count).joined(separator: " "),
                words.dropFirst(count).joined(separator: " "))
    }

    public func onTranslatedSuccess(properties: [String: String]?) {
        if let props = properties,
           let outputProperties = self.passportResponseModel?.passportExtractedModel?.outputProperties {

            debugLog("========== TRANSLATION ==========")
            debugLog("Translated keys: \(props.count) / output keys: \(outputProperties.count)")

            // Exact name / surname keys: same classification as replaceDataWithNfcData
            let nameKey = outputProperties.keys.first { classify($0) == .name }
            let surnameKey = outputProperties.keys.first { classify($0) == .surname }
            let nameValue = nameKey.flatMap { outputProperties[$0] }.map { "\($0)" } ?? ""
            let nameWordCount = nameWords(nameValue).count

            // 1) Start from EVERY key (NFC values included), so a key that was not
            //    translated is never lost (this is what emptied case 1 before)
            var tempTransformedProperties = outputProperties.mapValues { "\($0)" }
            var tempExtractedData = [String: Any]()
            for (key, value) in outputProperties {
                tempExtractedData[extractedKey(key)] = value
            }

            // 2) Overlay translated values
            for (key, value) in props {
                if key == FullNameKey {
                    // Only used when DG1 had no value; the DG1 override below wins otherwise
                    let split = splitTranslatedFullName(value, givenWordCount: nameWordCount)
                    if let nameKey = nameKey {
                        tempTransformedProperties[nameKey] = split.given
                        tempExtractedData["name"] = split.given
                    }
                    if let surnameKey = surnameKey {
                        tempTransformedProperties[surnameKey] = split.surname
                        tempExtractedData["surname"] = split.surname
                    }
                } else {
                    tempTransformedProperties[key] = value
                    tempExtractedData[extractedKey(key)] = value
                }
            }

            // 3) Ignored properties keep their original value
            for (key, value) in getIgnoredProperties(properties: outputProperties) {
                tempTransformedProperties[key] = "\(value)"
                tempExtractedData[extractedKey(key)] = value
            }

            // 4) DG1 is the source of truth for name / surname: applied LAST
            if let nameKey = nameKey, let given = dg1GivenNames {
                tempTransformedProperties[nameKey] = given
                tempExtractedData["name"] = given
                tempExtractedData[extractedKey(nameKey)] = given
            }
            if let surnameKey = surnameKey, let surname = dg1Surname {
                tempTransformedProperties[surnameKey] = surname
                tempExtractedData["surname"] = surname
                tempExtractedData[extractedKey(surnameKey)] = surname
            }

            let notTranslated = outputProperties.keys.filter { props[$0] == nil }
            if !notTranslated.isEmpty {
                debugLog("Kept untranslated (\(notTranslated.count)): \(notTranslated.map { extractedKey($0) }.sorted())")
            }

            self.passportResponseModel?.passportExtractedModel?.transformedProperties = tempTransformedProperties
            self.passportResponseModel?.passportExtractedModel?.extractedData = tempExtractedData
            debugLogFinal(tempExtractedData, title: "FINAL (after translation)")
        } else {
            debugLog("⚠️ Translation returned no properties: keeping NFC values")
        }

        completeScan()
    }

    public func onTranslatedError(properties: [String: String]?) {
        debugLog("⚠️ Translation failed: keeping NFC values")
        completeScan()
    }
}
