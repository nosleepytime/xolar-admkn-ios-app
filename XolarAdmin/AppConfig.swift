import Foundation

enum AppConfig {
    static let appName = "Xolar Admin"

    static let firebaseApiKey = "AIzaSyClct0l3bgOEiqZMU4iOfHYC0ZuciJwz2o"

    static let realtimeDatabaseURL = "https://xolarsupport-default-rtdb.firebaseio.com"

    static let pollNanoseconds: UInt64 = 4_000_000_000
    static let maxLocalNotifications = 50
}