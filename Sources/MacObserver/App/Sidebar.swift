import SwiftUI

struct Sidebar: View {
    @Binding var selection: Profile

    var body: some View {
        List(selection: $selection) {
            Section("Views") {
                ForEach(Profile.views) { profile in
                    Label(profile.rawValue, systemImage: profile.symbol)
                        .tag(profile)
                }
            }

            Section("System") {
                ForEach(Profile.system) { profile in
                    Label(profile.rawValue, systemImage: profile.symbol)
                        .tag(profile)
                }
            }
        }
        .navigationTitle("Mac Observer")
        .listStyle(.sidebar)
    }
}
