
import Foundation

public struct BaseUrls {


    public let signalRHub: String
    public let baseURLSigning: String
    public let baseURLGateway: String
    public let languageTransformationUrl: String
    public let blobUrl: String

    public init(
        signalRHub: String = "https://widgets.socket.assentify.com/",
        baseURLSigning: String = "https://signme.assentify.com/api/",
        baseURLGateway: String = "https://api.gateway.assentify.com/webapi/",
        languageTransformationUrl: String = "https://widgets.socket.assentify.com/api/",
        blobUrl: String = "https://blob.assentify.com/"
    ) {
        self.signalRHub = signalRHub
        self.baseURLSigning = baseURLSigning
        self.baseURLGateway = baseURLGateway
        self.languageTransformationUrl = languageTransformationUrl
        self.blobUrl = blobUrl
    }


    public static let production = BaseUrls()


    public private(set) static var current = BaseUrls.production

    public static func configure(_ urls: BaseUrls) {
        current = urls
    }

    public static func reset() {
        current = .production
    }

    public static var signalRHub: String { current.signalRHub }
    public static var baseURLSigning: String { current.baseURLSigning }
    public static var baseURLGateway: String { current.baseURLGateway }
    public static var languageTransformationUrl: String { current.languageTransformationUrl }
    public static var blobUrl: String { current.blobUrl }
}

let  SENTRY_DNS = "https://74e4085c2e6d7091d58117d96a00a604@o4507430254673920.ingest.us.sentry.io/4507509355118592"



final class BlobSSLDelegate: NSObject, URLSessionDelegate {
    private let trustedHost: String

    init(trustedHost: String) {
        self.trustedHost = trustedHost
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == trustedHost,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        print("⚠️ [Upload] Bypassing SSL validation for \(trustedHost)")
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

enum BlobSession {
    static let touchBlobUrl = "https://ocr-cognitive.touch.com.lb/blob/"
    static let touchHost = "ocr-cognitive.touch.com.lb"

    static let shared = URLSession(configuration: .default,
                                   delegate: BlobSSLDelegate(trustedHost: touchHost),
                                   delegateQueue: nil)
}
