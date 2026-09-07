import SwiftUI

/// Placeholder home after onboarding until Dashboard ships.
/// Spec version: 1.0
struct HomeStubView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        MekasaScreen {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mekasa")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .padding(.top, 64)

                Text(welcomeLine)
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.brand)

                Text("Onboarding is complete. Dashboard, inventory, and shopping list screens come next.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)

                if let household = session.household {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow("Household", household.name ?? "Unnamed home")
                        infoRow("Address", household.address ?? "—")
                        infoRow("Stores", "\(household.storeIDs.count) selected")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                Spacer()

                SecondaryButton(title: "Sign out") {
                    try? AuthService.shared.signOut()
                    session.signOut()
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private var welcomeLine: String {
        if let name = session.displayName, !name.isEmpty {
            return "Welcome, \(name)."
        }
        if let email = session.email {
            return "Signed in as \(email)."
        }
        return "You're in."
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(MekasaTheme.labelFont)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
        }
    }
}

#Preview {
    HomeStubView().environmentObject(AppSession())
}
