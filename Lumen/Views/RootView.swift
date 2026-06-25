import SwiftUI

struct RootView: View {
    @Environment(LumenModel.self) private var model

    var body: some View {
        ZStack {
            Palette.bgApp.ignoresSafeArea()
            switch model.state {
            case .unavailable:
                MessageView(icon: "heart.slash",
                            title: "Health data unavailable",
                            message: "Lumen needs an iPhone with the Health app to read your data.")
            default:
                if model.didOnboard {
                    MainTabs()
                } else {
                    OnboardingView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
    }
}

struct MainTabs: View {
    @Environment(LumenModel.self) private var model
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "house.fill") }
            TrendsView().tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .task {
            // First appearance after onboarding (or a relaunch) — read Health.
            if model.scores.isEmpty && model.state != .loading {
                await model.reload()
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(LumenModel.self) private var model
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(Palette.bgInset, lineWidth: 10).frame(width: 120, height: 120)
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                Image(systemName: "waveform.path.ecg").font(.title).foregroundStyle(Palette.accent)
            }
            .padding(.bottom, 28)

            Text("Lumen").font(.largeTitle.bold()).foregroundStyle(Palette.textPrimary)
            Text("Your Apple Health, in one daily Life Score.")
                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center).padding(.top, 6).padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 14) {
                Text("Lumen reads sleep, activity, heart, and body data to compute your score. It all stays on your device — nothing is ever uploaded.")
                    .font(.footnote).foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)

                Button {
                    Task { await model.connectAndLoad() }
                } label: {
                    HStack {
                        if model.state == .requesting || model.state == .loading {
                            ProgressView().tint(.black)
                        }
                        Image(systemName: "heart.fill")
                        Text("Connect Apple Health")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
                .disabled(model.state == .requesting || model.state == .loading)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 50)
        }
    }
}

struct MessageView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Palette.textFaint)
            Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
            Text(message).font(.subheadline).foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }
}
