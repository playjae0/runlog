import GoogleMaps
import SwiftUI

@main
struct RunHealthPrototypeApp: App {
    init() {
        GoogleMapsBootstrap.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum GoogleMapsBootstrap {
    private(set) static var isConfigured = false

    static func configureIfPossible() {
        guard !isConfigured else {
            return
        }

        guard let rawKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String else {
            return
        }

        let trimmedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedKey.hasPrefix("$(") else {
            return
        }

        GMSServices.provideAPIKey(trimmedKey)
        isConfigured = true
    }
}
