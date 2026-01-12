import SwiftUI

struct DiskSummaryBar: View {
    let appState: AppState
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            // Volume icon
            Image(systemName: "internaldrive.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            // Usage info
            VStack(alignment: .leading, spacing: 4) {
                Text(volumeTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(usageText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if appState.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    }
                }
            }

            Spacer()

            // Usage bar
            UsageProgressBar(
                used: appState.totalUsedSpace,
                total: appState.totalSpace,
                isScanning: appState.isScanning
            )
            .frame(width: 200, height: 8)

            // Free space badge
            FreeSpaceBadge(freeSpace: appState.totalFreeSpace)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .windowBackgroundColor).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Bottom border
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
            }
        }
    }

    private var volumeTitle: String {
        if let volume = appState.currentVolume {
            return volume.name
        }
        return "All Volumes"
    }

    private var usageText: String {
        let used = formatBytes(appState.totalUsedSpace)
        let total = formatBytes(appState.totalSpace)
        return "\(used) of \(total) used"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Usage Progress Bar

struct UsageProgressBar: View {
    let used: Int64
    let total: Int64
    let isScanning: Bool

    @State private var shimmerPhase: CGFloat = 0

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return min(Double(used) / Double(total), 1.0)
    }

    private var fillColor: Color {
        if percentage > 0.9 {
            return .red
        } else if percentage > 0.75 {
            return .orange
        }
        return .accentColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [fillColor, fillColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * percentage)

                // Scanning shimmer overlay
                if isScanning {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white, .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset(geometry.size.width))
                        )
                }
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        .onAppear {
            if isScanning {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
        }
        .onChange(of: isScanning) { _, newValue in
            if newValue {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            } else {
                shimmerPhase = 0
            }
        }
    }

    private func shimmerOffset(_ width: CGFloat) -> CGFloat {
        return -width + (shimmerPhase * width * 2)
    }
}

// MARK: - Free Space Badge

struct FreeSpaceBadge: View {
    let freeSpace: Int64

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text("\(formatBytes(freeSpace)) free")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Scan Progress Bar

struct ScanProgressBar: View {
    let progress: ScanProgress

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Animated scanning icon
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)

            // Progress info
            VStack(alignment: .leading, spacing: 2) {
                // Current file being scanned (truncated)
                Text(truncatedPath(progress.currentPath))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Stats row
                HStack(spacing: 16) {
                    Label("\(progress.filesScanned) files", systemImage: "doc.fill")
                    Label(formatBytes(progress.bytesScanned), systemImage: "externaldrive.fill")
                    Label(String(format: "%.0f files/sec", progress.filesPerSecond), systemImage: "speedometer")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Elapsed time
            Text(formatTime(progress.elapsedTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.blue.opacity(0.03)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Moving highlight
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, Color.blue.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(x: animationPhase * geometry.size.width)
                }

                // Top border accent
                VStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(height: 2)
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
    }

    private func truncatedPath(_ path: String) -> String {
        // Show just the filename or last path component
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent

        if parent.isEmpty || parent == "/" {
            return filename
        }
        return "\(parent)/\(filename)"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Scan Progress Wrapper (Isolates observation)

struct ScanProgressWrapper: View {
    let scanQueue: ScanQueue

    var body: some View {
        if scanQueue.isScanning, let progress = scanQueue.progress {
            ScanProgressBar(progress: progress)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview("Disk Summary") {
    let state = AppState()
    return DiskSummaryBar(appState: state)
        .frame(width: 800)
}

#Preview("Scan Progress") {
    ScanProgressBar(progress: ScanProgress(
        currentPath: "/Users/john/Documents/very-long-filename.txt",
        filesScanned: 1234,
        bytesScanned: 1_234_567_890,
        startTime: Date().addingTimeInterval(-15)
    ))
    .frame(width: 800)
}
