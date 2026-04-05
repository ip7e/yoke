import Foundation
import Common

@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var availableVersion: String? = nil
    @Published var isHomebrew: Bool = false

    private let repo = "ip7e/yoke"
    private let stateURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/yoke/update-check.json")
    }()

    private init() {}

    // MARK: - Install method detection

    func detectInstallMethod() {
        let path = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? ""
        isHomebrew = path.hasPrefix("/opt/homebrew/") || path.hasPrefix("/usr/local/")
    }

    // MARK: - State persistence

    private struct State: Codable {
        var lastCheck: Date?
        var dismissedVersion: String?
    }

    private func loadState() -> State {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    private func saveState(_ state: State) {
        let dir = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL)
        }
    }

    // MARK: - GitHub Releases check

    func checkIfNeeded() {
        detectInstallMethod()

        let state = loadState()

        // Skip if checked within last 24h
        if let last = state.lastCheck, Date().timeIntervalSince(last) < 86400 {
            return
        }

        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return
            }

            let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let current = aeroSpaceAppVersion

            Task { @MainActor in
                guard let self = self else { return }
                let newState = State(lastCheck: Date(), dismissedVersion: state.dismissedVersion)
                self.saveState(newState)

                if remote != current && self.isNewer(remote: remote, current: current) {
                    self.availableVersion = remote
                }
            }
        }.resume()
    }

    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}
