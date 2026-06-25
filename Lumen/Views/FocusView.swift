import SwiftUI
import DeviceActivity
import FamilyControls

struct FocusView: View {
    @Environment(LumenModel.self) private var model

    private var todayFilter: DeviceActivityFilter {
        let interval = Calendar.current.dateInterval(of: .day, for: Date())
            ?? DateInterval(start: Date(), duration: 86400)
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .all)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.screenAuthorized {
                        Text("Today's screen time, read live from Apple's Screen Time and folded into your Focus pillar.")
                            .font(.subheadline).foregroundStyle(Palette.textSecondary)

                        // Embedding the report runs the extension, which writes the
                        // total to the shared App Group.
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
                            model.ingestScreenTime()
                        } label: {
                            HStack { Image(systemName: "arrow.clockwise"); Text("Update Life Score") }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)

                        Text("The number comes from Apple's report extension, which only exposes total usage — Lumen never sees which apps you used.")
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
                // Give the embedded report a moment to compute, then ingest.
                try? await Task.sleep(for: .seconds(2))
                model.ingestScreenTime()
            }
        }
    }
}
