import Foundation
import XCTest

/// Loads the golden fixtures from tests/fixtures. The Xcode project copies them into the
/// test bundle. Nothing here edits or regenerates a fixture.
enum FixtureLoader {
    private final class BundleToken {}

    static func load(_ name: String) throws -> [String: Any] {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "FixtureLoader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).json not in test bundle"])
        }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FixtureLoader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).json is not an object"])
        }
        return object
    }
}
