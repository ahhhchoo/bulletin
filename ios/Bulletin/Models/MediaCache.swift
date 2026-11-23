import Foundation
import CryptoKit
import FirebaseStorage

/// Fetches pictures from Firebase Storage and keeps them on the phone. A picture's file name is a fingerprint of its
/// contents, so a file never changes: once it has been downloaded it is never downloaded again, and that is what keeps
/// the download bill small.
///
/// (It fetches through Storage's rules rather than a shareable link, so only people allowed to see a picture can get it.)
actor MediaCache {
    static let shared = MediaCache()

    private let memory: NSCache<NSString, NSData> = {
        let c = NSCache<NSString, NSData>()
        c.totalCostLimit = 40 * 1024 * 1024
        return c
    }()
    private let directory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    /// Downloads in progress, so two tiles asking for the same file share one download.
    private var inFlight: [String: Task<Data, Error>] = [:]

    /// Biggest file we will ask for: the full picture is at most a few MB.
    private static let maxBytes: Int64 = 8 * 1024 * 1024

    func data(path: String) async throws -> Data {
        let key = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        if let hit = memory.object(forKey: key as NSString) { return hit as Data }
        let file = directory.appendingPathComponent(key)
        if let onDisk = try? Data(contentsOf: file) {
            memory.setObject(onDisk as NSData, forKey: key as NSString, cost: onDisk.count)
            return onDisk
        }
        if let running = inFlight[key] { return try await running.value }

        let task = Task { try await Storage.storage().reference(withPath: path).data(maxSize: Self.maxBytes) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let data = try await task.value
        memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        try? data.write(to: file, options: .atomic)
        return data
    }
}
