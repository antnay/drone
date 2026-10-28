//
//  EQLog.swift
//  drone
//
//  Dedicated, persistent logging for the EQ audio pipeline. Uses os.Logger so
//  entries land in the unified log (viewable in Console.app and `log show`).
//
//  Retrieve with, e.g.:
//    log show --last 10m --predicate 'subsystem == "com.drone.eq"' --info --debug
//  or in Console.app filter by subsystem: com.drone.eq
//
//  A rotating-ish text copy is also written to:
//    ~/Library/Application Support/drone/eq-pipeline.log
//  so the user can hand the file back directly.
//

import Foundation
import os

enum EQLog {
    static let subsystem = "com.drone.eq"

    /// Master switch for EQ diagnostic logging. Off by default so normal builds
    /// do no file I/O. Flip it on when diagnosing audio-path issues — either set
    /// `EQLog.enabled = true` (e.g. from the debugger) or set the
    /// `eqLoggingEnabled` UserDefaults key to true and relaunch. When off, the
    /// persistent `eq-pipeline.log` file is never written.
    static var enabled: Bool = UserDefaults.standard.bool(forKey: "eqLoggingEnabled")

    static let install = Logger(subsystem: subsystem, category: "install")
    static let tap = Logger(subsystem: subsystem, category: "tap")
    static let process = Logger(subsystem: subsystem, category: "process")
    static let controller = Logger(subsystem: subsystem, category: "controller")

    // MARK: - File mirror

    /// URL of the text log file, created lazily under Application Support.
    static let fileURL: URL? = {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("drone", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("eq-pipeline.log")
    }()

    private static let fileQueue = DispatchQueue(label: "com.drone.eq.filelog")
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static var didTruncate = false

    /// Appends a line to both the unified log (via the given logger) and the
    /// text file. `category` is only used to tag the file line.
    static func line(_ category: String, _ message: String) {
        guard enabled else { return }
        let stamped = "\(formatter.string(from: Date())) [\(category)] \(message)\n"
        fileQueue.async {
            guard let url = fileURL else { return }
            // Truncate once per launch so the file doesn't grow unbounded.
            if !didTruncate {
                didTruncate = true
                try? "".write(to: url, atomically: true, encoding: .utf8)
            }
            if let data = stamped.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    /// Decodes a four-char-code OSStatus to its printable form when possible.
    static func osStatusString(_ status: OSStatus) -> String {
        guard status != 0 else { return "noErr(0)" }
        // Many CoreAudio errors are four-char codes.
        let n = UInt32(bitPattern: status)
        let chars = [
            UInt8((n >> 24) & 0xFF),
            UInt8((n >> 16) & 0xFF),
            UInt8((n >> 8) & 0xFF),
            UInt8(n & 0xFF),
        ]
        if chars.allSatisfy({ $0 >= 32 && $0 < 127 }) {
            let fourCC = String(bytes: chars, encoding: .ascii) ?? ""
            return "'\(fourCC)'(\(status))"
        }
        return "\(status)"
    }
}
