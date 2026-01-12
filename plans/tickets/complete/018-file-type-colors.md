# 018: Implement File Type Color Scheme

## Dependencies
- 003 (core data models - FileType enum)
- 017 (canvas treemap renderer)

## Task
Create a cohesive color palette for file types that works well in both light and dark mode, and implement dominant type calculation for folders.

## Spec Reference
See SPEC.md > UI - Treemap Visualization: color categories (Video=blue, Audio=purple, etc.)
See SPEC.md > "Folder color: Dominant file type by size within that folder"

## Implementation Details

### FileTypeColors.swift

```swift
import SwiftUI

struct FileTypeColors {
    /// Get the color for a file type
    static func color(for type: FileType, scheme: ColorScheme = .dark) -> Color {
        switch type {
        case .video:
            return Color(hue: 0.6, saturation: 0.7, brightness: scheme == .dark ? 0.8 : 0.6) // Blue
        case .audio:
            return Color(hue: 0.8, saturation: 0.6, brightness: scheme == .dark ? 0.75 : 0.55) // Purple
        case .image:
            return Color(hue: 0.35, saturation: 0.65, brightness: scheme == .dark ? 0.7 : 0.5) // Green
        case .code:
            return Color(hue: 0.08, saturation: 0.75, brightness: scheme == .dark ? 0.85 : 0.65) // Orange
        case .archive:
            return Color(hue: 0.07, saturation: 0.5, brightness: scheme == .dark ? 0.55 : 0.4) // Brown
        case .application:
            return Color(hue: 0.0, saturation: 0.65, brightness: scheme == .dark ? 0.75 : 0.55) // Red
        case .system:
            return Color(hue: 0.0, saturation: 0.0, brightness: scheme == .dark ? 0.45 : 0.35) // Gray
        case .cache:
            return Color(hue: 0.15, saturation: 0.7, brightness: scheme == .dark ? 0.85 : 0.65) // Yellow
        case .document:
            return Color(hue: 0.5, saturation: 0.5, brightness: scheme == .dark ? 0.65 : 0.45) // Teal
        case .other:
            return Color(hue: 0.0, saturation: 0.0, brightness: scheme == .dark ? 0.55 : 0.4) // Neutral gray
        }
    }

    /// Get a lighter variant for backgrounds
    static func backgroundColor(for type: FileType, scheme: ColorScheme = .dark) -> Color {
        color(for: type, scheme: scheme).opacity(0.3)
    }

    /// Get contrasting text color
    static func textColor(for type: FileType) -> Color {
        .white
    }

    /// Get all colors for legend display
    static var allColors: [(FileType, String)] {
        [
            (.video, "Video"),
            (.audio, "Audio"),
            (.image, "Images"),
            (.code, "Code"),
            (.archive, "Archives"),
            (.application, "Apps"),
            (.system, "System"),
            (.cache, "Cache"),
            (.document, "Documents"),
            (.other, "Other"),
        ]
    }
}

// MARK: - Dominant Type Calculation

extension FileNode {
    /// Calculate the dominant file type for a folder based on children's sizes
    func calculateDominantType() -> FileType {
        guard isDirectory, let children = children, !children.isEmpty else {
            return fileType
        }

        var typeSizes: [FileType: Int64] = [:]

        for child in children {
            let childType = child.isDirectory ? child.calculateDominantType() : child.fileType
            typeSizes[childType, default: 0] += child.size
        }

        // Find the type with the largest total size
        let dominant = typeSizes.max(by: { $0.value < $1.value })?.key ?? .other
        return dominant
    }

    /// Update this node and all children with calculated dominant types
    mutating func updateDominantTypes() {
        if isDirectory {
            // First update children
            if var kids = children {
                for i in kids.indices {
                    kids[i].updateDominantTypes()
                }
                children = kids
            }
            // Then calculate our dominant type
            fileType = calculateDominantType()
        }
    }
}

// MARK: - Color Legend View

struct ColorLegend: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(FileTypeColors.allColors, id: \.0) { type, name in
                HStack(spacing: 4) {
                    Circle()
                        .fill(FileTypeColors.color(for: type, scheme: colorScheme))
                        .frame(width: 10, height: 10)
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ColorLegend()
            .environment(\.colorScheme, .light)

        ColorLegend()
            .environment(\.colorScheme, .dark)
            .background(Color.black)
    }
    .padding()
}
```

### Update TreemapView to use FileTypeColors

```swift
// In TreemapView.swift, replace colorForFileType method:
@Environment(\.colorScheme) var colorScheme

private func colorForFileType(_ type: FileType) -> Color {
    FileTypeColors.color(for: type, scheme: colorScheme)
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/FileTypeColors.swift` - New file
- `DiskSpice/Models/FileNode.swift` - Add dominant type calculation
- `DiskSpice/Views/Treemap/TreemapView.swift` - Use FileTypeColors

## Acceptance Criteria
- [ ] All 10 file types have distinct, visually pleasing colors
- [ ] Colors work well in both light and dark mode
- [ ] Folders calculate dominant type from children by size
- [ ] calculateDominantType() correctly finds largest type
- [ ] updateDominantTypes() recursively updates tree
- [ ] ColorLegend view shows all types with their colors
- [ ] TreemapView uses FileTypeColors for consistent coloring

## Completion Promise
`<promise>TICKET_018_COMPLETE</promise>`
