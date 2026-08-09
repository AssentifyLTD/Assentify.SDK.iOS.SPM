import Foundation

public enum OtpHelper {
    
    public static func requestOtp(
          config: ConfigModel,
          requestOtpModel: RequestOtpModel,
          completion: @escaping (BaseResult<Bool, Error>) -> Void
      ) {

          // Build URL with query params
          var components = URLComponents(string: BaseUrls.baseURLGateway + "v1/OtpVerification/RequestOtp")
          

          guard let url = components?.url else {
              completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

          // ✅ headers (same as Kotlin)
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("iOS SDK", forHTTPHeaderField: "X-Source-Agent")
          request.setValue(config.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
          request.setValue(config.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
          request.setValue(config.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
          request.setValue(config.instanceId, forHTTPHeaderField: "X-Instance-Id")
          request.setValue(config.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
          request.setValue(config.instanceHash, forHTTPHeaderField: "X-Instance-Hash")

          
          do {
              let encoder = JSONEncoder()
              let jsonData = try encoder.encode(requestOtpModel)

              

              request.httpBody = jsonData
          } catch {
              completion(.failure(error))
              return
          }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in

              if let error {
                  completion(.failure(error))
                  return
              }

              guard let http = response as? HTTPURLResponse else {
                  completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                  return
              }

              guard (200...299).contains(http.statusCode) else {
                  // if you want: parse error body here
                  completion(.failure(NSError(domain: "HTTP \(http.statusCode)", code: http.statusCode, userInfo: nil)))
                  return
              }

              guard let data else {
                  completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                  return
              }

              do {
                  let decoder = JSONDecoder()
                  let result = try decoder.decode(RequestOtpResponseModel.self, from: data)
                  completion(.success(result.isSuccessful))
              } catch {
                  completion(.failure(error))
              }
          }

          task.resume()
      }
    
    public static func verifyOtp(
          config: ConfigModel,
          verifyOtpRequestOtpModel: VerifyOtpRequestOtpModel,
          completion: @escaping (BaseResult<Bool, Error>) -> Void
      ) {

          // Build URL with query params
          var components = URLComponents(string: BaseUrls.baseURLGateway + "v1/OtpVerification/VerifyOtp")
          

          guard let url = components?.url else {
              completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

          // ✅ headers (same as Kotlin)
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("iOS SDK", forHTTPHeaderField: "X-Source-Agent")
          request.setValue(config.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
          request.setValue(config.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
          request.setValue(config.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
          request.setValue(config.instanceId, forHTTPHeaderField: "X-Instance-Id")
          request.setValue(config.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
          request.setValue(config.instanceHash, forHTTPHeaderField: "X-Instance-Hash")

        

          do {
              let encoder = JSONEncoder()
              request.httpBody = try encoder.encode(verifyOtpRequestOtpModel)
          } catch {
              completion(.failure(error))
              return
          }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in

              if let error {
                  completion(.failure(error))
                  return
              }

              guard let http = response as? HTTPURLResponse else {
                  completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                  return
              }

              guard (200...299).contains(http.statusCode) else {
                  // if you want: parse error body here
                  completion(.failure(NSError(domain: "HTTP \(http.statusCode)", code: http.statusCode, userInfo: nil)))
                  return
              }

              guard let data else {
                  completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                  return
              }

              do {
                  let decoder = JSONDecoder()
                  let result = try decoder.decode(VerifyOtpResponseOtpModel.self, from: data)
                  let success = result.isSuccessful && result.data
                  completion(.success(success))
              } catch {
                  completion(.failure(error))
              }
          }

          task.resume()
      }
}



// MARK: - Request OTP

public struct RequestOtpModel: Codable {
    public let token: String
    public let inputType: String
    public let otpSize: Int
    public let otpType: Int
    public let otpExpiryTime: Double
    public let otpFormat: Int?
    public let smsProvider: Int?
    public let whatsappProvider: Int?
    public init(
        token: String,
        inputType: String,
        otpSize: Int,
        otpType: Int,
        otpExpiryTime: Double,
        otpFormat: Int,
        smsProvider: Int?,
        whatsappProvider: Int?,
    ) {
        self.token = token
        self.inputType = inputType
        self.otpSize = otpSize
        self.otpType = otpType
        self.otpExpiryTime = otpExpiryTime
        self.otpFormat = otpFormat
        self.smsProvider = smsProvider
        self.whatsappProvider = whatsappProvider
    }
}

public struct RequestOtpResponseModel: Codable {
    public let message: String?
    public let error: String?
    public let statusCode: Int?
    public let isSuccessful: Bool
    public let otpExpiryTime: Double?

    public init(
        message: String?,
        error: String?,
        statusCode: Int,
        isSuccessful: Bool,
        otpExpiryTime: Double
    ) {
        self.message = message
        self.error = error
        self.statusCode = statusCode
        self.isSuccessful = isSuccessful
        self.otpExpiryTime = otpExpiryTime
    }
}

// MARK: - Verify OTP

public struct VerifyOtpRequestOtpModel: Codable {
    public let token: String
    public let otp: String
    public let otpExpiryTime: Double

    public init(
        token: String,
        otp: String,
        otpExpiryTime: Double
    ) {
        self.token = token
        self.otp = otp
        self.otpExpiryTime = otpExpiryTime
    }
}

public struct VerifyOtpResponseOtpModel: Codable {
    public let message: String?
    public let error: String?
    public let statusCode: Int
    public let isSuccessful: Bool
    public let data: Bool

    public init(
        message: String?,
        error: String?,
        statusCode: Int,
        isSuccessful: Bool,
        data: Bool
    ) {
        self.message = message
        self.error = error
        self.statusCode = statusCode
        self.isSuccessful = isSuccessful
        self.data = data
    }
}
