import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit {
                    // Search is instant, no submit needed
                }
                .onExitCommand {
                    text = ""
                    isFocused = false
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    func focus() {
        isFocused = true
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SearchBar(text: .constant(""))
            .frame(width: 200)

        SearchBar(text: .constant("test query"))
            .frame(width: 200)
    }
    .padding()
}
