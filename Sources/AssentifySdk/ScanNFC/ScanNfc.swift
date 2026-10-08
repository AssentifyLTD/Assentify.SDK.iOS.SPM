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
    }

    private func rawBytes(_ model: NFCPassportModel, _ id: DataGroupId) -> [UInt8]? {
        guard let dg = model.dataGroupsRead[id] else { return nil }
        let bytes = dg.data
        return bytes.isEmpty ? nil : bytes
    }

    /// DG1 values read straight from the chip MRZ (same as JMRTD MRZInfo on Android).
    private struct MrzData {
        var surname: String?          // primaryIdentifier
        var givenNames: String?       // secondaryIdentifier
        var documentNumber: String?
        var nationality: String?
        var sex: String?
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
        let joined = [first, second].compactMap { $0 }.joined(separator: " ")
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


    // MARK: - Key classification

    /// Which value an output key holds.
    /// `contains()` is order-sensitive: specific keys ("Surname", "Name_Arabic", "Fathers_Name"...)
    /// also contain the base names, so the specific ones are always checked first.
    /// Surname is checked BEFORE name ("Surname" contains "name").
    /// Used by BOTH replaceDataWithNfcData and onTranslatedSuccess, so they always agree
    /// (Swift dictionaries have a random order, so "last key that matched" is not reliable).
    private enum NfcField {
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
        // 1) Exact field match, case / "_" / space insensitive:
        //    "IdentificationDocumentCapture_surname" == K.surname even if K.surname is "Surname"
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

    /// "IdentificationDocumentCapture_Last_Name" → "lastname"
    private func normalizedField(_ key: String) -> String {
        let field = key.components(separatedBy: "IdentificationDocumentCapture_").last ?? key
        return field.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }


    // MARK: - Replace Data With Nfc Data

    private func replaceDataWithNfcData(nFCPassportModel: NFCPassportModel) {
        let dg11 = nfcDg11
        let dg12 = nfcDg12
        let dg13 = nfcDg13

        // Best source first: DG13 (Lebanese issuer data) → DG11 → OCR value (via nfcOr)
        let fatherName = dg13?.fatherName ?? dg11?.fatherName
        let fatherNameArabic = dg13?.fatherNameArabic ?? dg11?.fatherNameArabic
        let motherName = dg13?.motherFullName
            ?? joinNames(dg13?.motherName, dg13?.motherFamilyName)
            ?? dg11?.motherName
        let motherNameArabic = dg13?.motherFullNameArabic
            ?? joinNames(dg13?.motherNameArabic, dg13?.motherFamilyNameArabic)
            ?? dg11?.motherNameArabic
        let placeOfBirth = dg11?.placeOfBirth                              // Latin only exists in DG11
        let placeOfBirthArabic = dg13?.placeOfBirthArabic ?? dg11?.placeOfBirthArabic

        // DG1 (MRZ): given names / surname come from the chip MRZ ("SURNAME<<GIVEN<NAMES").
        // Cleaned ("<" → space, trimmed). Like Kotlin, name / surname are ALWAYS taken from DG1.
        let mrz = readMrz(nFCPassportModel)
        let mrzGivenNames = mrz?.givenNames ?? ""
        let mrzSurname = mrz?.surname ?? ""
        let mrzNationality = mrz?.nationality ?? cleanNfcText(nFCPassportModel.nationality)
        let mrzDocumentNumber = mrz?.documentNumber ?? cleanNfcText(nFCPassportModel.documentNumber)
        let mrzSex = mrz?.sex ?? cleanNfcText(nFCPassportModel.gender)
        self.dg1GivenNames = mrzGivenNames
        self.dg1Surname = mrzSurname

        

        var outputProperties = [String: Any]()

        if let originalOutputProps = passportResponseModel?.passportExtractedModel?.outputProperties {
            for (key, value) in originalOutputProps {
               
                switch classify(key) {

                // ---------- Arabic / DG13 ----------
                case .fathersNameArabic:  outputProperties[key] = nfcOr(fatherNameArabic, value)
                case .mothersNameArabic:  outputProperties[key] = nfcOr(motherNameArabic, value)
                case .placeOfBirthArabic: outputProperties[key] = nfcOr(placeOfBirthArabic, value)
                case .surnameArabic:      outputProperties[key] = nfcOr(dg13?.surnameArabic, value)
                case .nameArabic:         outputProperties[key] = nfcOr(dg13?.givenNamesArabic, value)
                case .nationalityArabic:  outputProperties[key] = nfcOr(dg13?.nationalityArabic, value)
                case .sexArabic:          outputProperties[key] = nfcOr(dg13?.sexArabic, value)
                case .recordId:           outputProperties[key] = nfcOr(dg13?.recordId, value)
                case .dg13Extra:          outputProperties[key] = nfcOr(dg13?.unrecognized, value)

                // ---------- DG11 ----------
                case .otherNames:          outputProperties[key] = nfcOr(dg11?.otherNames, value)
                case .mothersName:         outputProperties[key] = nfcOr(motherName, value)
                case .fathersName:         outputProperties[key] = nfcOr(fatherName, value)
                case .personalNumber:      outputProperties[key] = nfcOr(dg11?.personalNumber, value)
                case .fullDateOfBirth:     outputProperties[key] = nfcOr(dg11?.fullDateOfBirth, value)
                case .placeOfBirth:        outputProperties[key] = nfcOr(placeOfBirth, value)
                case .permanentAddress:    outputProperties[key] = nfcOr(dg11?.permanentAddress, value)
                case .telephone:           outputProperties[key] = nfcOr(dg11?.telephone, value)
                case .profession:          outputProperties[key] = nfcOr(dg11?.profession, value)
                case .title:               outputProperties[key] = nfcOr(dg11?.title, value)
                case .personalSummary:     outputProperties[key] = nfcOr(dg11?.personalSummary, value)
                case .otherValidTDNumbers: outputProperties[key] = nfcOr(dg11?.otherValidTDNumbers, value)
                case .custodyInformation:  outputProperties[key] = nfcOr(dg11?.custodyInformation, value)

                // ---------- DG12 ----------
                case .issuingAuthority:            outputProperties[key] = nfcOr(dg12?.issuingAuthority, value)
                case .dateOfIssue:                 outputProperties[key] = nfcOr(dg12?.dateOfIssue, value)
                case .namesOfOtherPersons:         outputProperties[key] = nfcOr(dg12?.namesOfOtherPersons, value)
                case .endorsementsAndObservations: outputProperties[key] = nfcOr(dg12?.endorsementsAndObservations, value)
                case .taxOrExitRequirements:       outputProperties[key] = nfcOr(dg12?.taxOrExitRequirements, value)
                case .dateOfPersonalization:       outputProperties[key] = nfcOr(dg12?.dateAndTimeOfPersonalization, value)
                case .personalizationSystemSerialNumber:
                    outputProperties[key] = nfcOr(dg12?.personalizationSystemSerialNumber, value)

                // ---------- DG1 (MRZ) ----------
                case .surname:
                    // Always DG1, like Kotlin (primaryIdentifier) — never the OCR value
                    outputProperties[key] = mrzSurname
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.surname = mrzSurname
                case .name:
                    // Always DG1, like Kotlin (secondaryIdentifier) — never the OCR value
                    outputProperties[key] = mrzGivenNames
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.name = mrzGivenNames
                case .nationality:
                    outputProperties[key] = nfcOr(mrzNationality, value)
                    if let v = mrzNationality {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Nationality = v
                    }
                case .documentNumber:
                    outputProperties[key] = nfcOr(mrzDocumentNumber, value)
                    if let v = mrzDocumentNumber {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Document_Number = v
                    }
                case .sex:
                    outputProperties[key] = nfcOr(mrzSex, value)
                    if let v = mrzSex {
                        passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Sex = v
                    }

                case .other:
                    outputProperties[key] = value
                }
            }
        }

        var extractedData = [String: Any]()
        for (key, value) in outputProperties {
            extractedData[extractedKey(key)] = value
        }

        passportResponseModel?.passportExtractedModel?.outputProperties = outputProperties
        passportResponseModel?.passportExtractedModel?.transformedProperties = outputProperties.mapValues { "\($0)" }
        passportResponseModel?.passportExtractedModel?.extractedData = extractedData

        if self.language == Language.NON || self.apiKey.isEmpty {
            completeScan()
        } else {
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

            // Exact name / surname keys: same classification as replaceDataWithNfcData
            let nameKey = outputProperties.keys.first { classify($0) == .name }
            let surnameKey = outputProperties.keys.first { classify($0) == .surname }
            let nameValue = nameKey.flatMap { outputProperties[$0] }.map { "\($0)" } ?? ""
            let nameWordCount = nameWords(nameValue).count

            var tempTransformedProperties = [String: String]()
            var tempExtractedData = [String: Any]()

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

            for (key, value) in getIgnoredProperties(properties: outputProperties) {
                tempTransformedProperties[key] = "\(value)"
                tempExtractedData[extractedKey(key)] = value
            }

            // DG1 is the source of truth for name / surname: applied LAST so nothing
            // (the translated full name, a translated key, ignored properties) can overwrite it
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

            self.passportResponseModel?.passportExtractedModel?.transformedProperties = tempTransformedProperties
            self.passportResponseModel?.passportExtractedModel?.extractedData = tempExtractedData
        }

        completeScan()
    }

    public func onTranslatedError(properties: [String: String]?) {
        completeScan()
    }
}
