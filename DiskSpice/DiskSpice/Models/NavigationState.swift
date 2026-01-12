import Foundation

struct NavigationState {
    var currentPath: URL
    var history: [URL] = []
    var historyIndex: Int = -1

    mutating func navigateTo(_ path: URL) {
        // Truncate forward history if we navigated back then went somewhere new
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(currentPath)
        historyIndex = history.count - 1
        currentPath = path
    }

    mutating func goBack() -> URL? {
        guard historyIndex >= 0 else { return nil }
        let previousPath = history[historyIndex]
        historyIndex -= 1
        let temp = currentPath
        currentPath = previousPath
        return temp
    }

    mutating func goUp() -> URL? {
        let parent = currentPath.deletingLastPathComponent()
        guard parent != currentPath else { return nil }
        navigateTo(parent)
        return parent
    }

    var canGoBack: Bool {
        historyIndex >= 0
    }

    var breadcrumbs: [URL] {
        var crumbs: [URL] = []
        var path = currentPath
        while path.path != "/" {
            crumbs.insert(path, at: 0)
            path = path.deletingLastPathComponent()
        }
        crumbs.insert(URL(fileURLWithPath: "/"), at: 0)
        return crumbs
    }
}
