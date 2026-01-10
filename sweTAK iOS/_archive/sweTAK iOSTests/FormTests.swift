import XCTest
@testable import sweTAK

final class FormTests: XCTestCase {

    // MARK: - FormType Tests

    func testFormTypeRawValues() {
        XCTAssertEqual(FormType.sevenS.rawValue, "7S")
        XCTAssertEqual(FormType.indirectFire.rawValue, "IFS")
    }

    func testFormTypeDisplayNames() {
        XCTAssertEqual(FormType.sevenS.displayName, "7S Observation Report")
        XCTAssertEqual(FormType.indirectFire.displayName, "Indirect Fire Support Request")
    }

    func testFormTypeSFSymbols() {
        XCTAssertEqual(FormType.sevenS.sfSymbol, "doc.fill")
        XCTAssertEqual(FormType.indirectFire.sfSymbol, "scope")
    }

    // MARK: - SevenSFormData Tests

    func testSevenSFormDataCreation() {
        let formData = SevenSFormData(
            dateTime: "301430",
            place: "59.330000, 18.060000",
            forceSize: "~10",
            type: "Infantry",
            occupation: "Moving east",
            symbols: "Woodland camo",
            reporter: "Alpha-1",
            latitude: 59.33,
            longitude: 18.06
        )

        XCTAssertEqual(formData.dateTime, "301430")
        XCTAssertEqual(formData.place, "59.330000, 18.060000")
        XCTAssertEqual(formData.forceSize, "~10")
        XCTAssertEqual(formData.type, "Infantry")
        XCTAssertEqual(formData.occupation, "Moving east")
        XCTAssertEqual(formData.symbols, "Woodland camo")
        XCTAssertEqual(formData.reporter, "Alpha-1")
        XCTAssertEqual(formData.latitude, 59.33)
        XCTAssertEqual(formData.longitude, 18.06)
    }

    func testSevenSFormDataDefaultValues() {
        let formData = SevenSFormData()

        XCTAssertEqual(formData.dateTime, "")
        XCTAssertEqual(formData.place, "")
        XCTAssertEqual(formData.forceSize, "")
        XCTAssertEqual(formData.type, "")
        XCTAssertEqual(formData.occupation, "")
        XCTAssertEqual(formData.symbols, "")
        XCTAssertEqual(formData.reporter, "")
        XCTAssertNil(formData.latitude)
        XCTAssertNil(formData.longitude)
    }

    func testSevenSFormDataJSONSerialization() {
        let original = SevenSFormData(
            dateTime: "301430",
            place: "59.330000, 18.060000",
            forceSize: "~10",
            type: "Infantry",
            occupation: "Moving east",
            symbols: "Woodland camo",
            reporter: "Alpha-1"
        )

        let json = original.toJSONString()
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")

        let parsed = SevenSFormData.fromJSONString(json)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.dateTime, original.dateTime)
        XCTAssertEqual(parsed?.place, original.place)
        XCTAssertEqual(parsed?.reporter, original.reporter)
    }

    func testSevenSFormDataCreateDraft() {
        let draft = SevenSFormData.createDraft(
            reporter: "Bravo-2",
            latitude: 59.35,
            longitude: 18.10,
            placeText: nil
        )

        XCTAssertEqual(draft.reporter, "Bravo-2")
        XCTAssertEqual(draft.latitude, 59.35)
        XCTAssertEqual(draft.longitude, 18.10)
        XCTAssertFalse(draft.dateTime.isEmpty) // Should have current date/time
        XCTAssertTrue(draft.place.contains("59.35")) // Should have formatted coordinates
    }

    func testSevenSFormDataCreateDraftWithPlaceText() {
        let draft = SevenSFormData.createDraft(
            reporter: "Charlie-3",
            latitude: 59.35,
            longitude: 18.10,
            placeText: "33U VQ 12345 67890"
        )

        XCTAssertEqual(draft.place, "33U VQ 12345 67890")
    }

    // MARK: - IFSRequestType Tests

    func testIFSRequestTypeRawValues() {
        XCTAssertEqual(IFSRequestType.fight.rawValue, "Fight")
        XCTAssertEqual(IFSRequestType.keepDown.rawValue, "Keep down")
        XCTAssertEqual(IFSRequestType.block.rawValue, "Block")
        XCTAssertEqual(IFSRequestType.smoke.rawValue, "Smoke")
        XCTAssertEqual(IFSRequestType.illuminate.rawValue, "Illuminate")
    }

    func testIFSRequestTypeDisplayNames() {
        XCTAssertEqual(IFSRequestType.fight.displayName, "Fight")
        XCTAssertEqual(IFSRequestType.keepDown.displayName, "Keep down")
        XCTAssertEqual(IFSRequestType.block.displayName, "Block")
        XCTAssertEqual(IFSRequestType.smoke.displayName, "Smoke")
        XCTAssertEqual(IFSRequestType.illuminate.displayName, "Illuminate")
    }

    // MARK: - IndirectFireFormData Tests

    func testIndirectFireFormDataCreation() {
        let formData = IndirectFireFormData(
            observer: "Alpha-1",
            requestType: .fight,
            targetDescription: "Enemy position",
            observerPosition: "59.330000, 18.060000",
            enemyForces: "Infantry squad",
            enemyActivity: "Digging in",
            targetTerrain: "Open field",
            widthMeters: 50,
            angleOfViewMils: 1600,
            distanceMeters: 800,
            targetLatitude: 59.34,
            targetLongitude: 18.07
        )

        XCTAssertEqual(formData.observer, "Alpha-1")
        XCTAssertEqual(formData.requestType, .fight)
        XCTAssertEqual(formData.targetDescription, "Enemy position")
        XCTAssertEqual(formData.widthMeters, 50)
        XCTAssertEqual(formData.angleOfViewMils, 1600)
        XCTAssertEqual(formData.distanceMeters, 800)
    }

    func testIndirectFireFormDataDefaultValues() {
        let formData = IndirectFireFormData()

        XCTAssertEqual(formData.observer, "")
        XCTAssertEqual(formData.requestType, .fight)
        XCTAssertEqual(formData.targetDescription, "")
        XCTAssertNil(formData.widthMeters)
        XCTAssertNil(formData.angleOfViewMils)
        XCTAssertNil(formData.distanceMeters)
    }

    func testIndirectFireFormDataJSONSerialization() {
        let original = IndirectFireFormData(
            observer: "Alpha-1",
            requestType: .smoke,
            targetDescription: "Road junction",
            observerPosition: "59.330000, 18.060000",
            enemyForces: "Unknown",
            enemyActivity: "Staging",
            targetTerrain: "Urban",
            widthMeters: 100,
            angleOfViewMils: 3200,
            distanceMeters: 500
        )

        let json = original.toJSONString()
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")

        let parsed = IndirectFireFormData.fromJSONString(json)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.observer, original.observer)
        XCTAssertEqual(parsed?.requestType, original.requestType)
        XCTAssertEqual(parsed?.widthMeters, original.widthMeters)
        XCTAssertEqual(parsed?.distanceMeters, original.distanceMeters)
    }

    func testIndirectFireFormDataCreateDraft() {
        let draft = IndirectFireFormData.createDraft(
            observer: "Delta-4",
            observerLatitude: 59.33,
            observerLongitude: 18.06,
            observerPositionText: nil,
            targetLatitude: 59.34,
            targetLongitude: 18.07
        )

        XCTAssertEqual(draft.observer, "Delta-4")
        XCTAssertEqual(draft.observerLatitude, 59.33)
        XCTAssertEqual(draft.observerLongitude, 18.06)
        XCTAssertEqual(draft.targetLatitude, 59.34)
        XCTAssertEqual(draft.targetLongitude, 18.07)
        XCTAssertNotNil(draft.distanceMeters) // Should be auto-calculated
        XCTAssertNotNil(draft.angleOfViewMils) // Should be auto-calculated
    }

    func testIndirectFireFormDataCreateDraftWithPositionText() {
        let draft = IndirectFireFormData.createDraft(
            observer: "Echo-5",
            observerLatitude: 59.33,
            observerLongitude: 18.06,
            observerPositionText: "33U VQ 11111 22222",
            targetLatitude: nil,
            targetLongitude: nil
        )

        XCTAssertEqual(draft.observerPosition, "33U VQ 11111 22222")
        XCTAssertNil(draft.distanceMeters) // No target, so no calculation
        XCTAssertNil(draft.angleOfViewMils)
    }

    // MARK: - LinkedForm Tests

    func testLinkedFormCreation() {
        let form = LinkedForm(
            id: 12345,
            opPinId: 1,
            opOriginDeviceId: "device-123",
            formType: FormType.sevenS.rawValue,
            formData: "{}",
            submittedAtMillis: 1234567890,
            authorCallsign: "Alpha-1",
            targetLat: 59.34,
            targetLon: 18.07,
            observerLat: 59.33,
            observerLon: 18.06
        )

        XCTAssertEqual(form.id, 12345)
        XCTAssertEqual(form.opPinId, 1)
        XCTAssertEqual(form.opOriginDeviceId, "device-123")
        XCTAssertEqual(form.formType, "7S")
        XCTAssertEqual(form.authorCallsign, "Alpha-1")
        XCTAssertEqual(form.targetLat, 59.34)
        XCTAssertEqual(form.targetLon, 18.07)
    }

    func testLinkedFormCodable() throws {
        let original = LinkedForm(
            opPinId: 1,
            opOriginDeviceId: "device-123",
            formType: FormType.indirectFire.rawValue,
            formData: IndirectFireFormData(
                observer: "Alpha-1",
                requestType: .fight
            ).toJSONString(),
            authorCallsign: "Alpha-1"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LinkedForm.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.opPinId, decoded.opPinId)
        XCTAssertEqual(original.formType, decoded.formType)
        XCTAssertEqual(original.authorCallsign, decoded.authorCallsign)
    }

    // MARK: - NatoType Form Tests

    func testNatoTypeFormTypes() {
        XCTAssertEqual(NatoType.form7S.rawValue, "FORM_7S")
        XCTAssertEqual(NatoType.formIFS.rawValue, "FORM_IFS")
        XCTAssertEqual(NatoType.form7S.label, "7S")
        XCTAssertEqual(NatoType.formIFS.label, "IFS")
    }

    func testNatoTypeParse7S() {
        XCTAssertEqual(NatoType.parse("FORM_7S"), .form7S)
        XCTAssertEqual(NatoType.parse("7S"), .form7S)
    }

    func testNatoTypeParseIFS() {
        XCTAssertEqual(NatoType.parse("FORM_IFS"), .formIFS)
        XCTAssertEqual(NatoType.parse("IFS"), .formIFS)
    }

    // MARK: - PinsViewModel Form Tests

    func testPinsViewModelSingleton() {
        let vm1 = PinsViewModel.shared
        let vm2 = PinsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testPinsViewModelLinkedFormsProperty() {
        let vm = PinsViewModel.shared
        // Just verify the property exists and doesn't crash
        _ = vm.linkedForms
    }

    func testPinsViewModelGetFormsForPin() {
        let vm = PinsViewModel.shared
        // Test that method exists and returns array
        let forms = vm.getFormsForPin(pinId: 999999, originDeviceId: "nonexistent")
        XCTAssertTrue(forms.isEmpty) // Should be empty for non-existent pin
    }
}
