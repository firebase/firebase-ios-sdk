/*
 * Copyright 2017 Google
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

import FirebaseMessaging

enum Row: String {
  case apnsToken
  case apnsStatus
  case requestAPNSPermissions
  case fcmToken
}

enum PermissionsButtonTitle: String {
  case requestPermissions = "Request User Notifications"
  case noAPNS = "Cannot Request Permissions (No APNs)"
  case alreadyRequested = "Already Requested Permissions"
  case simulator = "Cannot Request Permissions (Simulator)"
}

class MessagingViewController: UIViewController {
  let tableView: UITableView

  var sections = [[Row]]()
  var sectionHeaderTitles = [String?]()

  var allowedNotificationTypes: [NotificationsControllerAllowedNotificationType]?

  // Cached rows by Row type. Since this is largely a fixed table view, we'll
  // keep track of our created cells and UI, rather than have all the logic

  required init?(coder aDecoder: NSCoder) {
    tableView = UITableView(frame: CGRect.zero, style: .grouped)
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 44
    // Allow UI Controls within the table to be immediately responsive
    tableView.delaysContentTouches = false
    super.init(coder: aDecoder)
    tableView.dataSource = self
    tableView.delegate = self
  }

  override func loadView() {
    super.loadView()
    view = UIView(frame: CGRect.zero)
    view.addSubview(tableView)
    // Ensure that the tableView always is the size of the view
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let center = NotificationCenter.default
    center.addObserver(self,
                       selector: #selector(onAPNSTokenReceived),
                       name: APNSTokenReceivedNotification,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(onUserNotificationSettingsChanged),
                       name: UserNotificationsChangedNotification,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(onFCMTokenRefreshed),
                       name: Notification.Name.MessagingRegistrationTokenRefreshed,
                       object: nil)
    updateAllowedNotificationTypes {
      self.resetTableContents()
      self.tableView.reloadData()
    }
  }

  func onAPNSTokenReceived() {
    // Reload the appropriate cells
    updateAllowedNotificationTypes {
      if let tokenPath = self.indexPathFor(.apnsToken),
        let statusPath = self.indexPathFor(.apnsStatus),
        let requestPath = self.indexPathFor(.requestAPNSPermissions) {
        self.updateIndexPaths(indexPaths: [tokenPath, statusPath, requestPath])
      }
    }
  }

  func onFCMTokenRefreshed() {
    if let indexPath = indexPathFor(.fcmToken) {
      updateIndexPaths(indexPaths: [indexPath])
    }
  }

  func onUserNotificationSettingsChanged() {
    updateAllowedNotificationTypes {
      if let statusPath = self.indexPathFor(.apnsStatus),
        let requestPath = self.indexPathFor(.requestAPNSPermissions) {
        self.updateIndexPaths(indexPaths: [statusPath, requestPath])
      }
    }
  }

  private func updateIndexPaths(indexPaths: [IndexPath]) {
    tableView.beginUpdates()
    tableView.reloadRows(at: indexPaths, with: .none)
    tableView.endUpdates()
  }

  fileprivate func updateAllowedNotificationTypes(_ completion: (() -> Void)?) {
    NotificationsController.shared.getAllowedNotificationTypes { types in
      self.allowedNotificationTypes = types
      self.updateRequestAPNSButton()
      completion?()
    }
  }

  fileprivate func updateRequestAPNSButton() {
    guard !Environment.isSimulator else {
      requestPermissionsButton.isEnabled = false
      requestPermissionsButton.setTitle(PermissionsButtonTitle.simulator.rawValue, for: .normal)
      return
    }
    guard let allowedTypes = allowedNotificationTypes else {
      requestPermissionsButton.isEnabled = false
      requestPermissionsButton.setTitle(PermissionsButtonTitle.noAPNS.rawValue, for: .normal)
      return
    }

    requestPermissionsButton.isEnabled =
      (allowedTypes.count == 1 && allowedTypes.first! == .silent)

    let title: PermissionsButtonTitle =
      (requestPermissionsButton.isEnabled ? .requestPermissions : .alreadyRequested)
    requestPermissionsButton.setTitle(title.rawValue, for: .normal)
  }

  // MARK: UI (Cells and Buttons) Defined as lazy properties

  lazy var apnsTableCell: UITableViewCell = {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: Row.apnsToken.rawValue)
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.lineBreakMode = .byWordWrapping
    return cell
  }()

  lazy var apnsStatusTableCell: UITableViewCell = {
    let cell = UITableViewCell(style: UITableViewCellStyle.value1,
                               reuseIdentifier: Row.apnsStatus.rawValue)
    cell.textLabel?.text = "Allowed:"
    cell.detailTextLabel?.numberOfLines = 0
    cell.detailTextLabel?.lineBreakMode = .byWordWrapping
    return cell
  }()

  lazy var requestPermissionsButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle(PermissionsButtonTitle.requestPermissions.rawValue, for: .normal)
    button.setTitleColor(UIColor.gray, for: .highlighted)
    button.setTitleColor(UIColor.gray, for: .disabled)
    button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    button.addTarget(self,
                     action: #selector(onRequestUserNotificationsButtonTapped),
                     for: .touchUpInside)
    return button
  }()

  lazy var apnsRequestPermissionsTableCell: UITableViewCell = {
    let cell = UITableViewCell(style: .default,
                               reuseIdentifier: Row.requestAPNSPermissions.rawValue)
    cell.selectionStyle = .none
    cell.contentView.addSubview(self.requestPermissionsButton)
    self.requestPermissionsButton.frame = cell.contentView.bounds
    self.requestPermissionsButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return cell
  }()

  lazy var fcmTokenTableCell: UITableViewCell = {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: Row.fcmToken.rawValue)
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.lineBreakMode = .byCharWrapping
    return cell
  }()
}

// MARK: - Configuring the table view and cells with information

extension MessagingViewController {
  func resetTableContents() {
    sections.removeAll()
    sectionHeaderTitles.removeAll()

    // APNS
    let apnsSection: [Row] = [.apnsToken, .apnsStatus, .requestAPNSPermissions]
    sections.append(apnsSection)
    sectionHeaderTitles.append("APNs")

    // FCM
    let fcmSection: [Row] = [.fcmToken]
    sections.append(fcmSection)
    sectionHeaderTitles.append("FCM Token")
  }

  func indexPathFor(_ rowId: Row) -> IndexPath? {
    var sectionIndex = 0
    for section in sections {
      var rowIndex = 0
      for row in section {
        if row == rowId {
          return IndexPath(row: rowIndex, section: sectionIndex)
        }
        rowIndex += 1
      }
      sectionIndex += 1
    }
    return nil
  }

  func configureCell(_ cell: UITableViewCell, withAPNSToken apnsToken: Data?) {
    guard !Environment.isSimulator else {
      cell.textLabel?.text = "APNs notifications are not supported in the simulator."
      cell.detailTextLabel?.text = nil
      return
    }
    if let apnsToken = apnsToken {
      cell.textLabel?.text = apnsToken.hexByteString
      cell.detailTextLabel?.text = "Tap to Share"
    } else {
      cell.textLabel?.text = "None"
      cell.detailTextLabel?.text = nil
    }
  }

  func configureCellWithAPNSStatus(_ cell: UITableViewCell) {
    if let allowedNotificationTypes = allowedNotificationTypes {
      let displayableTypes: [String] = allowedNotificationTypes.map { $0.rawValue }
      cell.detailTextLabel?.text = displayableTypes.joined(separator: ", ")
    } else {
      cell.detailTextLabel?.text = "Retrieving..."
    }
  }

  func configureCell(_ cell: UITableViewCell, withFCMToken fcmToken: String?) {
    if let fcmToken = fcmToken {
      cell.textLabel?.text = fcmToken
      cell.detailTextLabel?.text = "Tap to Share"
    } else {
      cell.textLabel?.text = "None"
      cell.detailTextLabel?.text = nil
    }
  }
}

// MARK: - UITableViewDataSource

extension MessagingViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].count
  }

  public func tableView(_ tableView: UITableView,
                        cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = sections[indexPath.section][indexPath.row]

    let cell: UITableViewCell
    switch row {
    case .apnsToken:
      cell = apnsTableCell
      configureCell(cell, withAPNSToken: Messaging.messaging().apnsToken)
    case .apnsStatus:
      cell = apnsStatusTableCell
      configureCellWithAPNSStatus(cell)
    case .requestAPNSPermissions:
      cell = apnsRequestPermissionsTableCell
    case .fcmToken:
      cell = fcmTokenTableCell
      configureCell(cell, withFCMToken: Messaging.messaging().fcmToken)
    }
    return cell
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sectionHeaderTitles[section]
  }
}

// MARK: - UITableViewDelegate

extension MessagingViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let row = sections[indexPath.section][indexPath.row]
    switch row {
    case .apnsToken:
      if let apnsToken = Messaging.messaging().apnsToken {
        showActivityViewControllerFor(sharedItem: apnsToken.hexByteString)
      }
    case .fcmToken:
      if let fcmToken = Messaging.messaging().fcmToken {
        showActivityViewControllerFor(sharedItem: fcmToken)
      }
    default: break
    }
  }
}

// MARK: - UI Controls

extension MessagingViewController {
  func onRequestUserNotificationsButtonTapped(sender: UIButton) {
    NotificationsController.shared.registerForUserFacingNotificationsFor(UIApplication.shared)
  }
}

// MARK: - Activity View Controller

extension MessagingViewController {
  func showActivityViewControllerFor(sharedItem: Any) {
    let activityViewController = UIActivityViewController(activityItems: [sharedItem],
                                                          applicationActivities: nil)
    present(activityViewController, animated: true, completion: nil)
  }
}
