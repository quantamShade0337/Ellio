import Combine
import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

final class AppStore: ObservableObject {
    @Published var morningTasks: [MorningTask] {
        didSet { save(morningTasks, forKey: Keys.morningTasks) }
    }

    @Published var packItems: [PackItem] {
        didSet { save(packItems, forKey: Keys.packItems) }
    }

    @Published var upcomingAlarms: [AlarmItem] {
        didSet {
            save(upcomingAlarms, forKey: Keys.upcomingAlarms)
            AlarmScheduler.sync(upcomingAlarms)
        }
    }

    @Published var queueItems: [String] {
        didSet { save(queueItems, forKey: Keys.queueItems) }
    }

    @Published var theme: AppTheme {
        didSet { save(theme, forKey: Keys.theme) }
    }

    init() {
        morningTasks = Self.load([MorningTask].self, forKey: Keys.morningTasks) ?? MorningTask.sample
        packItems = Self.load([PackItem].self, forKey: Keys.packItems) ?? PackItem.sample
        upcomingAlarms = Self.load([AlarmItem].self, forKey: Keys.upcomingAlarms) ?? AlarmItem.sample
        queueItems = Self.load([String].self, forKey: Keys.queueItems) ?? [
            "Reply to Theo about studio timing",
            "Pick up detergent on the way home",
            "Submit typography references"
        ]
        theme = Self.load(AppTheme.self, forKey: Keys.theme) ?? .dark
        AlarmScheduler.sync(upcomingAlarms)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Keys {
        static let morningTasks = "ellio.morningTasks"
        static let packItems = "ellio.packItems"
        static let upcomingAlarms = "ellio.upcomingAlarms"
        static let queueItems = "ellio.queueItems"
        static let theme = "ellio.theme"
    }
}
