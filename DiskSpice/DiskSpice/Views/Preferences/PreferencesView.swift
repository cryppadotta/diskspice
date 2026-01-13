import SwiftUI

struct PreferencesView: View {
    @Bindable var appState: AppState
    @State private var showClearConfirm = false
    @State private var didClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Cache")
                    .font(.system(size: 13, weight: .semibold))

                Text("Clears the on-disk cache used to speed up startup. Current scan data remains until you rescan.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Clear Cache") {
                        showClearConfirm = true
                    }
                    .buttonStyle(.borderedProminent)

                    if didClear {
                        Text("Cache cleared.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .alert("Clear Cache?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                appState.clearCache()
                didClear = true
            }
        } message: {
            Text("This will remove all cached scan data from disk.")
        }
    }
}

#Preview {
    PreferencesView(appState: AppState())
}
