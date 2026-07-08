import SwiftUI

/// Chooses iPad split view or iPhone tab layout based on horizontal size class.
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let navigation: NavigationCoordinator

    @State private var showDisclaimer = false

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView(navigation: navigation)
            } else {
                RootView(navigation: navigation)
            }
        }
        // F4: one-time currency disclaimer. It is a notice, not a contract —
        // Continue only, and it never blocks access to logbook data.
        .onAppear { showDisclaimer = !UserPreferences.shared.hasAcknowledgedCurrencyDisclaimer }
        .sheet(isPresented: $showDisclaimer) {
            CurrencyDisclaimerView {
                UserPreferences.shared.hasAcknowledgedCurrencyDisclaimer = true
                showDisclaimer = false
            }
            .interactiveDismissDisabled()
        }
    }
}

/// F4 first-launch acknowledgment. Placeholder wording — replace with the exact
/// audit F4 text when available (noted in DECISIONS.md).
struct CurrencyDisclaimerView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Currency is an aid, not authority", systemImage: "exclamationmark.shield")
                        .font(.title2.weight(.bold))
                    Text("AeroLog Ultimate calculates currency and recency from the flights, endorsements, and dates you enter. These calculations are a planning aid only.")
                    Text("As pilot in command you are solely responsible for determining your currency, recency, medical eligibility, and privileges under the applicable Federal Aviation Regulations. Verify all requirements against the FARs and your certificates before acting as PIC or carrying passengers.")
                    Text("Imported data is only as accurate as its source. Fields such as full-stop landings, holds, and approaches must be present for night, instrument, and class currency to compute correctly.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Before you begin")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: onAcknowledge) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}