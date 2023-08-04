// Copyright 2020 Google LLC
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

/// Models an object that can be used as an item in a tableview
protocol Itemable {
  var title: String? { get }
  var detailTitle: String? { get }
  var image: UIImage? { get set }
  var textColor: UIColor? { get }
  var isEditable: Bool { get }
  var hasNestedContent: Bool { get set }
  var isChecked: Bool { get set }
}

/// Models an object that can be used as a section in a tableview
protocol Sectionable {
  associatedtype Item: Itemable
  var headerDescription: String? { get }
  var footerDescription: String? { get }
  var items: [Item] { get set }
}

/// Delegate Protocol to handle cell selection and tableview scrolling
protocol DataSourceProviderDelegate: AnyObject {
  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView)
  func tableViewDidScroll(_ tableView: UITableView)
}

extension DataSourceProviderDelegate {
  /// Provide default implementation to prevent a required implementation when conforming to this
  /// protocol
  func tableViewDidScroll(_ tableView: UITableView) {}
}

/// Models a type that can be used for the datasource in a DataSourceProvider
protocol DataSourceProvidable {
  associatedtype Section: Sectionable
  var sections: [Section] { get }
}
