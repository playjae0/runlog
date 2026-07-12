import SwiftUI

enum MapProvider: String, CaseIterable, Identifiable {
    case apple
    case google

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .apple:
            return "Apple Map"
        case .google:
            return "Google Map"
        }
    }
}

struct MapProviderPicker: View {
    @Binding var selection: MapProvider

    var body: some View {
        Picker("지도 제공자", selection: $selection) {
            ForEach(MapProvider.allCases) { provider in
                Text(provider.title)
                    .tag(provider)
            }
        }
        .pickerStyle(.segmented)
    }
}
