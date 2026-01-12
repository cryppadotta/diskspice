# 016: Implement Squarified Treemap Algorithm

## Dependencies
- 003 (core data models)

## Task
Implement the squarified treemap layout algorithm that produces visually pleasing rectangles with aspect ratios close to 1.

## Spec Reference
See SPEC.md > UI - Treemap Visualization: "Squarified treemap algorithm (prefers square-ish rectangles)"

## Implementation Details

### TreemapLayout.swift

```swift
import Foundation
import CoreGraphics

struct TreemapRect: Identifiable {
    let id: UUID
    let node: FileNode
    var frame: CGRect
}

struct TreemapLayout {
    /// Generate treemap layout for given nodes within bounds
    static func layout(nodes: [FileNode], in bounds: CGRect) -> [TreemapRect] {
        guard !nodes.isEmpty else { return [] }

        // Filter out zero-size nodes and sort by size descending
        let validNodes = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !validNodes.isEmpty else { return [] }

        let totalSize = validNodes.reduce(0) { $0 + $1.size }

        return squarify(
            nodes: validNodes,
            totalSize: totalSize,
            bounds: bounds
        )
    }

    // MARK: - Squarified Algorithm

    private static func squarify(
        nodes: [FileNode],
        totalSize: Int64,
        bounds: CGRect
    ) -> [TreemapRect] {
        var results: [TreemapRect] = []
        var remaining = nodes
        var currentBounds = bounds

        while !remaining.isEmpty {
            // Determine layout direction based on aspect ratio
            let isHorizontal = currentBounds.width >= currentBounds.height

            // Find the best row of nodes
            let (row, rest) = findBestRow(
                nodes: remaining,
                totalSize: totalSize,
                bounds: currentBounds,
                isHorizontal: isHorizontal
            )

            // Layout the row
            let rowRects = layoutRow(
                row: row,
                totalSize: totalSize,
                bounds: currentBounds,
                isHorizontal: isHorizontal
            )

            results.append(contentsOf: rowRects)

            // Update bounds for remaining nodes
            if !rest.isEmpty {
                let rowSize = row.reduce(0) { $0 + $1.size }
                let rowRatio = Double(rowSize) / Double(totalSize)

                if isHorizontal {
                    let rowWidth = currentBounds.width * rowRatio
                    currentBounds = CGRect(
                        x: currentBounds.minX + rowWidth,
                        y: currentBounds.minY,
                        width: currentBounds.width - rowWidth,
                        height: currentBounds.height
                    )
                } else {
                    let rowHeight = currentBounds.height * rowRatio
                    currentBounds = CGRect(
                        x: currentBounds.minX,
                        y: currentBounds.minY + rowHeight,
                        width: currentBounds.width,
                        height: currentBounds.height - rowHeight
                    )
                }
            }

            remaining = rest
        }

        return results
    }

    private static func findBestRow(
        nodes: [FileNode],
        totalSize: Int64,
        bounds: CGRect,
        isHorizontal: Bool
    ) -> (row: [FileNode], rest: [FileNode]) {
        guard !nodes.isEmpty else { return ([], []) }

        var bestRow: [FileNode] = []
        var bestWorst = Double.infinity

        for i in 1...nodes.count {
            let candidateRow = Array(nodes.prefix(i))
            let worstRatio = calculateWorstAspectRatio(
                row: candidateRow,
                totalSize: totalSize,
                bounds: bounds,
                isHorizontal: isHorizontal
            )

            if worstRatio <= bestWorst {
                bestWorst = worstRatio
                bestRow = candidateRow
            } else {
                // Adding more nodes makes it worse, stop
                break
            }
        }

        let rest = Array(nodes.dropFirst(bestRow.count))
        return (bestRow, rest)
    }

    private static func calculateWorstAspectRatio(
        row: [FileNode],
        totalSize: Int64,
        bounds: CGRect,
        isHorizontal: Bool
    ) -> Double {
        let rowSize = row.reduce(0) { $0 + $1.size }
        let rowRatio = Double(rowSize) / Double(totalSize)

        let shortSide = isHorizontal ? bounds.height : bounds.width
        let rowLength = isHorizontal ? bounds.width * rowRatio : bounds.height * rowRatio

        var worstRatio = 0.0

        for node in row {
            let nodeRatio = Double(node.size) / Double(rowSize)
            let nodeLength = shortSide * nodeRatio

            let aspectRatio: Double
            if isHorizontal {
                aspectRatio = max(rowLength / nodeLength, nodeLength / rowLength)
            } else {
                aspectRatio = max(nodeLength / rowLength, rowLength / nodeLength)
            }

            worstRatio = max(worstRatio, aspectRatio)
        }

        return worstRatio
    }

    private static func layoutRow(
        row: [FileNode],
        totalSize: Int64,
        bounds: CGRect,
        isHorizontal: Bool
    ) -> [TreemapRect] {
        let rowSize = row.reduce(0) { $0 + $1.size }
        let rowRatio = Double(rowSize) / Double(totalSize)

        var results: [TreemapRect] = []
        var offset: CGFloat = 0

        for node in row {
            let nodeRatio = Double(node.size) / Double(rowSize)

            let frame: CGRect
            if isHorizontal {
                let rowWidth = bounds.width * rowRatio
                let nodeHeight = bounds.height * nodeRatio
                frame = CGRect(
                    x: bounds.minX,
                    y: bounds.minY + offset,
                    width: rowWidth,
                    height: nodeHeight
                )
                offset += nodeHeight
            } else {
                let rowHeight = bounds.height * rowRatio
                let nodeWidth = bounds.width * nodeRatio
                frame = CGRect(
                    x: bounds.minX + offset,
                    y: bounds.minY,
                    width: nodeWidth,
                    height: rowHeight
                )
                offset += nodeWidth
            }

            results.append(TreemapRect(id: node.id, node: node, frame: frame))
        }

        return results
    }
}
```

### Unit tests (TreemapLayoutTests.swift)

```swift
import XCTest
@testable import DiskSpice

final class TreemapLayoutTests: XCTestCase {
    func testEmptyInput() {
        let results = TreemapLayout.layout(nodes: [], in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(results.isEmpty)
    }

    func testSingleNode() {
        let node = FileNode(path: URL(fileURLWithPath: "/test"), name: "test", size: 100, isDirectory: true)
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let results = TreemapLayout.layout(nodes: [node], in: bounds)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].frame, bounds)
    }

    func testMultipleNodes() {
        let nodes = [
            FileNode(path: URL(fileURLWithPath: "/a"), name: "a", size: 60, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/b"), name: "b", size: 30, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/c"), name: "c", size: 10, isDirectory: true),
        ]
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let results = TreemapLayout.layout(nodes: nodes, in: bounds)

        XCTAssertEqual(results.count, 3)

        // Total area should equal bounds area
        let totalArea = results.reduce(0.0) { $0 + $1.frame.width * $1.frame.height }
        XCTAssertEqual(totalArea, 10000, accuracy: 1)
    }

    func testAspectRatiosReasonable() {
        let nodes = (0..<10).map { i in
            FileNode(path: URL(fileURLWithPath: "/\(i)"), name: "\(i)", size: Int64.random(in: 100...1000), isDirectory: true)
        }
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let results = TreemapLayout.layout(nodes: nodes, in: bounds)

        for rect in results {
            let aspectRatio = max(rect.frame.width / rect.frame.height, rect.frame.height / rect.frame.width)
            // Squarified should keep aspect ratios reasonable (< 5:1)
            XCTAssertLessThan(aspectRatio, 5.0, "Aspect ratio too extreme: \(aspectRatio)")
        }
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapLayout.swift` - New file
- `DiskSpiceTests/TreemapLayoutTests.swift` - New test file

## Acceptance Criteria
- [ ] TreemapLayout.layout() takes nodes and bounds, returns TreemapRects
- [ ] Algorithm produces squarified layout (aspect ratios close to 1)
- [ ] Larger nodes get larger rectangles proportionally
- [ ] All rectangles fit within bounds with no overlap
- [ ] Total area of rectangles equals bounds area
- [ ] Empty input returns empty output
- [ ] Single node fills entire bounds
- [ ] Unit tests pass

## Completion Promise
`<promise>TICKET_016_COMPLETE</promise>`
