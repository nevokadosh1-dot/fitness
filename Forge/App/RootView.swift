import SwiftUI
import SwiftData

struct RootView: View {
    var storeLoadError: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLockService.self) private var appLock
    @Query private var settingsList: [AppSettings]

    @State private var showStoreError = false
    @State private var didApplyInitialLock = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Group {
            if settings?.onboardingComplete == true {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .overlay {
            if appLock.isLocked {
                LockScreenView()
            }
        }
        .onAppear {
            if !didApplyInitialLock, let settings {
                didApplyInitialLock = true
                appLock.lockIfEnabled(settings: settings)
            }
            showStoreError = storeLoadError != nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, let settings {
                appLock.lockIfEnabled(settings: settings)
            }
        }
        .alert("Storage Problem", isPresented: $showStoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storeLoadError ?? "")
        }
    }

    private var mainTabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            WorkoutsHomeView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }

            ProgressHomeView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .background(Theme.background)
    }
}

/// Full-screen cover shown while the app is locked.
struct LockScreenView: View {
    @Environment(AppLockService.self) private var appLock

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.accent)
                Text("Forge is locked")
                    .font(.forgeTitle)
                    .foregroundStyle(Theme.textPrimary)
                if let error = appLock.lastError {
                    Text(error)
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("Unlock") {
                    Task { await appLock.unlock() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
            }
            .padding(Spacing.xl)
        }
        .task { await appLock.unlock() }
    }
}
