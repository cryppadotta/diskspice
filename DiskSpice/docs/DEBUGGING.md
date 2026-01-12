# DiskSpice Debug Logging Guide

## Log File Location

Debug logs are written to:
```
~/Library/Logs/DiskSpice/debug.log
```

## Viewing Logs in Real-Time

Open a terminal and run:
```bash
tail -f ~/Library/Logs/DiskSpice/debug.log
```

This will show log entries as they appear in real-time while the app runs.

## Log Format

Each log entry follows this format:
```
[HH:mm:ss.SSS] [CATEGORY] [FileName:Line] Message
```

Example:
```
[14:32:15.123] [APP] [ContentView:69] loadMockData called
[14:32:15.125] [VOLUME] [VolumeManager:17] discoverVolumes called
[14:32:15.130] [TREEMAP] [TreemapContainer:75] TreemapContainer initialized
```

## Log Categories

| Category | Description |
|----------|-------------|
| `SYSTEM` | Logger startup/shutdown messages |
| `APP` | Application-level events (startup, data loading) |
| `VOLUME` | Volume discovery and management |
| `TREEMAP` | TreemapContainer and TreemapView state |
| `LAYOUT` | TreemapLayout algorithm execution |
| `DRAW` | Canvas drawing operations |
| `ERROR` | Error conditions |
| `DEBUG` | General debug messages |

## Debugging the Treemap

The treemap rendering pipeline has logging at each stage:

### 1. Data Loading (`APP` category)
```
loadMockData called
Discovered volumes: count=1, volumes=[...]
Created volume nodes: count=1, nodes=[...]
Updated appState children at root
```

**What to check:**
- Are volumes being discovered?
- Are volume nodes being created with non-zero sizes?
- Is appState.currentChildren populated?

### 2. Container Initialization (`TREEMAP` category)
```
TreemapContainer onAppear: geometrySize=600 x 400
TreemapContainer initialized: currentPath=/, childCount=1
```

**What to check:**
- Is the geometry size valid (non-zero)?
- Does childCount match expected volumes?

### 3. Layout Calculation (`LAYOUT` category)
```
TreemapLayout.layout called: nodeCount=1, bounds=(0, 0, 600 x 400)
TreemapLayout.layout result: rectCount=1, rects=[...]
```

**What to check:**
- Are nodes being passed to layout?
- Are rects being generated with valid frames?
- Are bounds non-zero?

### 4. View Layout (`TREEMAP` category)
```
TreemapView.recalculateLayout called: size=600 x 400, nodeCount=1
TreemapView.recalculateLayout complete: rectCount=1
```

**What to check:**
- Is recalculateLayout being called?
- Is nodeCount > 0?
- Is rectCount > 0?

### 5. Drawing (`DRAW` category)
```
drawTreemap called: canvasSize=600 x 400, rectCount=1
Drawing rect: name=Macintosh HD, frame=(1, 1, 598 x 398), fileType=other
```

**What to check:**
- Is drawTreemap being called?
- Are rects present when drawing?
- Are rect frames valid (positive width/height)?
- Is the fileType being set correctly?

## Common Issues

### Treemap is Empty/Black

1. **Check if nodes reach TreemapContainer:**
   Look for `TreemapContainer initialized: childCount=X`
   - If childCount is 0, the issue is in data loading

2. **Check if layout generates rects:**
   Look for `TreemapLayout.layout result: rectCount=X`
   - If rectCount is 0, nodes may have size=0 or bounds are invalid

3. **Check if drawing is happening:**
   Look for `drawTreemap called: rectCount=X`
   - If rectCount is 0, layout didn't produce rects
   - If not called at all, Canvas isn't being rendered

4. **Check rect frames:**
   Look for `Drawing rect: frame=(X, Y, W x H)`
   - If width or height is 0 or negative, layout calculation failed

### Color Issues

The `Drawing rect` log shows `fileType=X`. Check if:
- Volume/folder nodes have `fileType=other` (gray color)
- The color for that fileType is visible against the background

## Disabling Logging

To disable logging in production, set in `DebugLogger.swift`:
```swift
var isEnabled = false
```

## Clearing the Log

The log file is automatically cleared each time the app starts. To manually clear:
```bash
> ~/Library/Logs/DiskSpice/debug.log
```

## Adding More Logging

Use the global functions:
```swift
// Simple message
debugLog("Something happened", category: "MYCATEGORY")

// With data
debugLog("State changed", data: [
    "value1": someValue,
    "value2": anotherValue
], category: "MYCATEGORY")

// Errors
debugError("Something failed", error: theError)
```
