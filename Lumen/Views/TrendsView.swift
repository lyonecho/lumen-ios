import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(LumenModel.self) private var model
    @State private var series: PillarKey? = nil // nil = composite Life Score

    private var color: Color { series.map { Palette.pillar($0) } ?? Palette.accent }

    private func valueFor(_ ds: DayScore) -> Int {
        if let k = series { return ds.pillars.first { $0.def.key == k }?.score ?? 0 }
        return ds.score
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if model.scores.isEmpty {
                    LoadingOrEmpty().frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(series == nil ? "Life Score" : (PILLARS.first { $0.key == series }?.name ?? ""))
                            .font(.headline).foregroundStyle(Palette.textPrimary)

                        Chart(model.scores) { ds in
                            AreaMark(x: .value("Day", ds.date), y: .value("Score", valueFor(ds)))
                                .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0.02)],
                                                                startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Day", ds.date), y: .value("Score", valueFor(ds)))
                                .foregroundStyle(color)
                                .interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) }
                        .frame(height: 220)

                        // Series picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Chip(label: "Life Score", color: Palette.accent, active: series == nil) { series = nil }
                                ForEach(PILLARS) { p in
                                    Chip(label: p.shortName, color: p.color, active: series == p.key) { series = p.key }
                                }
                            }
                        }

                        Text("History").font(.headline).foregroundStyle(Palette.textPrimary).padding(.top, 4)
                        ForEach(model.scores.reversed()) { ds in
                            HStack {
                                Text(ds.date, format: .dateTime.weekday(.abbreviated).month().day())
                                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                                if ds.flagged {
                                    Text("recovery").font(.caption2)
                                        .foregroundStyle(Palette.bandAtRisk)
                                }
                                Spacer()
                                Text("\(ds.score)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ds.band.color).monospacedDigit()
                            }
                            .padding(.vertical, 6)
                            Divider().overlay(Palette.border)
                        }
                    }
                    .padding()
                }
            }
            .background(Palette.bgApp)
            .scrollContentBackground(.hidden)
            .navigationTitle("Trends")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await model.reload() }
        }
    }
}

struct Chip: View {
    let label: String
    let color: Color
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(active ? Palette.bgRaised : Palette.bgInset, in: Capsule())
            .overlay(Capsule().stroke(active ? color : Palette.border, lineWidth: 1))
            .foregroundStyle(active ? Palette.textPrimary : Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
