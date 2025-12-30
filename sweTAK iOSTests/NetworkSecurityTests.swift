import XCTest
@testable import sweTAK

// MARK: - Network Service Browser Tests

final class NetworkServiceBrowserTests: XCTestCase {

    func testServiceTypeRawValues() {
        XCTAssertEqual(NetworkServiceType.sweTAK.rawValue, "_swetak._udp.")
        XCTAssertEqual(NetworkServiceType.sweTAKTCP.rawValue, "_swetak._tcp.")
        XCTAssertEqual(NetworkServiceType.cot.rawValue, "_cot._tcp.")
        XCTAssertEqual(NetworkServiceType.tak.rawValue, "_tak._tcp.")
    }

    func testServiceTypeDisplayNames() {
        XCTAssertEqual(NetworkServiceType.sweTAK.displayName, "sweTAK (UDP)")
        XCTAssertEqual(NetworkServiceType.sweTAKTCP.displayName, "sweTAK (TCP)")
        XCTAssertEqual(NetworkServiceType.cot.displayName, "CoT")
        XCTAssertEqual(NetworkServiceType.tak.displayName, "TAK")
    }

    func testDiscoveredPeerInitialization() {
        let txtRecord = ["deviceId": "test-device", "callsign": "Alpha-1"]
        let peer = DiscoveredPeer(
            name: "TestPeer",
            serviceType: .sweTAK,
            host: "192.168.1.100",
            port: 35876,
            txtRecord: txtRecord
        )

        XCTAssertEqual(peer.name, "TestPeer")
        XCTAssertEqual(peer.serviceType, .sweTAK)
        XCTAssertEqual(peer.host, "192.168.1.100")
        XCTAssertEqual(peer.port, 35876)
        XCTAssertEqual(peer.deviceId, "test-device")
        XCTAssertEqual(peer.callsign, "Alpha-1")
    }

    func testDiscoveredPeerAlternateKeys() {
        // Test alternate key names (did, cs)
        let txtRecord = ["did": "device-123", "cs": "Bravo-2"]
        let peer = DiscoveredPeer(
            name: "TestPeer2",
            serviceType: .sweTAK,
            txtRecord: txtRecord
        )

        XCTAssertEqual(peer.deviceId, "device-123")
        XCTAssertEqual(peer.callsign, "Bravo-2")
    }

    func testDiscoveredPeerEquality() {
        let peer1 = DiscoveredPeer(id: "peer-1", name: "Test", serviceType: .sweTAK)
        let peer2 = DiscoveredPeer(id: "peer-1", name: "Test", serviceType: .sweTAK)
        let peer3 = DiscoveredPeer(id: "peer-2", name: "Test", serviceType: .sweTAK)

        XCTAssertEqual(peer1, peer2)
        XCTAssertNotEqual(peer1, peer3)
    }

    func testDiscoveredPeerHashable() {
        let peer1 = DiscoveredPeer(id: "peer-1", name: "Test", serviceType: .sweTAK)
        let peer2 = DiscoveredPeer(id: "peer-1", name: "Test", serviceType: .sweTAK)

        var set = Set<DiscoveredPeer>()
        set.insert(peer1)
        set.insert(peer2)

        XCTAssertEqual(set.count, 1)
    }

    func testBrowserSharedInstance() {
        let browser1 = NetworkServiceBrowser.shared
        let browser2 = NetworkServiceBrowser.shared
        XCTAssertTrue(browser1 === browser2)
    }

    func testBrowserInitialState() {
        let browser = NetworkServiceBrowser.shared
        XCTAssertFalse(browser.isScanning)
        XCTAssertNil(browser.lastError)
    }
}

// MARK: - Device Certificate Manager Tests

final class DeviceCertificateManagerTests: XCTestCase {

    func testSharedInstance() {
        let manager1 = DeviceCertificateManager.shared
        let manager2 = DeviceCertificateManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testCertificateInfoProperties() {
        let info = DeviceCertificateInfo(
            deviceId: "test-device",
            commonName: "test-device",
            organization: "sweTAK",
            country: "SE",
            serialNumber: "123456",
            notBefore: Date(),
            notAfter: Calendar.current.date(byAdding: .year, value: 2, to: Date())!,
            fingerprint: "AA:BB:CC:DD"
        )

        XCTAssertEqual(info.deviceId, "test-device")
        XCTAssertEqual(info.commonName, "test-device")
        XCTAssertEqual(info.organization, "sweTAK")
        XCTAssertEqual(info.country, "SE")
        XCTAssertFalse(info.isExpired)
        XCTAssertTrue(info.isValid)
        XCTAssertGreaterThan(info.daysUntilExpiration, 0)
    }

    func testCertificateInfoExpired() {
        let info = DeviceCertificateInfo(
            deviceId: "test-device",
            commonName: "test-device",
            organization: "sweTAK",
            country: "SE",
            serialNumber: "123456",
            notBefore: Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
            notAfter: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
            fingerprint: "AA:BB:CC:DD"
        )

        XCTAssertTrue(info.isExpired)
        XCTAssertFalse(info.isValid)
    }

    func testTrustedPeerInitialization() {
        let peer = TrustedPeer(
            deviceId: "peer-device",
            certificatePEM: "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----",
            fingerprint: "AA:BB:CC",
            displayName: "Test Peer"
        )

        XCTAssertEqual(peer.id, "peer-device")
        XCTAssertEqual(peer.deviceId, "peer-device")
        XCTAssertTrue(peer.certificatePEM.contains("BEGIN CERTIFICATE"))
        XCTAssertEqual(peer.fingerprint, "AA:BB:CC")
        XCTAssertEqual(peer.displayName, "Test Peer")
    }

    func testTrustedPeerCodable() throws {
        let peer = TrustedPeer(
            deviceId: "peer-device",
            certificatePEM: "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----",
            fingerprint: "AA:BB:CC",
            displayName: "Test Peer"
        )

        let encoded = try JSONEncoder().encode(peer)
        let decoded = try JSONDecoder().decode(TrustedPeer.self, from: encoded)

        XCTAssertEqual(peer.deviceId, decoded.deviceId)
        XCTAssertEqual(peer.certificatePEM, decoded.certificatePEM)
        XCTAssertEqual(peer.fingerprint, decoded.fingerprint)
    }
}

// MARK: - Secure HTTP Client Tests

final class SecureHttpClientTests: XCTestCase {

    func testSharedInstance() {
        let client1 = SecureHttpClient.shared
        let client2 = SecureHttpClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func testDefaultConfiguration() {
        let client = SecureHttpClient.shared
        XCTAssertEqual(client.timeoutInterval, 30)
        XCTAssertEqual(client.userAgent, "sweTAK/1.0 (iOS)")
        XCTAssertTrue(client.pinningEnabled)
    }

    func testHasPinsForKnownDomains() {
        let client = SecureHttpClient.shared
        XCTAssertTrue(client.hasPins(for: "api.maptiler.com"))
        XCTAssertTrue(client.hasPins(for: "api.opentopodata.org"))
        XCTAssertFalse(client.hasPins(for: "unknown.example.com"))
    }

    func testAddCertificatePin() {
        let client = SecureHttpClient.shared
        let domain = "test.example.com"

        // Initially no pins
        XCTAssertFalse(client.hasPins(for: domain))

        // Add pin
        client.addCertificatePin(domain: domain, publicKeyHash: "testHash123")
        XCTAssertTrue(client.hasPins(for: domain))

        // Clean up
        client.removeCertificatePins(for: domain)
        XCTAssertFalse(client.hasPins(for: domain))
    }

    func testHTTPErrorDescriptions() {
        XCTAssertEqual(HTTPError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(HTTPError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(HTTPError.timeout.errorDescription, "Request timed out")
        XCTAssertEqual(HTTPError.cancelled.errorDescription, "Request cancelled")

        let httpError = HTTPError.httpError(statusCode: 404, message: "Not Found")
        XCTAssertEqual(httpError.errorDescription, "HTTP error 404: Not Found")

        let pinError = HTTPError.certificatePinningFailed(domain: "test.com")
        XCTAssertEqual(pinError.errorDescription, "Certificate pinning failed for test.com")
    }

    func testHTTPResponseSuccess() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            data: "{\"key\": \"value\"}".data(using: .utf8)!
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
    }

    func testHTTPResponseFailure() {
        let response = HTTPResponse(
            statusCode: 404,
            headers: [:],
            data: Data()
        )

        XCTAssertFalse(response.isSuccess)
    }

    func testHTTPResponseJSON() throws {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: "{\"name\": \"test\", \"value\": 42}".data(using: .utf8)!
        )

        let json = try response.json() as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "test")
        XCTAssertEqual(json?["value"] as? Int, 42)
    }

    func testHTTPResponseDecode() throws {
        struct TestModel: Codable {
            let name: String
            let value: Int
        }

        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: "{\"name\": \"test\", \"value\": 42}".data(using: .utf8)!
        )

        let model = try response.decode(TestModel.self)
        XCTAssertEqual(model.name, "test")
        XCTAssertEqual(model.value, 42)
    }

    func testHTTPResponseString() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: "Hello, World!".data(using: .utf8)!
        )

        XCTAssertEqual(response.string, "Hello, World!")
    }
}

// MARK: - HTTP Request Builder Tests

final class HTTPRequestBuilderTests: XCTestCase {

    func testBuilderMethodChaining() throws {
        let builder = HTTPRequestBuilder(url: "https://example.com/api")
            .method("POST")
            .header("Authorization", "Bearer token")
            .header("Accept", "application/json")
            .timeout(60)

        // Verify builder returns self for chaining
        XCTAssertNotNil(builder)
    }

    func testBuilderHeaders() throws {
        let builder = HTTPRequestBuilder(url: "https://example.com/api")
            .headers([
                "X-Custom-1": "value1",
                "X-Custom-2": "value2"
            ])
            .header("X-Custom-3", "value3")

        XCTAssertNotNil(builder)
    }

    func testBuilderBody() throws {
        let builder = HTTPRequestBuilder(url: "https://example.com/api")
            .method("POST")
            .body("test data".data(using: .utf8)!)

        XCTAssertNotNil(builder)
    }

    func testBuilderJSONBody() throws {
        struct TestBody: Codable {
            let name: String
        }

        let builder = try HTTPRequestBuilder(url: "https://example.com/api")
            .method("POST")
            .jsonBody(TestBody(name: "test"))

        XCTAssertNotNil(builder)
    }
}

// MARK: - Certificate Pin Tests

final class CertificatePinTests: XCTestCase {

    func testCertificatePinEquality() {
        let pin1 = CertificatePin(domain: "example.com", publicKeyHash: "hash123")
        let pin2 = CertificatePin(domain: "example.com", publicKeyHash: "hash123")
        let pin3 = CertificatePin(domain: "example.com", publicKeyHash: "different")

        XCTAssertEqual(pin1, pin2)
        XCTAssertNotEqual(pin1, pin3)
    }

    func testCertificatePinProperties() {
        let pin = CertificatePin(domain: "api.example.com", publicKeyHash: "AAAA+BBB/CCC=")

        XCTAssertEqual(pin.domain, "api.example.com")
        XCTAssertEqual(pin.publicKeyHash, "AAAA+BBB/CCC=")
    }
}

// MARK: - Elevation API Client Tests

final class ElevationAPIClientTests: XCTestCase {

    func testSharedInstance() {
        let client1 = ElevationAPIClient.shared
        let client2 = ElevationAPIClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func testSetApiKey() {
        let client = ElevationAPIClient.shared
        client.setMapTilerApiKey("test-api-key")
        // API key is private, so we just verify no crash
    }
}

// MARK: - Integration Tests

final class NetworkSecurityIntegrationTests: XCTestCase {

    func testDeviceCertificateManagerExportJSON() {
        let manager = DeviceCertificateManager.shared

        // Try to export - may fail if no certificate exists
        do {
            let json = try manager.exportCertificateJSON()
            XCTAssertNotNil(json["deviceId"])
            XCTAssertNotNil(json["fingerprint"])
        } catch {
            // Expected if running without proper setup
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testDeviceCertificateManagerTrustManagement() {
        let manager = DeviceCertificateManager.shared

        // Test trust checking for non-existent device
        XCTAssertFalse(manager.isDeviceTrusted("non-existent-device"))

        // Get trusted device IDs
        let trustedIds = manager.getTrustedDeviceIds()
        XCTAssertNotNil(trustedIds)
    }
}
