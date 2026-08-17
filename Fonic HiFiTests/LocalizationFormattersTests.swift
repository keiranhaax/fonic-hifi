import XCTest
@testable import Fonic_HiFi

final class LocalizationFormattersTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let french = Locale(identifier: "fr_FR")

    func testCountPhrasesUseCatalogPluralRulesInEnglishAndFrench() throws {
        let englishBundle = try localizedBundle("en")
        let frenchBundle = try localizedBundle("fr")

        XCTAssertEqual(
            LocalizedFormatters.trackCount(1, locale: english, bundle: englishBundle),
            "1 track"
        )
        XCTAssertEqual(
            LocalizedFormatters.trackCount(2, locale: english, bundle: englishBundle),
            "2 tracks"
        )
        XCTAssertEqual(
            LocalizedFormatters.failedImportCount(1, locale: english, bundle: englishBundle),
            "1 file failed to import"
        )

        XCTAssertEqual(
            LocalizedFormatters.trackCount(1, locale: french, bundle: frenchBundle),
            "1 piste"
        )
        XCTAssertEqual(
            LocalizedFormatters.trackCount(2, locale: french, bundle: frenchBundle),
            "2 pistes"
        )
        XCTAssertEqual(
            LocalizedFormatters.failedImportCount(2, locale: french, bundle: frenchBundle),
            "Échec de l’importation de 2 fichiers"
        )
    }

    func testTechnicalValuesUseLocaleAwareNumbersAndUnits() throws {
        let englishBundle = try localizedBundle("en")
        let frenchBundle = try localizedBundle("fr")

        XCTAssertEqual(
            LocalizedFormatters.sampleRate(
                44_100,
                locale: english,
                bundle: englishBundle
            ),
            "44,100 Hz"
        )
        XCTAssertEqual(
            LocalizedFormatters.sampleRate(
                44_100,
                locale: french,
                bundle: frenchBundle
            ),
            "44 100 Hz"
        )
        XCTAssertEqual(
            LocalizedFormatters.gain(-1.5, locale: english, bundle: englishBundle),
            "-1.5 dB"
        )
        XCTAssertEqual(
            LocalizedFormatters.gain(-1.5, locale: french, bundle: frenchBundle),
            "-1,5 dB"
        )
    }

    func testAccessibilityValueKeepsLocalizedNumberAndUnitTogether() throws {
        let englishBundle = try localizedBundle("en")
        let frenchBundle = try localizedBundle("fr")

        XCTAssertEqual(
            LocalizedFormatters.gainAccessibilityValue(
                -1.5,
                locale: english,
                bundle: englishBundle
            ),
            "-1.5 decibels"
        )
        XCTAssertEqual(
            LocalizedFormatters.gainAccessibilityValue(
                -1.5,
                locale: french,
                bundle: frenchBundle
            ),
            "-1,5 décibels"
        )
    }

    func testMetadataCompositionPreservesValuesWithBidirectionalIsolation() throws {
        let frenchBundle = try localizedBundle("fr")

        XCTAssertEqual(
            LocalizedFormatters.artistAlbum(
                artist: "أم كلثوم",
                album: "Live in Paris",
                locale: french,
                bundle: frenchBundle
            ),
            "\u{2068}أم كلثوم\u{2069} — \u{2068}Live in Paris\u{2069}"
        )
        XCTAssertEqual(
            LocalizedFormatters.artistAlbum(
                artist: "Miles Davis",
                album: "",
                locale: french,
                bundle: frenchBundle
            ),
            "Miles Davis"
        )
    }

    private func localizedBundle(
        _ language: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Bundle {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: language,
                withExtension: "lproj"
            ),
            "Missing \(language) localization bundle",
            file: file,
            line: line
        )
        return try XCTUnwrap(
            Bundle(url: url),
            "Unable to load \(language) localization bundle",
            file: file,
            line: line
        )
    }
}
