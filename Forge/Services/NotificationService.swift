import Foundation
import UserNotifications

/// Local notifications, all opt-in and individually configurable.
enum NotificationService {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Rebuilds every scheduled reminder from current settings. Called after
    /// any notification preference changes.
    static func rebuildSchedule(settings: AppSettings, weekActivities: [ResolvedActivity]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard await authorizationStatus() == .authorized else { return }
        let calendar = Calendar.current

        if settings.notifyScheduledWorkouts {
            // One reminder per upcoming planned activity this week, at the chosen time.
            for activity in weekActivities where activity.status == .planned && activity.kind != .rest {
                let day = calendar.startOfDay(for: activity.date)
                guard let fireDate = calendar.date(byAdding: .minute, value: settings.workoutReminderMinutes, to: day),
                      fireDate > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Today: \(activity.title)"
                content.body = "A \(activity.kind.displayName.lowercased()) session is on your plan."
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "workout-\(activity.id.uuidString)",
                    content: content, trigger: trigger
                )
                try? await center.add(request)
            }
        }

        if settings.notifyBodyWeightLogging {
            let content = UNMutableNotificationContent()
            content.title = "Morning weigh-in"
            content.body = "Log your body weight to keep the trend accurate."
            content.sound = .default
            var components = DateComponents()
            components.hour = settings.weighInReminderMinutes / 60
            components.minute = settings.weighInReminderMinutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "weigh-in", content: content, trigger: trigger))
        }

        if settings.notifyWeeklyReview {
            let content = UNMutableNotificationContent()
            content.title = "Weekly review"
            content.body = "Check your progress, adherence and new insights from this week."
            content.sound = .default
            var components = DateComponents()
            components.weekday = settings.firstWeekday
            components.hour = 18
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "weekly-review", content: content, trigger: trigger))
        }

        if settings.notifyMissedSessions {
            // Evening nudge if anything planned today is still incomplete.
            let today = calendar.startOfDay(for: Date())
            let todayPlanned = weekActivities.filter {
                calendar.isDate($0.date, inSameDayAs: today) && $0.status == .planned && $0.kind != .rest
            }
            if !todayPlanned.isEmpty, let fireDate = calendar.date(byAdding: .hour, value: 20, to: today), fireDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Session still open"
                content.body = "\(todayPlanned.count) planned session\(todayPlanned.count == 1 ? "" : "s") not logged yet today."
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "missed-today", content: content, trigger: trigger))
            }
        }

        if settings.notifyFlexibilitySessions {
            let content = UNMutableNotificationContent()
            content.title = "Flexibility session"
            content.body = "A short stretch keeps split progress moving. Frequency beats intensity."
            content.sound = .default
            var components = DateComponents()
            components.hour = 19
            components.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "flexibility", content: content, trigger: trigger))
        }
    }
}
