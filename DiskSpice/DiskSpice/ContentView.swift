import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "internaldrive")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("DiskSpice")
                .font(.largeTitle)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
