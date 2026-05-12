import Foundation

enum AppConfig {
    static let appName = "Xolar Admin"

    static let firebaseApiKey = "PASTE_YOUR_FIREBASE_WEB_API_KEY_HERE"

    static let realtimeDatabaseURL = "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com"

    static let pollNanoseconds: UInt64 = 4_000_000_000
    static let maxLocalNotifications = 50
}
