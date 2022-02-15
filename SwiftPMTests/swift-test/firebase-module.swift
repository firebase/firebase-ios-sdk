// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Firebase
// Verify that the following Firebase Swift APIs can be found.
import FirebaseAnalyticsSwift
import FirebaseFirestoreSwift
#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
  import FirebaseInAppMessagingSwift
#endif
import FirebaseStorageSwift

// Functions is not visible from the Firebase pod with Swift Package Manager and a Swift implementation.
import FirebaseFunctions

class CoreExists: FirebaseApp {}
class AnalyticsExists: Analytics {}
class AuthExists: Auth {}
// Uncomment next line if ABTesting gets added to Firebase.h.
// class ABTestingExists : LifecycleEvents {}
class DatabaseExists: Database {}
#if os(iOS) && !targetEnvironment(macCatalyst)
  class DynamicLinksExists: DynamicLinks {}
#endif
class FirestoreExists: Firestore {}
class FunctionsExists: Functions {}
#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
  class InAppMessagingExists: InAppMessaging {}
  class InAppMessagingDisplayExists: InAppMessagingDisplay { // protocol instead of interface
    func displayMessage(_ messageForDisplay: InAppMessagingDisplayMessage,
                        displayDelegate: InAppMessagingDisplayDelegate) {}
  }
#endif

class MessagingExists: Messaging {}
#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
  class PerformanceExists: Performance {}
#endif
class RemoteConfigExists: RemoteConfig {}
class StorageExists: Storage {}
