import SwiftUI

// MARK: - Scan Status Modifier

struct ScanStatusModifier: ViewModifier {
    let status: ScanStatus
    var onRetry: (() -> Void)?

    @State private var shimmerOffset: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .saturation(saturation)
            .overlay {
                if case .scanning = status {
                    ShimmerOverlay(offset: shimmerOffset)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                shimmerOffset = 2
                            }
                        }
                }
            }
            .overlay(alignment: .topTrailing) {
                if case .error(let message) = status {
                    ErrorBadge(message: message, onRetry: onRetry)
                }
            }
    }

    private var opacity: Double {
        switch status {
        case .stale: return 0.7
        case .scanning: return 0.85
        case .current: return 1.0
        case .error: return 0.8
        }
    }

    private var saturation: Double {
        switch status {
        case .stale: return 0.6
        case .scanning: return 0.9
        case .current: return 1.0
        case .error: return 0.7
        }
    }
}

// MARK: - Shimmer Overlay

struct ShimmerOverlay: View {
    let offset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.15),
                    .white.opacity(0.25),
                    .white.opacity(0.15),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.5)
            .offset(x: geometry.size.width * offset)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Error Badge

struct ErrorBadge: View {
    let message: String
    var onRetry: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button {
            onRetry?()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .padding(4)
                .background {
                    if isHovering {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(formatErrorMessage(message))
        .disabled(onRetry == nil)
    }

    private func formatErrorMessage(_ message: String) -> String {
        if message.contains("Permission denied") || message.contains("Operation not permitted") {
            return "Permission denied. Click to retry after granting access."
        } else if message.contains("No such file") || message.contains("not found") {
            return "File or folder not found."
        } else {
            return "Error: \(message). Click to retry."
        }
    }
}

// MARK: - View Extension

extension View {
    func scanStatus(_ status: ScanStatus, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ScanStatusModifier(status: status, onRetry: onRetry))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue)
                .frame(width: 100, height: 60)
                .scanStatus(.current)
                .overlay { Text("Current").foregroundStyle(.white) }

            RoundedRectangle(cornerRadius: 8)
                .fill(.blue)
                .frame(width: 100, height: 60)
                .scanStatus(.stale)
                .overlay { Text("Stale").foregroundStyle(.white) }

            RoundedRectangle(cornerRadius: 8)
                .fill(.blue)
                .frame(width: 100, height: 60)
                .scanStatus(.scanning)
                .overlay { Text("Scanning").foregroundStyle(.white) }

            RoundedRectangle(cornerRadius: 8)
                .fill(.blue)
                .frame(width: 100, height: 60)
                .scanStatus(.error("Test error"))
                .overlay { Text("Error").foregroundStyle(.white) }
        }
    }
    .padding()
}
