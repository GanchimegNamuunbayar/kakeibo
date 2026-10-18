import SwiftUI
import SwiftData

@main
struct KakeiboApp: App {
    let container: ModelContainer

    init() {
        let configuration = ModelConfiguration(schema: KakeiboSchema.all, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: KakeiboSchema.all, configurations: configuration)
            SeedData.ensure(in: container.mainContext)
        } catch {
            fatalError("SwiftData の初期化に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Palette.accent)
        }
        .modelContainer(container)
    }
}
