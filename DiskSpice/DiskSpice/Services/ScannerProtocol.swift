import Foundation

protocol ScannerDelegate: AnyObject {
    func scanner(_ scanner: any Scanner, didUpdateNode node: FileNode, at path: URL)
    func scanner(_ scanner: any Scanner, didCompleteFolder path: URL)
    func scanner(_ scanner: any Scanner, didFailAt path: URL, error: Error)
    func scannerDidComplete(_ scanner: any Scanner)
}

protocol Scanner: AnyObject {
    var delegate: ScannerDelegate? { get set }
    var isScanning: Bool { get }

    func startScan(at path: URL) async
    func pauseScan()
    func resumeScan()
    func cancelScan()
    func refreshFolder(at path: URL) async
}
