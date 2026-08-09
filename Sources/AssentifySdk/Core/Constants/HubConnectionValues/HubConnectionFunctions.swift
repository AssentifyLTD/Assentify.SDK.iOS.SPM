
import Foundation



class HubConnectionFunctions {
    static func etHubConnectionFunction(blockType: BlockType) -> String {
        switch blockType {
        case BlockType.READ_PASSPORT:
            return "v2/api/IdentificationDocument/ReadPassport"
        case  BlockType.ID_CARD:
            return "v2/api/IdentificationDocument/ReadId"
        case  BlockType.OTHER:
            return "v2/api/IdentificationDocument/Other"
        case BlockType.FACE_MATCH:
            return "v2/api/IdentificationDocument/FaceMatchWithImage"
        case BlockType.QR:
            return "v2/api/IdentificationDocument/ReadIdQrCode"
       }
    }
}

