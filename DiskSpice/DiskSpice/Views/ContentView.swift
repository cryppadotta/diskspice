import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var splitRatio: CGFloat = 0.55
    @State private var coordinator: ScanCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar
            DiskSummaryBar(appState: appState)

            // Scan progress bar (isolated observation to prevent view churn)
            ScanProgressWrapper(scanQueue: appState.scanQueue)

            // Navigation bar (breadcrumbs)
            BreadcrumbBar(appState: appState)

            // Main split view - file list on left, treemap on right
            SplitView(splitRatio: $splitRatio) {
                FileListView(
                    appState: appState,
                    nodes: appState.currentChildren
                )
            } right: {
                TreemapContainer(appState: appState)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .focusable()
        .onKeyPress(.escape) {
            appState.goBack()
            return .handled
        }
        .onKeyPress(.return) {
            appState.navigateToSelected()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectNextItem()
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectPreviousItem()
            return .handled
        }
        .onKeyPress(.delete) {
            appState.deleteSelectedNode()
            return .handled
        }
        .onAppear {
            setupCoordinator()
            loadMockData()
        }
    }

    private func setupCoordinator() {
        // Use RustScanner when binary is available, MockScanner for development
        let scanner = RustScanner()
        coordinator = ScanCoordinator(scanner: scanner, appState: appState)
        appState.coordinator = coordinator
    }

    private func startScan(at path: URL) {
        guard let coordinator = coordinator else { return }
        Task {
            await coordinator.startScan(at: path)
        }
    }

    private func loadMockData() {
        debugLog("loadMockData starting", category: "APP")

        // Discover real volumes
        let volumes = VolumeManager.discoverVolumes()
        appState.volumes = volumes

        debugLog("Found \(volumes.count) volumes", category: "APP")

        // Create root children from volumes for treemap display
        let volumeNodes = volumes.map { volume -> FileNode in
            var node = FileNode(
                path: volume.path,
                name: volume.name,
                size: volume.usedSize,
                isDirectory: true
            )
            node.itemCount = 0
            node.scanStatus = .stale
            return node
        }

        // At root level, show volumes as children
        appState.updateChildren(at: URL(fileURLWithPath: "/"), children: volumeNodes)

        // Auto-start scanning the main volume (usually the first/largest one)
        if let mainVolume = volumes.first {
            debugLog("Auto-starting scan of \(mainVolume.path.path)", category: "APP")
            // Queue the main volume for scanning with high priority
            appState.scanQueue.prioritize(path: mainVolume.path)
        }
    }

    private func selectNextItem() {
        debugLog("selectNextItem called", category: "KEY")
        let nodes = appState.sortedNodes(
            for: appState.navigationState.currentPath,
            nodes: appState.currentChildren
        )
        guard !nodes.isEmpty else {
            debugLog("selectNextItem: no nodes", category: "KEY")
            return
        }

        if let currentId = appState.selectedNode?.id,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentId }),
           currentIndex < nodes.count - 1 {
            appState.selectNode(nodes[currentIndex + 1])
        } else if appState.selectedNode == nil {
            appState.selectNode(nodes[0])
        }
    }

    private func selectPreviousItem() {
        let nodes = appState.sortedNodes(
            for: appState.navigationState.currentPath,
            nodes: appState.currentChildren
        )
        guard !nodes.isEmpty else { return }

        if let currentId = appState.selectedNode?.id,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentId }),
           currentIndex > 0 {
            appState.selectNode(nodes[currentIndex - 1])
        }
    }
}

#Preview {
    ContentView()
}
