//
//  careersignalApp.swift
//  careersignal
//
//  Created by Eliot Pontarelli on 9/12/25.
//

import SwiftUI

@main
struct careersignalApp: App {
    init() {
        NotificationManager.shared.requestPermission()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
// MARK: - Notification Manager
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            // Handle permission result if needed
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
}
