import Foundation
// import Firebase // TODO mac wants module imports, iOS requires non-modular imports in Firebase.h
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseInstanceID
import FirebaseStorage
import GoogleUtilities_Environment
import GoogleUtilities_Logger

print("Hello world!")
print("Is app store receipt sandbox? Answer: \(GULAppEnvironmentUtil.isAppStoreReceiptSandbox())")
print("Is from app store? Answer: \(GULAppEnvironmentUtil.isFromAppStore())")
print("Is this the simulator? Answer: \(GULAppEnvironmentUtil.isSimulator())")
print("Device model? Answer: \(GULAppEnvironmentUtil.deviceModel() ?? "NONE")")
print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion() ?? "NONE")")
print("Is App extension? Answer: \(GULAppEnvironmentUtil.isAppExtension())")
print("Is iOS 7 or higher? Answer: \(GULAppEnvironmentUtil.isIOS7OrHigher())")

print("Is there a default app? Answer: \(FirebaseApp.app() != nil)")

print("Storage Version String? Answer: \(StorageVersionString)")

print("InstanceIDScopeFirebaseMessaging? Answer: \(InstanceIDScopeFirebaseMessaging)")
