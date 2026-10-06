import Foundation

enum Shell {
    /// Run a command and return its stdout.
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: d, as: UTF8.self)
    }

    /// Start a command and don't wait for it.
    @discardableResult
    static func spawn(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run(); return true } catch { return false }
    }

    /// (pid, lower-cased command line) of every process.
    static func processList() -> [(pid: Int32, cmd: String)] {
        var out: [(pid: Int32, cmd: String)] = []
        for line in run("/bin/ps", ["-axww", "-o", "pid=,command="]).split(separator: "\n") {
            let trimmed = line.drop(while: { $0 == " " })
            guard let sp = trimmed.firstIndex(of: " "), let pid = Int32(trimmed[..<sp]) else { continue }
            out.append((pid, trimmed[sp...].lowercased()))
        }
        return out
    }

    /// Force-kill every process whose command line contains one of `needles` (lower-case).
    @discardableResult
    static func killProcesses(containing needles: [String]) -> Int {
        var n = 0
        let me = ProcessInfo.processInfo.processIdentifier
        for (pid, cmd) in processList() where pid != me && needles.contains(where: { cmd.contains($0) }) {
            if kill(pid, SIGKILL) == 0 { n += 1 }
        }
        return n
    }

    /// Lower-cased command lines of every process.
    static func processes() -> [String] {
        run("/bin/ps", ["-axww", "-o", "command="]).lowercased()
            .split(separator: "\n").map(String.init)
    }
}

/// Tiny event log on the STEAM drive (readable when debugging launches).
enum Log {
    static func write(_ text: String) {
        let url = URL(fileURLWithPath: "/Volumes/STEAM/Hub/steamhub-app.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
