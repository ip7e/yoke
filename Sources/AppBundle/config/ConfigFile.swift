import Common
import Foundation

let configDotfileName = ".aerospace.toml"
func findCustomConfigUrl() -> ConfigFile {
    // Yoke: skip config file discovery, always use the bundled default config
    return .noCustomConfigExists
}

enum ConfigFile {
    case file(URL), ambiguousConfigError(_ candidates: [URL]), noCustomConfigExists

    var urlOrNil: URL? {
        return switch self {
            case .file(let url): url
            case .ambiguousConfigError, .noCustomConfigExists: nil
        }
    }
}
