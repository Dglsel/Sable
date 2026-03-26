import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var interfaceLanguageRawValue: String
    var defaultReplyLanguageRawValue: String
    var appearanceModeRawValue: String
    var launchBehaviorRawValue: String

    init(
        id: UUID = UUID(),
        interfaceLanguage: InterfaceLanguage = .followSystem,
        defaultReplyLanguage: ReplyLanguage = .automatic,
        appearanceMode: AppearanceMode = .light,
        launchBehavior: LaunchBehavior = .reopenLastConversation
    ) {
        self.id = id
        self.interfaceLanguageRawValue = interfaceLanguage.rawValue
        self.defaultReplyLanguageRawValue = defaultReplyLanguage.rawValue
        self.appearanceModeRawValue = appearanceMode.rawValue
        self.launchBehaviorRawValue = launchBehavior.rawValue
    }

    var interfaceLanguage: InterfaceLanguage {
        get { InterfaceLanguage(rawValue: interfaceLanguageRawValue) ?? .followSystem }
        set { interfaceLanguageRawValue = newValue.rawValue }
    }

    var defaultReplyLanguage: ReplyLanguage {
        get { ReplyLanguage(rawValue: defaultReplyLanguageRawValue) ?? .automatic }
        set { defaultReplyLanguageRawValue = newValue.rawValue }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRawValue) ?? .light }
        set { appearanceModeRawValue = newValue.rawValue }
    }

    var launchBehavior: LaunchBehavior {
        get { LaunchBehavior(rawValue: launchBehaviorRawValue) ?? .reopenLastConversation }
        set { launchBehaviorRawValue = newValue.rawValue }
    }
}
