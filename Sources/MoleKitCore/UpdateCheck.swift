import Foundation

/// Looks up the newest Mole release the same way `mo` does (lib/manage/update.sh):
/// Homebrew installs ask formulae.brew.sh, other installs ask GitHub releases.
public enum MoleUpdate {
    public enum Channel: Sendable { case homebrew, script }

    public static func channel(of cli: MoleCLI) -> Channel {
        let real = cli.executable.resolvingSymlinksInPath().path
        return (real.contains("/Cellar/") || real.contains("/homebrew/")) ? .homebrew : .script
    }

    /// "Mole version 1.71.0" → "1.71.0"
    public static func installedVersion(_ cli: MoleCLI) async -> String? {
        guard let out = try? await cli.run(["--version"]) else { return nil }
        for line in out.stdout.split(separator: "\n") where line.lowercased().contains("version") {
            if let v = Rx.match(#"([0-9]+\.[0-9]+\.[0-9]+)"#, String(line))?[1] { return v }
        }
        return nil
    }

    public static func latestVersion(channel: Channel, session: URLSession = .shared) async -> String? {
        var request: URLRequest
        switch channel {
        case .homebrew:
            request = URLRequest(url: URL(string: "https://formulae.brew.sh/api/formula/mole.json")!)
        case .script:
            request = URLRequest(url: URL(string: "https://api.github.com/repos/tw93/mole/releases/latest")!)
        }
        request.timeoutInterval = 6
        request.setValue("Molekit", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let raw: String?
        switch channel {
        case .homebrew: raw = (json["versions"] as? [String: Any])?["stable"] as? String
        case .script: raw = json["tag_name"] as? String
        }
        guard let raw, let v = Rx.match(#"([0-9]+\.[0-9]+\.[0-9]+)"#, raw)?[1] else { return nil }
        return v
    }

    /// True when `latest` is newer than `installed` (numeric, dot by dot).
    public static func isNewer(_ latest: String, than installed: String) -> Bool {
        let a = latest.split(separator: ".").map { Int($0) ?? 0 }
        let b = installed.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
