import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

extension Notification.Name {
    static let xolarOpenTicketFromNotification = Notification.Name("xolarOpenTicketFromNotification")
    static let xolarFCMTokenDidUpdate = Notification.Name("xolarFCMTokenDidUpdate")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let token = fcmToken else { return }

        NotificationCenter.default.post(
            name: .xolarFCMTokenDidUpdate,
            object: nil,
            userInfo: [
                "token": token
            ]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo

        guard let ticketId = info["ticketId"] as? String else {
            return
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .xolarOpenTicketFromNotification,
                object: nil,
                userInfo: [
                    "ticketId": ticketId,
                    "notificationId": response.notification.request.identifier
                ]
            )
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }

            Messaging.messaging().token { token, error in
                if let realToken = token {
                    NotificationCenter.default.post(
                        name: .xolarFCMTokenDidUpdate,
                        object: nil,
                        userInfo: [
                            "token": realToken
                        ]
                    )
                }

                if let error = error {
                    print("FCM token error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }

    func sendLocalNotification(_ item: AgentNotification) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "ticketId": item.ticketId,
            "notificationId": item.id,
            "type": item.type
        ]

        let request = UNNotificationRequest(
            identifier: item.id,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func clearDeliveredNotification(id: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}