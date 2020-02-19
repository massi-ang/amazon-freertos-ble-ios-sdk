import AmazonFreeRTOS
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // FreeRTOS SDK Logging, will switch to AWSDDLog in future releases
        _ = AmazonContext.shared
        AmazonFreeRTOSManager.shared.isDebug = true

        // Override advertising Service UUIDs if needed.
        // AmazonFreeRTOSManager.shared.advertisingServiceUUIDs = []

        // AWS SDK Logging
        // AWSDDLog.sharedInstance.logLevel = .all
        // AWSDDLog.add(AWSDDTTYLogger.sharedInstance)

        // Setup the user sign-in with cognito:
        return true
    }
}
