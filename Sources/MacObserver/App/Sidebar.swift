import SwiftUI

struct Sidebar: View {
    @Binding var selection: Profile
    var monitoringSince: Date = Date()

    var body: some View {
        AppSidebar(selection: $selection, monitoringSince: monitoringSince)
    }
}
