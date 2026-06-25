import SwiftUI

struct SettingsView: View {
    @Environment(LumenModel.self) private var model
    @State private var refreshing = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Tune the mix — how much each pillar counts toward your Life Score. The score always normalizes to 100%.")
                        .font(.subheadline).foregroundStyle(Palette.textSecondary)

                    // Weight sliders
                    VStack(spacing: 16) {
                        ForEach(PILLARS) { p in
                            VStack(spacing: 6) {
                                HStack {
                                    Circle().fill(p.color).frame(width: 9, height: 9)
                                    Text(p.name).font(.subheadline).foregroundStyle(Palette.textPrimary)
                                    Spacer()
                                    Text("\(Int(model.weights[p.key] ?? 0))%")
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.textSecondary)
                                        .monospacedDigit()
                                }
                                Slider(
                                    value: Binding(
                                        get: { model.weights[p.key] ?? 0 },
                                        set: { model.setWeight(p.key, $0.rounded()) }
                                    ),
                                    in: 0...40, step: 1
                                )
                                .tint(p.color)
                            }
                        }
                    }
                    .padding(16)
                    .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))

                    HStack {
                        Text("Total \(model.weightTotal)%")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(model.weightTotal == 100 ? Palette.bandStrong : Palette.bandOnTrack)
                        Spacer()
                        Button("Normalize") { model.normalizeWeights() }
                            .font(.footnote).buttonStyle(.bordered).tint(Palette.accent)
                        Button("Reset") { model.resetWeights() }
                            .font(.footnote).buttonStyle(.bordered).tint(Palette.textMuted)
                    }

                    Divider().overlay(Palette.border)

                    // Data
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DATA").font(.caption2).tracking(1.5).foregroundStyle(Palette.textMuted)
                        InfoRow(label: "Days from Health", value: "\(model.days.count)")
                        if let first = model.days.first {
                            InfoRow(label: "Earliest", value: first.date.formatted(date: .abbreviated, time: .omitted))
                        }
                        Button {
                            Task { refreshing = true; await model.reload(); refreshing = false }
                        } label: {
                            HStack {
                                if refreshing { ProgressView().tint(Palette.accent) }
                                Image(systemName: "arrow.clockwise")
                                Text("Re-read Apple Health")
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.accent)
                        .disabled(refreshing)

                        Text("Screen Time isn't available through HealthKit, so the Focus pillar stays manual for now — it's simply excluded from your score until added.")
                            .font(.caption).foregroundStyle(Palette.textMuted)
                    }
                }
                .padding()
            }
            .background(Palette.bgApp)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Palette.textMuted)
            Spacer()
            Text(value).foregroundStyle(Palette.textPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }
}
