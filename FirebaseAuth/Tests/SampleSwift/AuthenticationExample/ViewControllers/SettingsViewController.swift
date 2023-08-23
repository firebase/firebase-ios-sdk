// Copyright 2023 Google LLC
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

import UIKit
@testable import FirebaseAuth
import FirebaseCore

/// Namespace for performable actions on a Auth Settings view
enum SettingsAction: String {
  case toggleIdentityTokenAPI = "Identity Toolkit"
  case toggleSecureTokenAPI = "Secure Token"
  case toggleActiveApp = "Active App"
  case toggleAccessGroup = "Current Access Group"
}

class SettingsViewController: UIViewController, DataSourceProviderDelegate {
  var dataSourceProvider: DataSourceProvider<AuthSettings>!

  var tableView: UITableView { view as! UITableView }

  private var _settings: AuthSettings?
  var settings: AuthSettings? {
    get { AppManager.shared.auth().settings }
    set { _settings = newValue }
  }

  // MARK: - UIViewController Life Cycle

  override func loadView() {
    view = UITableView(frame: .zero, style: .insetGrouped)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureDataSourceProvider()
  }

  // MARK: - DataSourceProviderDelegate

  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)

    guard let actionName = item.detailTitle,
          let action = SettingsAction(rawValue: actionName) else {
      // The row tapped has no affiliated action.
      return
    }

    switch action {
    case .toggleSecureTokenAPI:
      toggleSecureTokenAPI()
    case .toggleIdentityTokenAPI:
      toggleIdentityTokenAPI()
    case .toggleActiveApp:
      AppManager.shared.toggle()
    case .toggleAccessGroup:
      toggleAccessGroup()
    }
    updateUI()
  }

  // MARK: - Firebase 🔥

  private func toggleIdentityTokenAPI() {
    if IdentityToolkitRequest.host == "www.googleapis.com" {
      IdentityToolkitRequest.setHost("staging-www.sandbox.googleapis.com")
    } else {
      IdentityToolkitRequest.setHost("www.googleapis.com")
    }
  }

  private func toggleSecureTokenAPI() {
    if SecureTokenRequest.host == "securetoken.googleapis.com" {
      SecureTokenRequest.setHost("staging-securetoken.sandbox.googleapis.com")
    } else {
      SecureTokenRequest.setHost("securetoken.googleapis.com")
    }
  }

  private func toggleAccessGroup() {
    if AppManager.shared.auth().userAccessGroup == nil {
      guard let bundleDictionary = Bundle.main.infoDictionary,
            let group = bundleDictionary["AppIdentifierPrefix"] as? String else {
        fatalError("Configure AppIdentifierPrefix in the plist")
      }
      AppManager.shared.auth().userAccessGroup = group + "com.google.firebase.auth.keychainGroup1"
    } else {
      AppManager.shared.auth().userAccessGroup = nil
    }
  }

  // MARK: - Private Helpers

  private func configureNavigationBar() {
    navigationItem.title = "Settings"
    guard let navigationBar = navigationController?.navigationBar else { return }
    navigationBar.prefersLargeTitles = true
    navigationBar.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
    navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.systemOrange]
  }

  private func configureDataSourceProvider() {
    dataSourceProvider = DataSourceProvider(
      dataSource: settings?.sections,
      emptyStateView: SignedOutView(),
      tableView: tableView
    )
    dataSourceProvider.delegate = self
  }

  private func updateUI() {
    configureDataSourceProvider()
    animateUpdates(for: tableView)
  }

  private func animateUpdates(for tableView: UITableView) {
    UIView.transition(with: tableView, duration: 0.2,
                      options: .transitionCrossDissolve,
                      animations: { tableView.reloadData() })
  }

  private func presentEditUserInfoController(for title: String,
                                             to saveHandler: @escaping (String) -> Void) {
    let editController = UIAlertController(
      title: "Update \(title)",
      message: nil,
      preferredStyle: .alert
    )
    editController.addTextField { $0.placeholder = "New \(title)" }

    let saveHandler1: (UIAlertAction) -> Void = { _ in
      let text = editController.textFields!.first!.text!
      saveHandler(text)
    }

    let cancel: (UIAlertAction) -> Void = { _ in
      saveHandler("")
    }

    editController.addAction(UIAlertAction(title: "Save", style: .default, handler: saveHandler1))
    editController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: cancel))
    present(editController, animated: true, completion: nil)
  }
}

// MARK: - Extending a `AuthSettings` to conform to `DataSourceProvidable`

extension AuthSettings: DataSourceProvidable {
  private var versionSection: Section {
    let items = [Item(title: FirebaseVersion(), detailTitle: "FirebaseAuth")]
    return Section(headerDescription: "Versions", items: items)
  }

  private var apiHostSection: Section {
    let items = [Item(title: IdentityToolkitRequest.host, detailTitle: "Identity Toolkit"),
                 Item(title: SecureTokenRequest.host, detailTitle: "Secure Token")]
    return Section(headerDescription: "API Hosts", items: items)
  }

  private var appsSection: Section {
    let items = [Item(title: AppManager.shared.app.options.projectID, detailTitle: "Active App")]
    return Section(headerDescription: "Firebase Apps", items: items)
  }

  private var keychainSection: Section {
    let items = [Item(title: AppManager.shared.auth().userAccessGroup ?? "[none]",
                      detailTitle: "Current Access Group")]
    return Section(headerDescription: "Keychain Access Groups", items: items)
  }

  var sections: [Section] {
    [versionSection, apiHostSection, appsSection, keychainSection]
  }
}
