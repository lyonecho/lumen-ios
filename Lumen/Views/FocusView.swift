import SwiftUI
import DeviceActivity
import FamilyControls

struct FocusView: View {
    @Environment(LumenModel.self) private var model
    @State private var pickerPresented = false

    private var todayFilter: DeviceActivityFilter {
        let interval = Calendar.current.dateInterval(of: .day, for: Date())
            ?? DateInterval(start: Date(), duration: 86400)
        let s = model.focusSelection
        // Scope the live report to the SAME apps the score uses, so the exact
        // number shown matches what the Focus pillar is based on.
        if hasSelection {
            return DeviceActivityFilter(
                segment: .daily(during: interval), users: .all, devices: .all,
                applications: s.applicationTokens, categories: s.categoryTokens, webDomains: s.webDomainTokens)
        }
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .all)
    }

    private var hasSelection: Bool {
        let s = model.focusSelection
        return !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
    }

    var body: some View {
        @Bindable var model = model // local bindable for the picker's two-way selection
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.screenAuthorized {
                        Text("Today's screen time for the apps you choose, from Apple's Screen Time. The number below is exact; your Focus score updates in steps in the background.")
                            .font(.subheadline).foregroundStyle(Palette.textSecondary)

                        if let err = model.monitorError {
                            Banner(icon: "exclamationmark.triangle.fill", tint: Palette.bandAtRisk,
                                   title: "Background tracking", message: err)
                        }

                        // Apple renders the exact total inside this report view.
                        DeviceActivityReport(.totalActivity, filter: todayFilter)
                            .frame(height: 130)
                            .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))

                        if let f = model.currentScore?.pillars.first(where: { $0.def.key == .focus }) {
                            HStack {
                                Image(systemName: "iphone").foregroundStyle(Palette.focus)
                                Text("Focus pillar")
                                Spacer()
                                Text(f.hasData ? "\(f.score)" : "—")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(f.hasData ? Palette.focus : Palette.textFaint)
                                    .monospacedDigit()
                            }
                            .padding(14)
                            .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
                        }

                        Button {
                            pickerPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                Text(hasSelection ? "Edit tracked apps & categories" : "Choose apps & categories to track")
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
                        .foregroundStyle(Palette.textPrimary)
                        .familyActivityPicker(isPresented: $pickerPresented, selection: $model.focusSelection)
                        .onChange(of: pickerPresented) { _, presented in
                            // Persist + (re)arm the background monitor when the picker closes.
                            if !presented { model.updateFocusSelection(model.focusSelection) }
                        }

                        Button {
                            model.ingestScreenTime()
                        } label: {
                            HStack { Image(systemName: "arrow.clockwise"); Text("Update Life Score") }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)

                        Text("Background updates only track the apps and categories you pick, and arrive in steps (every 15–30 min of use) — so between checkpoints your score can read a little low, and iOS may delay an update until you next unlock. Open this tab for the exact figure. Lumen only ever sees a total, never which apps you used. Background tracking needs a real iPhone — not the Simulator.")
                            .font(.caption).foregroundStyle(Palette.textMuted)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "hourglass").font(.largeTitle).foregroundStyle(Palette.focus)
                            Text("Track Focus automatically").font(.headline).foregroundStyle(Palette.textPrimary)
                            Text("Grant Screen Time access and Lumen will read your daily total and score the Focus pillar — no manual entry.")
                                .font(.subheadline).foregroundStyle(Palette.textMuted)
                                .multilineTextAlignment(.center).padding(.horizontal, 20)
                            Button {
                                Task { await model.requestScreenTime() }
                            } label: {
                                Text("Connect Screen Time")
                                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity, minHeight: 360)
                    }
                }
                .padding()
            }
            .background(Palette.bgApp)
            .scrollContentBackground(.hidden)
            .navigationTitle("Focus")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                // Re-arm the daily monitor (no-op until apps are selected), then
                // give the embedded report a moment to compute and ingest.
                model.startBackgroundMonitoring()
                try? await Task.sleep(for: .seconds(2))
                model.ingestScreenTime()
            }
        }
    }
}
