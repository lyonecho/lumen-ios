import SwiftUI

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int
    let band: Band
    var body: some View {
        ZStack {
            Circle().stroke(Palette.bgInset, lineWidth: 16)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(band.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: band.color.opacity(0.45), radius: 14)
            VStack(spacing: 2) {
                Text("LIFE SCORE").font(.caption2).tracking(2).foregroundStyle(Palette.textMuted)
                Text("\(score)")
                    .font(.system(size: 76, weight: .light, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                Text(band.label.uppercased())
                    .font(.caption.bold()).tracking(1.5)
                    .foregroundStyle(band.color)
            }
        }
        .frame(width: 230, height: 230)
        .animation(.easeOut(duration: 0.8), value: score)
    }
}

// MARK: - Pillar card

struct PillarCardView: View {
    let result: PillarResult
    let weight: Double
    var body: some View {
        let c = result.def.color
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: Palette.pillarIcon(result.def.key))
                    .font(.system(size: 13)).foregroundStyle(c)
                Text(result.def.shortName).font(.caption.weight(.semibold)).foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("\(Int(weight))%").font(.caption2).foregroundStyle(Palette.textFaint).monospacedDigit()
            }
            Text(result.hasData ? "\(result.score)" : "—")
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(result.hasData ? c : Palette.textFaint)
                .monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.bgInset)
                    Capsule().fill(c)
                        .frame(width: geo.size.width * CGFloat(result.hasData ? result.score : 0) / 100)
                }
            }
            .frame(height: 6)
            Text(result.hasData ? "\(result.metrics.filter { !$0.gap }.count)/\(result.metrics.count) metrics" : "no data yet")
                .font(.caption2).foregroundStyle(Palette.textMuted)
        }
        .padding(14)
        .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                .fill(c).frame(height: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(LumenModel.self) private var model
    @State private var detail: PillarResult?

    private func value(_ ds: DayScore, _ key: String) -> Double? {
        for p in ds.pillars { for m in p.metrics where m.def.key == key { return m.actual } }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let ds = model.currentScore {
                    content(ds)
                        .padding()
                } else {
                    LoadingOrEmpty()
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .background(Palette.bgApp)
            .scrollContentBackground(.hidden)
            .navigationTitle("Today")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await model.reload() }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { step(-1) } label: { Image(systemName: "chevron.left") }
                        .disabled(model.selectedIndex <= 0)
                    Button { step(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(model.selectedIndex >= model.scores.count - 1)
                }
            }
        }
        .sheet(item: $detail) { PillarDetailView(result: $0, weight: model.weights[$0.def.key] ?? 0) }
    }

    private func step(_ d: Int) {
        let i = model.selectedIndex + d
        if model.scores.indices.contains(i) { model.selectedIndex = i }
    }

    @ViewBuilder
    private func content(_ ds: DayScore) -> some View {
        VStack(spacing: 26) {
            ScoreRing(score: ds.score, band: ds.band)

            VStack(spacing: 10) {
                Text(ds.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline).foregroundStyle(Palette.textMuted)
                Text("Today is \(ds.band.label)")
                    .font(.title.bold()).foregroundStyle(Palette.textPrimary)
                if let avg = trailingAvg(model.scores, model.selectedIndex, 7) {
                    Text("7-day average \(avg)").font(.footnote).foregroundStyle(Palette.textMuted)
                }
            }

            // Quick stats
            HStack(spacing: 18) {
                QuickStat(label: "Sleep", value: formatMetric(value(ds, "sleep_hours"), .hours))
                QuickStat(label: "Steps", value: formatMetric(value(ds, "steps"), .steps))
                QuickStat(label: "Rest HR", value: formatMetric(value(ds, "resting_hr"), .bpm))
                QuickStat(label: "Move", value: formatMetric(value(ds, "exercise_minutes"), .minutes))
            }

            // Diagnosis
            if ds.flagged {
                Banner(icon: "exclamationmark.triangle.fill", tint: Palette.bandAtRisk,
                       title: "Recovery flag", message: ds.flagReason ?? "")
            } else {
                VStack(spacing: 12) {
                    DiagnosisRow(icon: "arrow.down.right.circle", label: "Weakest pillar",
                                 value: "\(ds.worstPillar.def.shortName) · \(ds.worstPillar.score)")
                    if let wm = ds.worstMetric {
                        DiagnosisRow(icon: "target", label: "Push on this",
                                     value: "\(wm.def.name) · \(Int((wm.attainment ?? 0).rounded()))% of target")
                    }
                }
                .padding(14)
                .background(Palette.bgSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
            }

            // Pillars
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ds.pillars) { p in
                    Button { detail = p } label: {
                        PillarCardView(result: p, weight: model.weights[p.def.key] ?? 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Small pieces

struct QuickStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.textPrimary).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DiagnosisRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.textMuted).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(Palette.textMuted)
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Palette.textPrimary)
            }
            Spacer()
        }
    }
}

struct Banner: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.textPrimary)
                Text(message).font(.footnote).foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.4), lineWidth: 1))
    }
}

struct LoadingOrEmpty: View {
    @Environment(LumenModel.self) private var model
    var body: some View {
        VStack(spacing: 14) {
            if model.state == .loading || model.state == .requesting {
                ProgressView().tint(Palette.accent)
                Text("Reading Apple Health…").font(.subheadline).foregroundStyle(Palette.textMuted)
            } else {
                Image(systemName: "heart.text.square").font(.largeTitle).foregroundStyle(Palette.textFaint)
                Text("No Health data yet").font(.headline).foregroundStyle(Palette.textSecondary)
                Text("Make sure Lumen has permission in Settings → Health, then pull to refresh.")
                    .font(.footnote).foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Button("Re-read Health") { Task { await model.reload() } }
                    .buttonStyle(.borderedProminent).tint(Palette.accent)
            }
        }
    }
}

// MARK: - Pillar detail sheet

struct PillarDetailView: View {
    let result: PillarResult
    let weight: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(result.def.blurb).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    ForEach(result.metrics) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.def.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.textPrimary)
                                Spacer()
                                Text(formatMetric(m.actual, m.def.format))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(m.gap ? Palette.textFaint : result.def.color)
                                    .monospacedDigit()
                            }
                            HStack {
                                Text("Target \(m.def.targetText)").font(.caption).foregroundStyle(Palette.textMuted)
                                Spacer()
                                Text(m.gap ? "no data" : "\(Int((m.attainment ?? 0).rounded()))% of target")
                                    .font(.caption).foregroundStyle(Palette.textMuted)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Palette.bgInset)
                                    Capsule().fill(result.def.color)
                                        .frame(width: geo.size.width * CGFloat((m.attainment ?? 0)) / 100)
                                }
                            }.frame(height: 6)
                            Text(m.def.why).font(.caption).foregroundStyle(Palette.textMuted)
                        }
                        .padding(.vertical, 8)
                        Divider().overlay(Palette.border)
                    }
                }
                .padding()
            }
            .background(Palette.bgApp)
            .scrollContentBackground(.hidden)
            .navigationTitle(result.def.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
