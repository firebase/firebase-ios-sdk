/*
* Copyright 2020 Google
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

import UIKit
import FirebaseAnalytics
import FirebaseRemoteConfig

class ViewController: UIViewController {
  
  @IBAction func fireAnalyticsEventButtonTapped(_ sender: Any) {
    let alert = UIAlertController(title: "Fire custom analytics event",
                                  message: "Enter the name of a custom event",
                                  preferredStyle: .alert)
    
    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (action) in
      alert.dismiss(animated: true, completion: nil)
    }))
    
    alert.addAction(UIAlertAction(title: "Fire event", style: .default, handler: { (action) in
      guard let textField = alert.textFields?.first else {
        assertionFailure("Alert has no text field. Something went wrong.")
        return
      }
      
      if let event = textField.text {
        Analytics.logEvent(event, parameters: nil)
      }
    }))
    
    alert.addTextField { (textField) in
      textField.placeholder = "e.g.: tapped_close_button"
    }
    
    self.present(alert, animated: true, completion: nil)
  }
  
  @IBAction func checkTestButtonTapped(_ sender: Any) {
    let remoteConfig = RemoteConfig.remoteConfig()
    
    remoteConfig.fetchAndActivate { (status, error) in
      guard let color = remoteConfig.configValue(forKey: "bg_color").stringValue else {
        assertionFailure("Failed to fetch `bg_color` config value. Check the ABT console.")
        return
      }
      
      DispatchQueue.main.async {
        if color == "green" {
          self.view.backgroundColor = UIColor.green
        } else {
          self.view.backgroundColor = UIColor.red
        }
      }
    }
  }
}

