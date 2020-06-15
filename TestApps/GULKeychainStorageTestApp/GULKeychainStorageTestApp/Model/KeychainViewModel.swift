/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

import Combine
import BackgroundTasks

import GoogleUtilities
import Promises

protocol BackgroundFetchHandler: AnyObject {
  func performFetchWithCompletionHandler(completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

class KeychainViewModel: ObservableObject {
  let valueKey = "SingleValueStorage.ValueKey"
  let keychainStorage: GULKeychainStorage

  internal init(keychainStorage: GULKeychainStorage = GULKeychainStorage(service: Bundle.main.bundleIdentifier ?? "GULKeychainStorageTestApp")) {
    self.keychainStorage = keychainStorage

    self.registerBackgroundFetchHandler()
  }

  // MARK: -- Keychain
  private func getValue() -> Promise<String?> {
    return Promise<String?>(keychainStorage.getObjectForKey(valueKey, objectClass: NSString.self, accessGroup: nil))
  }

  private func set(value: String?) -> Promise<NSNull> {
    if let value = value {
      return Promise<NSNull>(keychainStorage.setObject(value as NSString, forKey: valueKey, accessGroup: nil))
    } else {
      return Promise<NSNull>(keychainStorage.removeObject(forKey: valueKey, accessGroup: nil))
    }
  }

  private func generateRandom() -> Promise<String> {
    return Promise(UUID().uuidString)
  }

  // MARK: -- Log
  private func log(message: String) {
    log = "\(message)\n\(log)"
    print(message)
  }

  // MARK: -- View Model API
  @Published var log = ""

  func readButtonPressed() {
    getValue()
    .then { value in
      self.log(message: "Get value: \(value ?? "nil")")
    }.catch { error in
      self.log(message: "Get value error: \(error)")
    }
  }

  func generateAndSaveButtonPressed(completion: (() -> Void)? = nil) {
    generateRandom()
      .then { random -> Promise<NSNull> in
        self.log(message: "Saved value: \(random)")
        return self.set(value: random)
      }
      .catch { error in
        self.log(message: "Save value error: \(error)")
      }
    .always {
      completion?()
    }

  }

  // MARK: -- Background fetch
  let backgroundFetchTaskID = "KeychainViewModel.fetch"
  private func registerBackgroundFetchHandler() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundFetchTaskID, using: nil) { task in
      self.log(message: "Background fetch:")

      // Schedule next refresh.
      self.registerBackgroundFetchHandler()

      self.generateAndSaveButtonPressed {
        task.setTaskCompleted(success: true)
      }
    }

    let request = BGAppRefreshTaskRequest(identifier: backgroundFetchTaskID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5)

    do {
       try BGTaskScheduler.shared.submit(request)
      print("Background app refresh scheduled.")
    } catch {
      print("Could not schedule app refresh: \(error)")
    }
  }
}

extension KeychainViewModel: BackgroundFetchHandler {
  func performFetchWithCompletionHandler(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    self.log(message: "Background fetch:")

    self.readButtonPressed()

    self.generateAndSaveButtonPressed {
      completionHandler(.newData)
    }
  }
}
