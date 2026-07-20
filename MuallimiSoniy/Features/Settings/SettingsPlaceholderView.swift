import SwiftUI

/// Placeholder for the Settings tab until the real settings UI lands.
struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Sozlamalar — tez orada",
                systemImage: "gearshape",
                description: Text("Bu boʻlim keyingi bosqichda tayyor boʻladi.")
            )
            .navigationTitle("Sozlamalar")
        }
    }
}
