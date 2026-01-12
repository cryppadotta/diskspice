# 013: Create Breadcrumb Navigation Component

## Dependencies
- 003 (core data models - NavigationState)
- 005 (main window structure)

## Task
Build the breadcrumb navigation bar showing the current path with clickable segments, back button, and proper styling.

## Spec Reference
See SPEC.md > Navigation: "Breadcrumbs: Path bar showing current location"
See SPEC.md > Visual Design Goals: SF Pro typography, micro-interactions

## Implementation Details

### BreadcrumbBar.swift

```swift
import SwiftUI

struct BreadcrumbBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Back button
            NavigationButton(
                icon: "chevron.left",
                isEnabled: appState.navigationState.canGoBack
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = appState.navigationState.goBack()
                }
            }

            // Up button
            NavigationButton(
                icon: "chevron.up",
                isEnabled: canGoUp
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = appState.navigationState.goUp()
                }
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // Breadcrumbs
            BreadcrumbPath(
                breadcrumbs: appState.navigationState.breadcrumbs,
                onSelect: { url in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.navigationState.navigateTo(url)
                    }
                }
            )

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var canGoUp: Bool {
        appState.navigationState.currentPath.path != "/"
    }
}

// MARK: - Navigation Button

struct NavigationButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var backgroundColor: Color {
        if isPressed && isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        } else if isHovering && isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Breadcrumb Path

struct BreadcrumbPath: View {
    let breadcrumbs: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, url in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    BreadcrumbItem(
                        name: displayName(for: url),
                        isLast: index == breadcrumbs.count - 1
                    ) {
                        onSelect(url)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }
        return url.lastPathComponent
    }
}

// MARK: - Breadcrumb Item

struct BreadcrumbItem: View {
    let name: String
    let isLast: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isLast ? .semibold : .regular))
                .foregroundStyle(isLast ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovering ? Color(nsColor: .controlBackgroundColor) : .clear)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    state.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/Users/demo/Documents/Projects"))

    return BreadcrumbBar(appState: state)
        .frame(width: 600)
}
```

## Files to Create/Modify
- `DiskSpice/Views/Components/BreadcrumbBar.swift` - New file
- `DiskSpice/Views/ContentView.swift` - Replace NavigationBar placeholder

## Acceptance Criteria
- [ ] Back button navigates to previous location
- [ ] Back button disabled when no history
- [ ] Up button navigates to parent folder
- [ ] Up button disabled at root
- [ ] Breadcrumb shows full path as clickable segments
- [ ] Clicking a breadcrumb segment navigates there
- [ ] Current (last) segment is visually distinct (bold)
- [ ] Hover effects on buttons and breadcrumb items
- [ ] Horizontal scroll if path is very long
- [ ] Chevron separators between segments
- [ ] Smooth animations on navigation

## Completion Promise
`<promise>TICKET_013_COMPLETE</promise>`
