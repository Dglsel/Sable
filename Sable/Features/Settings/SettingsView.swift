import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var appSettings: [AppSettings]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SableSpacing.xLarge) {
                if let settings = appSettings.first {
                    GeneralSettingsSection(settings: settings)
                    ModelsSettingsSection()
                    DataSettingsSection()
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(SableSpacing.xLarge)
        }
        .frame(minWidth: 480, minHeight: 480)
        .background(SableTheme.chatBackground)
    }
}
