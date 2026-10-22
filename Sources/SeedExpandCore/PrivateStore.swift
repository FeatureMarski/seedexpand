import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Versioned library storage. A failed read is never interpreted as an empty library.
public struct PrivateStore {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("library.json") }
    public init(directory: URL) { self.directory = directory }
    private func prepare() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            let attributes = try fm.attributesOfItem(atPath: directory.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                throw LibraryError.invalid("Storage directory must not be a symbolic link")
            }
        } else {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
        }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
    public func load() throws -> Library {
        try prepare()
        do { _ = try FileManager.default.attributesOfItem(atPath: file.path) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) {
            return Library(snippets: [])
        }
        return try Library.decodeJSON(Self.readBounded(file))
    }
    public static func readBounded(_ url: URL) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue <= Library.maxLibraryBytes else {
            throw LibraryError.invalid("Choose a regular file no larger than 16 MiB")
        }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw LibraryError.invalid("Cannot open regular file safely") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Library.maxLibraryBytes + 1) ?? Data()
        guard data.count <= Library.maxLibraryBytes else { throw LibraryError.invalid("File exceeds 16 MiB") }
        return data
    }
    /// Exclusive creation with mode 0600 before any text is written.
    public static func writeNew(_ data: Data, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw LibraryError.invalid("Cannot create a new private file; choose an unused filename") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
    private func atomicWrite(_ data: Data, to destination: URL) throws {
        let staging = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: staging) }
        try Self.writeNew(data, to: staging)
        guard rename(staging.path, destination.path) == 0 else {
            throw LibraryError.invalid("Atomic save failed; previous file retained")
        }
    }
    public func save(_ library: Library) throws {
        let data = try library.encodeJSON()
        try prepare()
        if FileManager.default.fileExists(atPath: file.path) {
            let old = try Self.readBounded(file)
            try atomicWrite(old, to: directory.appendingPathComponent("library.backup.json"))
        }
        try atomicWrite(data, to: file)
    }
}
