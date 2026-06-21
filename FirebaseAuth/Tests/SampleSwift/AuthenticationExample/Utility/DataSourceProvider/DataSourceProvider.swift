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

/// Abstracts away view/view controller based tableview configuration by acting as a tableview's
/// datasource and delegate
class DataSourceProvider<DataSource: DataSourceProvidable>: NSObject, UITableViewDataSource,
  UITableViewDelegate {
  weak var delegate: (any DataSourceProviderDelegate)?

  private var emptyView: UIView?

  private var sections: [DataSource.Section]!

  convenience init(dataSource: [DataSource.Section]?, emptyStateView: UIView? = nil,
                   tableView: UITableView? = nil) {
    self.init()
    emptyView = emptyStateView
    sections = dataSource ?? [DataSource.Section]()
    tableView?.dataSource = self
    tableView?.delegate = self
  }

  // MARK: Public Section and Item Getters

  public func section(at indexPath: IndexPath) -> DataSource.Section {
    return sections[indexPath.section]
  }

  public func item(at indexPath: IndexPath) -> DataSource.Section.Item {
    return sectionItem(at: indexPath)
  }

  @discardableResult
  public func updateItem(at indexPath: IndexPath, item: Item) -> DataSource.Section.Item {
    return editSectionItem(at: indexPath, item: item)
  }

  // MARK: - UITableViewDataSource

  func numberOfSections(in tableView: UITableView) -> Int {
    updateBackgroundViewIfNeeded(for: tableView)

    return sections.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].items.count
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return sections[section].headerDescription?.isEmpty ?? true ? 20 : 40
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    var label = UILabel()
    let section = sections[section]
    config(&label, for: section)
    return label
  }

  func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    return sections[section].footerDescription
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
      ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
    let item = sectionItem(at: indexPath)
    config(&cell, for: item)
    return cell
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    delegate?.didSelectRowAt(indexPath, on: tableView)
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let tableView = scrollView as? UITableView else { return }
    delegate?.tableViewDidScroll(tableView)
  }

  // MARK: - Private Helpers

  private func updateBackgroundViewIfNeeded(for tableView: UITableView) {
    tableView.backgroundView = sections.isEmpty ? emptyView : nil
    tableView.isScrollEnabled = !sections.isEmpty
  }

  private func sectionItem(at indexPath: IndexPath) -> DataSource.Section.Item {
    return sections[indexPath.section].items[indexPath.row]
  }

  private func editSectionItem(at indexPath: IndexPath, item: Item) -> DataSource.Section.Item {
    sections[indexPath.section].items[indexPath.row] = item as! DataSource.Section.Item
    return sectionItem(at: indexPath)
  }

  private func config(_ label: inout UILabel, for section: DataSource.Section) {
    label.text = section.headerDescription
    label.textColor = .label
    label.font = UIFont.boldSystemFont(ofSize: 19.0)
  }

  private func config(_ cell: inout UITableViewCell, for item: DataSource.Section.Item) {
    cell.textLabel?.text = item.title
    cell.textLabel?.textColor = item.textColor
    cell.detailTextLabel?.text = item.detailTitle
    cell.detailTextLabel?.textColor = .secondaryLabel
    cell.imageView?.image = item.image
    cell.accessoryView = item.isEditable ? editableImageView() : nil
    cell.accessoryType = item.hasNestedContent ? .disclosureIndicator : .none
    cell.accessoryType = item.isChecked ? .checkmark : cell.accessoryType
  }

  private func editableImageView() -> UIImageView {
    let image = UIImage(systemName: "pencil")?
      .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
    return UIImageView(image: image)
  }
}
