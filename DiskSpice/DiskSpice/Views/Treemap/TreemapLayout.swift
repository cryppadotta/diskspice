import Foundation
import CoreGraphics

struct TreemapRect: Identifiable {
    let id: UUID
    let node: FileNode
    var frame: CGRect
    let isOtherGroup: Bool

    init(id: UUID, node: FileNode, frame: CGRect, isOtherGroup: Bool = false) {
        self.id = id
        self.node = node
        self.frame = frame
        self.isOtherGroup = isOtherGroup
    }
}

/// Represents grouped small items
struct OtherGroup {
    let items: [FileNode]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var itemCount: Int { items.count }

    func asFileNode() -> FileNode {
        var node = FileNode(
            path: URL(fileURLWithPath: "/__other__"),
            name: "Other (\(itemCount) items)",
            size: totalSize,
            isDirectory: false
        )
        node.fileType = .other
        node.itemCount = itemCount
        return node
    }
}

struct TreemapLayout {
    /// Minimum pixel size for a rectangle to be individually rendered
    static let minimumRectSize: CGFloat = 20

    /// Maximum number of items to show before grouping
    static let maxVisibleItems = 100

    /// Generate treemap layout for given nodes within bounds
    static func layout(nodes: [FileNode], in bounds: CGRect) -> [TreemapRect] {
        let (rects, _) = layoutWithGrouping(nodes: nodes, in: bounds)
        return rects
    }

    /// Generate treemap layout with small items grouped
    static func layoutWithGrouping(
        nodes: [FileNode],
        in bounds: CGRect
    ) -> (rects: [TreemapRect], otherGroup: OtherGroup?) {
        guard !nodes.isEmpty else { return ([], nil) }

        let validNodes = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !validNodes.isEmpty else { return ([], nil) }

        let totalSize = validNodes.reduce(0) { $0 + $1.size }
        let minAreaRatio = (minimumRectSize * minimumRectSize) / (bounds.width * bounds.height)
        let minSize = Int64(Double(totalSize) * Double(minAreaRatio))

        // Split into visible and grouped items
        var visibleNodes: [FileNode] = []
        var groupedNodes: [FileNode] = []

        for (index, node) in validNodes.enumerated() {
            // Group if: too small OR too many items
            if node.size < minSize || index >= maxVisibleItems {
                groupedNodes.append(node)
            } else {
                visibleNodes.append(node)
            }
        }

        // Create "Other" group if there are grouped items
        var nodesToLayout = visibleNodes
        var otherGroup: OtherGroup? = nil

        if !groupedNodes.isEmpty {
            otherGroup = OtherGroup(items: groupedNodes)
            nodesToLayout.append(otherGroup!.asFileNode())
        }

        // Layout all nodes including Other group
        let newTotalSize = nodesToLayout.reduce(0) { $0 + $1.size }
        var rects = squarify(nodes: nodesToLayout, totalSize: newTotalSize, bounds: bounds)

        // Mark the Other group rect
        if otherGroup != nil {
            for i in rects.indices {
                if rects[i].node.path.path == "/__other__" {
                    rects[i] = TreemapRect(
                        id: rects[i].id,
                        node: rects[i].node,
                        frame: rects[i].frame,
                        isOtherGroup: true
                    )
                }
            }
        }

        return (rects, otherGroup)
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
