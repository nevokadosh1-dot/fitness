import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container: ModelContainer
    private let storeLoadError: String?

    @State private var appLock = AppLockService()

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITestMode")
        let result = ModelContainerFactory.makeContainer(inMemory: isUITest)
        container = result.container
        storeLoadError = result.loadError

        let container = self.container
        MainActor.assumeIsolated {
            let context = container.mainContext
            SeedData.seedIfNeeded(context: context)
            if isUITest {
                // UI tests skip onboarding and run against an in-memory store.
                let settings = AppSettings.fetchOrCreate(in: context)
                settings.onboardingComplete = true
                if ProcessInfo.processInfo.arguments.contains("-UITestSampleData") {
                    SampleData.insert(into: context)
                }
            }
            Haptics.isEnabled = AppSettings.fetchOrCreate(in: context).hapticsEnabled
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(storeLoadError: storeLoadError)
                .environment(appLock)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
