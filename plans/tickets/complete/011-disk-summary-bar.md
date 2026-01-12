# 011: Create Disk Summary Bar Component

## Dependencies
- 005 (main window structure)

## Task
Build the polished disk summary bar showing total/used/free space with a visual progress bar, following the premium design goals.

## Spec Reference
See SPEC.md > Window Layout: "Disk summary bar: Top bar showing 'X of Y used (Z free)' with visual progress bar"
See SPEC.md > Visual Design Goals: shadows, gradients, depth, SF Pro typography

## Implementation Details

### DiskSummaryBar.swift

```swift
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
    }

    @State private var shimmerPhase: CGFloat = 0

    private func shimmerOffset(_ width: CGFloat) -> CGFloat {
        // This would be animated in the actual implementation
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

#Preview {
    let state = AppState()
    // Add mock data
    return DiskSummaryBar(appState: state)
        .frame(width: 800)
}
```

## Files to Create/Modify
- `DiskSpice/Views/Components/DiskSummaryBar.swift` - New file
- `DiskSpice/Views/ContentView.swift` - Replace placeholder with real component

## Acceptance Criteria
- [ ] Summary bar shows volume name (or "All Volumes")
- [ ] Shows "X of Y used" text
- [ ] Progress bar visualizes percentage used
- [ ] Progress bar color changes based on usage (green->orange->red)
- [ ] Free space badge shows available space
- [ ] Scanning indicator (spinner) shows when scanning
- [ ] Follows design goals: subtle shadows, gradients, SF Pro
- [ ] Looks polished and premium
- [ ] Project builds and displays correctly

## Completion Promise
`<promise>TICKET_011_COMPLETE</promise>`
