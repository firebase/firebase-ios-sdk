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

/// Base UIViewController Class for presenting auth flows defined in
/// [OtherAuthMethods](x-source-tag://OtherAuthMethods)
class OtherAuthViewController: UIViewController {
  weak var delegate: (any LoginDelegate)?

  lazy var textField: UITextField = {
    let textField = UITextField()
    textField.backgroundColor = .secondarySystemBackground
    textField.tintColor = .systemOrange
    textField.layer.cornerRadius = 14
    return textField
  }()

  private var textFieldInputLabel: UILabel?

  private lazy var button: UIButton = {
    let button = UIButton()
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(.highlightedLabel, for: .highlighted)
    button.setBackgroundImage(UIColor.systemOrange.image, for: .normal)
    button.setBackgroundImage(UIColor.systemOrange.highlighted.image, for: .highlighted)
    button.clipsToBounds = true
    button.layer.cornerRadius = 14
    return button
  }()

  private var infoLabel: UILabel!

  private var textFieldTopConstraint: NSLayoutConstraint!
  private var buttonTopConstraint: NSLayoutConstraint!

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureNavigationBar()
    configureTextField()
    configureButton()
    configureInfoLabel()
  }

  // Dismisses keyboard when view is tapped
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    view.endEditing(true)
  }

  // MARK: - Action Handlers

  @objc
  func buttonTapped() {
    print(#function)
  }

  // MARK: - UI Configuration

  /// Used by subclasses to configure the UI for given OtherAuthMethod
  /// - Parameter authMethod: Either the Passwordless, Phone Number, Custom Auth login flow
  public func configureUI(for authMethod: OtherAuthMethod) {
    navigationItem.title = authMethod.navigationTitle
    textField.setImage(UIImage(systemName: authMethod.textFieldIcon)!)
    textField.placeholder = authMethod.textFieldPlaceholder
    configureTextFieldInputLabel(with: authMethod.textFieldInputText)
    button.setTitle(authMethod.buttonTitle, for: .normal)
    infoLabel.text = authMethod.infoText

    if authMethod == .PhoneNumber {
      textField.keyboardType = .numberPad
    }
  }

  private func configureNavigationBar() {
    navigationController?.setTitleColor(.systemOrange)
  }

  private func configureTextField() {
    textField.delegate = self
    textField.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(textField)
    textField.leadingAnchor
      .constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15).isActive = true
    textField.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -15
    ).isActive = true
    textField.heightAnchor.constraint(equalToConstant: 45).isActive = true

    let constant: CGFloat = UIDevice.current.orientation.isLandscape ? 10 : 60
    textFieldTopConstraint = textField.topAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.topAnchor,
      constant: constant
    )
    textFieldTopConstraint.isActive = true
  }

  private func configureTextFieldInputLabel(with text: String?) {
    guard let text = text else { return }
    let label = UILabel()
    label.font = .systemFont(ofSize: 12)
    label.textColor = .secondaryLabel
    label.text = text
    label.alpha = UIDevice.current.orientation.isLandscape ? 0 : 1
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 5),
      label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15),
      label.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
    ])
    textFieldInputLabel = label
  }

  private func configureButton() {
    button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: 15
      ),
      button.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
      button.heightAnchor.constraint(equalToConstant: 45),
    ])
    let constant: CGFloat = UIDevice.current.orientation.isLandscape ? 15 : 110
    buttonTopConstraint = button.topAnchor.constraint(
      equalTo: textField.bottomAnchor,
      constant: constant
    )
    buttonTopConstraint.isActive = true
  }

  private func configureInfoLabel() {
    infoLabel = UILabel()
    infoLabel.textColor = .secondaryLabel
    infoLabel.numberOfLines = 15
    infoLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(infoLabel)
    NSLayoutConstraint.activate([
      infoLabel.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 10),
      infoLabel.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: 35
      ),
      infoLabel.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
    ])
    let infoSymbol = UIImageView(systemImageName: "info.circle", tintColor: .systemOrange)
    infoSymbol.contentMode = .center
    infoSymbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17)
    infoSymbol.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(infoSymbol)
    NSLayoutConstraint.activate([
      infoSymbol.topAnchor.constraint(equalTo: infoLabel.topAnchor),
      infoSymbol.trailingAnchor.constraint(
        equalTo: infoLabel.safeAreaLayoutGuide.leadingAnchor,
        constant: -5
      ),
    ])
  }

  override func viewWillTransition(to size: CGSize,
                                   with coordinator: any UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    textFieldTopConstraint.constant = UIDevice.current.orientation.isLandscape ? 10 : 60
    buttonTopConstraint.constant = UIDevice.current.orientation.isLandscape ? 15 : 110
    textFieldInputLabel?.alpha = UIDevice.current.orientation.isLandscape ? 0 : 1
  }
}

// MARK: - UITextFieldDelegate

extension OtherAuthViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
