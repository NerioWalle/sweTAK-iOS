import Foundation
import CryptoKit
import Security
import os.log

// MARK: - Certificate Pin

/// A certificate pin for domain verification
public struct CertificatePin: Equatable {
    public let domain: String
    public let publicKeyHash: String  // Base64-encoded SHA-256 of SPKI

    public init(domain: String, publicKeyHash: String) {
        self.domain = domain
        self.publicKeyHash = publicKeyHash
    }
}

// MARK: - HTTP Error

/// HTTP client errors
public enum HTTPError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case certificatePinningFailed(domain: String)
    case timeout
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown")"
        case .certificatePinningFailed(let domain):
            return "Certificate pinning failed for \(domain)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request cancelled"
        }
    }
}

// MARK: - HTTP Response

/// HTTP response container
public struct HTTPResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let data: Data

    public var isSuccess: Bool {
        (200...299).contains(statusCode)
    }

    public func json() throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    public var string: String? {
        String(data: data, encoding: .utf8)
    }
}

// MARK: - Secure HTTP Client

/// HTTP client with TLS certificate pinning
/// Mirrors Android SecureHttpClient functionality
public final class SecureHttpClient: NSObject {

    // MARK: - Singleton

    public static let shared = SecureHttpClient()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "HTTP")

    // MARK: - Configuration

    /// Timeout for requests in seconds
    public var timeoutInterval: TimeInterval = 30

    /// User-Agent header value
    public var userAgent: String = "sweTAK/1.0 (iOS)"

    /// Enable certificate pinning
    public var pinningEnabled: Bool = true

    // MARK: - Certificate Pins

    /// Pinned certificates for domains
    /// Uses SPKI (Subject Public Key Info) SHA-256 hashes
    private var certificatePins: [String: [String]] = [
        // MapTiler API - Let's Encrypt certificates
        "api.maptiler.com": [
            // ISRG Root X1 (RSA)
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
            // ISRG Root X2 (ECDSA)
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=",
            // R3 intermediate
            "jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=",
            // E1 intermediate
            "J2/oqMTsdhFWW/n85tys6b4yDBtb6idZayIEBx7QTxA=",
            // R10 intermediate
            "e0IRz5Tio3GA1Xs4fUVJpkTGiWZnQv/Y7tfiQepgA64=",
            // R11 intermediate
            "5C8kvU039KouVrl52D0eZSGf4Onjo4Khs8tmyTlV3nU="
        ],
        // OpenTopoData API - Let's Encrypt certificates
        "api.opentopodata.org": [
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=",
            "jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=",
            "J2/oqMTsdhFWW/n85tys6b4yDBtb6idZayIEBx7QTxA=",
            "e0IRz5Tio3GA1Xs4fUVJpkTGiWZnQv/Y7tfiQepgA64=",
            "5C8kvU039KouVrl52D0eZSGf4Onjo4Khs8tmyTlV3nU="
        ]
    ]

    // MARK: - Session

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent
        ]
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Add certificate pin for a domain
    public func addCertificatePin(domain: String, publicKeyHash: String) {
        if certificatePins[domain] == nil {
            certificatePins[domain] = []
        }
        certificatePins[domain]?.append(publicKeyHash)
        logger.info("Added certificate pin for \(domain)")
    }

    /// Remove certificate pins for a domain
    public func removeCertificatePins(for domain: String) {
        certificatePins.removeValue(forKey: domain)
        logger.info("Removed certificate pins for \(domain)")
    }

    /// Check if a domain has certificate pins
    public func hasPins(for domain: String) -> Bool {
        certificatePins[domain]?.isEmpty == false
    }

    // MARK: - HTTP Methods

    /// Perform a GET request
    public func get(
        url: String,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await request(url: url, method: "GET", headers: headers)
    }

    /// Perform a POST request
    public func post(
        url: String,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await request(url: url, method: "POST", body: body, headers: headers)
    }

    /// Perform a POST request with JSON body
    public func postJSON<T: Encodable>(
        url: String,
        body: T,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        let data = try JSONEncoder().encode(body)
        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"
        return try await request(url: url, method: "POST", body: data, headers: allHeaders)
    }

    /// Perform a PUT request
    public func put(
        url: String,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await request(url: url, method: "PUT", body: body, headers: headers)
    }

    /// Perform a DELETE request
    public func delete(
        url: String,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await request(url: url, method: "DELETE", headers: headers)
    }

    /// Perform a generic HTTP request
    public func request(
        url: String,
        method: String,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        guard let requestURL = URL(string: url) else {
            throw HTTPError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeoutInterval

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        logger.debug("\(method) \(url)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }

            let responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }

            let httpResponseObj = HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: responseHeaders,
                data: data
            )

            logger.debug("\(method) \(url) -> \(httpResponse.statusCode)")

            if !httpResponseObj.isSuccess {
                throw HTTPError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: httpResponseObj.string
                )
            }

            return httpResponseObj

        } catch let error as HTTPError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw HTTPError.timeout
            case .cancelled:
                throw HTTPError.cancelled
            default:
                throw HTTPError.networkError(error)
            }
        } catch {
            throw HTTPError.networkError(error)
        }
    }

    /// Download data from URL
    public func download(url: String) async throws -> Data {
        let response = try await get(url: url)
        return response.data
    }

    /// Fetch JSON from URL
    public func fetchJSON(url: String) async throws -> Any {
        let response = try await get(url: url, headers: ["Accept": "application/json"])
        return try response.json()
    }

    /// Fetch and decode JSON
    public func fetch<T: Decodable>(url: String, as type: T.Type) async throws -> T {
        let response = try await get(url: url, headers: ["Accept": "application/json"])
        return try response.decode(type)
    }
}

// MARK: - URLSessionDelegate (Certificate Pinning)

extension SecureHttpClient: URLSessionDelegate {

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // If pinning is disabled or no pins for this host, use default handling
        guard pinningEnabled, let pins = certificatePins[host], !pins.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Verify certificate chain
        var result: SecTrustResultType = .invalid
        SecTrustEvaluate(serverTrust, &result)

        guard result == .unspecified || result == .proceed else {
            logger.error("Certificate chain validation failed for \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        // Check if any certificate in chain matches our pins
        var pinMatched = false

        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }

            // Get public key hash
            if let publicKeyHash = getPublicKeyHash(from: certificate) {
                if pins.contains(publicKeyHash) {
                    pinMatched = true
                    break
                }
            }
        }

        if pinMatched {
            logger.debug("Certificate pin matched for \(host)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            logger.error("Certificate pinning failed for \(host) - no matching pins")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Get SHA-256 hash of certificate's public key (SPKI)
    private func getPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // Calculate SHA-256 hash
        let hash = SHA256.hash(data: publicKeyData)
        let hashData = Data(hash)

        return hashData.base64EncodedString()
    }
}

// MARK: - Elevation API Client

/// Client for elevation data APIs with certificate pinning
public final class ElevationAPIClient {

    // MARK: - Singleton

    public static let shared = ElevationAPIClient()

    // MARK: - Properties

    private let httpClient = SecureHttpClient.shared
    private let logger = Logger(subsystem: "com.swetak", category: "Elevation")

    // MARK: - API Keys

    private var mapTilerApiKey: String?

    // MARK: - Configuration

    public func setMapTilerApiKey(_ key: String) {
        mapTilerApiKey = key
    }

    // MARK: - Public API

    /// Get elevation for a single point
    public func getElevation(latitude: Double, longitude: Double) async throws -> Double? {
        // Try MapTiler first
        if let apiKey = mapTilerApiKey {
            if let elevation = try? await getElevationFromMapTiler(
                latitude: latitude,
                longitude: longitude,
                apiKey: apiKey
            ) {
                return elevation
            }
        }

        // Fallback to OpenTopoData
        return try await getElevationFromOpenTopoData(latitude: latitude, longitude: longitude)
    }

    /// Get elevations for multiple points
    public func getElevations(coordinates: [(latitude: Double, longitude: Double)]) async throws -> [Double?] {
        var results: [Double?] = []

        for coord in coordinates {
            let elevation = try await getElevation(latitude: coord.latitude, longitude: coord.longitude)
            results.append(elevation)
        }

        return results
    }

    // MARK: - Private API Methods

    private func getElevationFromMapTiler(
        latitude: Double,
        longitude: Double,
        apiKey: String
    ) async throws -> Double? {
        let url = "https://api.maptiler.com/tiles/terrain-rgb/12/\(longitude)/\(latitude).png?key=\(apiKey)"

        // MapTiler returns terrain-rgb tiles, need to decode elevation from pixel values
        // For simplicity, using their elevation API endpoint instead
        let elevationUrl = "https://api.maptiler.com/tiles/terrain-quantized-mesh/\(Int(latitude)),\(Int(longitude)).terrain?key=\(apiKey)"

        // This is a simplified implementation
        // Real implementation would use terrain-rgb decoding
        logger.debug("MapTiler elevation request for \(latitude), \(longitude)")

        return nil  // Placeholder - implement terrain-rgb decoding
    }

    private func getElevationFromOpenTopoData(
        latitude: Double,
        longitude: Double
    ) async throws -> Double? {
        let url = "https://api.opentopodata.org/v1/srtm30m?locations=\(latitude),\(longitude)"

        logger.debug("OpenTopoData elevation request for \(latitude), \(longitude)")

        let response = try await httpClient.get(url: url)
        let json = try response.json()

        guard let dict = json as? [String: Any],
              let results = dict["results"] as? [[String: Any]],
              let first = results.first,
              let elevation = first["elevation"] as? Double else {
            return nil
        }

        return elevation
    }
}

// MARK: - HTTP Request Builder

/// Fluent builder for HTTP requests
public final class HTTPRequestBuilder {

    private var url: String
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?
    private var timeout: TimeInterval?

    public init(url: String) {
        self.url = url
    }

    public func method(_ method: String) -> HTTPRequestBuilder {
        self.method = method
        return self
    }

    public func header(_ key: String, _ value: String) -> HTTPRequestBuilder {
        headers[key] = value
        return self
    }

    public func headers(_ headers: [String: String]) -> HTTPRequestBuilder {
        self.headers.merge(headers) { _, new in new }
        return self
    }

    public func body(_ data: Data) -> HTTPRequestBuilder {
        self.body = data
        return self
    }

    public func jsonBody<T: Encodable>(_ value: T) throws -> HTTPRequestBuilder {
        self.body = try JSONEncoder().encode(value)
        headers["Content-Type"] = "application/json"
        return self
    }

    public func timeout(_ seconds: TimeInterval) -> HTTPRequestBuilder {
        self.timeout = seconds
        return self
    }

    public func execute() async throws -> HTTPResponse {
        let client = SecureHttpClient.shared
        if let timeout = timeout {
            client.timeoutInterval = timeout
        }
        return try await client.request(url: url, method: method, body: body, headers: headers)
    }
}

// MARK: - Convenience Extensions

extension SecureHttpClient {
    /// Create a request builder
    public func request(to url: String) -> HTTPRequestBuilder {
        HTTPRequestBuilder(url: url)
    }
}
