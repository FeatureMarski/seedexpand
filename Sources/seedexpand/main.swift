import Foundation
import SeedExpandCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func read(_ path: String) throws -> Data {
    let url = URL(fileURLWithPath: path)
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    if let size = attrs[.size] as? NSNumber, size.intValue > Library.maxLibraryBytes {
        throw LibraryError.invalid("Input exceeds 16 MiB")
    }
    return try Data(contentsOf: url)
}
func write(_ data: Data, to path: String) throws {
    guard !FileManager.default.fileExists(atPath: path) else {
        throw LibraryError.invalid("Output already exists; choose a new path")
    }
    // withoutOverwriting rejects an existence race instead of replacing user data.
    try data.write(to: URL(fileURLWithPath: path), options: .withoutOverwriting)
}
func main() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else { throw LibraryError.invalid("Use: seedexpand validate FILE | export-apple INPUT OUTPUT | import-apple INPUT OUTPUT | compose INPUT ID...") }
    switch command {
    case "validate" where args.count == 2:
        let library = try Library.decodeJSON(read(args[1]))
        print("Valid library: \(library.snippets.count) snippets")
    case "export-apple" where args.count == 3:
        let library = try Library.decodeJSON(read(args[1]))
        try write(library.exportApplePlist(), to: args[2])
        print("Exported \(library.snippets.count) snippets. Import this file through macOS Text Replacements.")
    case "import-apple" where args.count == 3:
        let library = try Library.importApplePlist(read(args[1]))
        try write(library.encodeJSON(), to: args[2])
        print("Imported \(library.snippets.count) snippets")
    case "compose" where args.count >= 3:
        let library = try Library.decodeJSON(read(args[1]))
        print(try library.compose(ids: Array(args.dropFirst(2))))
    default:
        throw LibraryError.invalid("Invalid command or arguments")
    }
}
do { try main() } catch {
    FileHandle.standardError.write(Data("seedexpand: \(error)\n".utf8)); exit(1)
}
