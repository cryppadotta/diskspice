# 012: Create Custom Split View Layout

## Dependencies
- 005 (main window structure)

## Task
Replace the basic HSplitView with a custom resizable split view that provides better control over appearance and behavior.

## Spec Reference
See SPEC.md > Window Layout: "Resizable split (drag divider)"
See SPEC.md > Visual Design Goals: fluid animations, polish

## Implementation Details

### SplitView.swift

```swift
import SwiftUI

struct SplitView<Left: View, Right: View>: View {
    let left: Left
    let right: Right

    @Binding var splitRatio: CGFloat
    let minLeftWidth: CGFloat
    let minRightWidth: CGFloat

    @State private var isDragging = false

    init(
        splitRatio: Binding<CGFloat>,
        minLeftWidth: CGFloat = 300,
        minRightWidth: CGFloat = 250,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self._splitRatio = splitRatio
        self.minLeftWidth = minLeftWidth
        self.minRightWidth = minRightWidth
        self.left = left()
        self.right = right()
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dividerWidth: CGFloat = 1
            let leftWidth = max(minLeftWidth, min(totalWidth - minRightWidth - dividerWidth, totalWidth * splitRatio))
            let rightWidth = totalWidth - leftWidth - dividerWidth

            HStack(spacing: 0) {
                // Left panel
                left
                    .frame(width: leftWidth)

                // Divider
                SplitDivider(isDragging: $isDragging)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newRatio = (leftWidth + value.translation.width) / totalWidth
                                let minRatio = minLeftWidth / totalWidth
                                let maxRatio = (totalWidth - minRightWidth - dividerWidth) / totalWidth
                                splitRatio = min(max(newRatio, minRatio), maxRatio)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )

                // Right panel
                right
                    .frame(width: rightWidth)
            }
        }
    }
}

// MARK: - Split Divider

struct SplitDivider: View {
    @Binding var isDragging: Bool
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: 1)
            .overlay {
                // Wider hit area for easier grabbing
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 9)
                    .contentShape(Rectangle())
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private var dividerColor: Color {
        if isDragging {
            return Color.accentColor.opacity(0.8)
        } else if isHovering {
            return Color(nsColor: .separatorColor).opacity(0.8)
        }
        return Color(nsColor: .separatorColor).opacity(0.5)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var ratio: CGFloat = 0.5

        var body: some View {
            SplitView(splitRatio: $ratio) {
                ZStack {
                    Color.blue.opacity(0.2)
                    Text("Left Panel")
                }
            } right: {
                ZStack {
                    Color.green.opacity(0.2)
                    Text("Right Panel")
                }
            }
            .frame(width: 800, height: 600)
        }
    }

    return PreviewWrapper()
}
```

### Update ContentView.swift

Replace HSplitView with custom SplitView:

```swift
struct ContentView: View {
    @State private var appState = AppState()
    @State private var splitRatio: CGFloat = 0.55

    var body: some View {
        VStack(spacing: 0) {
            DiskSummaryBar(appState: appState)
            NavigationBar(appState: appState)

            SplitView(splitRatio: $splitRatio) {
                TreemapPlaceholder()
            } right: {
                ListPlaceholder()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/Components/SplitView.swift` - New file
- `DiskSpice/Views/ContentView.swift` - Use custom SplitView

## Acceptance Criteria
- [ ] Split view shows two panels side by side
- [ ] Divider is draggable to resize panels
- [ ] Divider respects minimum widths for both panels
- [ ] Cursor changes to resize cursor on hover
- [ ] Divider highlights subtly on hover
- [ ] Divider highlights with accent color while dragging
- [ ] Smooth resizing without jank
- [ ] Split ratio persists correctly
- [ ] Project builds and runs correctly

## Completion Promise
`<promise>TICKET_012_COMPLETE</promise>`
