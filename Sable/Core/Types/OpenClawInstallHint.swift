import Foundation

enum OpenClawInstallHint {

    // MARK: - Primary: Installer Script (for fresh installs)

    static let installerCommand = "curl -fsSL https://openclaw.ai/install.sh | bash"
    static let installerDescription = "Recommended installer handles Node detection, installation, and onboarding."

    // MARK: - Onboarding (quickstart, skips channel selection)

    static let onboardCommand = "openclaw onboard --flow quickstart"

    // MARK: - Advanced: Manual install steps

    static let npmInstallCommand = "npm install -g openclaw@latest"

    // MARK: - URLs

    static let docsURL = URL(string: "https://github.com/openclaw/openclaw#installation")!
    static let minNodeVersion = "22"
    static let defaultGatewayPort: UInt16 = 18789

    // MARK: - Command for current status

    /// Returns the single recommended command for the current status.
    static func primaryCommand(for status: OpenClawStatus) -> String {
        switch status {
        case .notInstalled:
            installerCommand
        case .needsOnboarding:
            onboardCommand
        case .installedStopped, .running, .error:
            ""
        }
    }
}
