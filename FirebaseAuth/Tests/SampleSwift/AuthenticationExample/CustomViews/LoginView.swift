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

/// Login View presented when performing Email & Password Login Flow
class LoginView: UIView {
  var emailTextField: UITextField! {
    didSet {
      emailTextField.textContentType = .emailAddress
    }
  }

  var passwordTextField: UITextField! {
    didSet {
      passwordTextField.textContentType = .password
    }
  }

  var emailTopConstraint: NSLayoutConstraint!
  var passwordTopConstraint: NSLayoutConstraint!

  lazy var loginButton: UIButton = {
    let button = UIButton()
    button.setTitle("Login", for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(.highlightedLabel, for: .highlighted)
    button.setBackgroundImage(UIColor.systemOrange.image, for: .normal)
    button.setBackgroundImage(UIColor.systemOrange.highlighted.image, for: .highlighted)
    button.clipsToBounds = true
    button.layer.cornerRadius = 14
    return button
  }()

  lazy var createAccountButton: UIButton = {
    let button = UIButton()
    button.setTitle("Create Account", for: .normal)
    button.setTitleColor(.secondaryLabel, for: .normal)
    button.setTitleColor(UIColor.secondaryLabel.highlighted, for: .highlighted)
    return button
  }()

  convenience init() {
    self.init(frame: .zero)
    setupSubviews()
  }

  // MARK: - Subviews Setup

  private func setupSubviews() {
    backgroundColor = .systemBackground
    clipsToBounds = true

    setupFirebaseLogoImage()
    setupEmailTextfield()
    setupPasswordTextField()
    setupLoginButton()
    setupCreateAccountButton()
  }

  private func setupFirebaseLogoImage() {
    let firebaseLogo = UIImage(named: "firebaseLogo")
    let imageView = UIImageView(image: firebaseLogo)
    imageView.contentMode = .scaleAspectFit
    addSubview(imageView)
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -55),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 55),
      imageView.widthAnchor.constraint(equalToConstant: 325),
      imageView.heightAnchor.constraint(equalToConstant: 325),
    ])
  }

  private func setupEmailTextfield() {
    emailTextField = textField(placeholder: "Email", symbolName: "person.crop.circle")
    emailTextField.translatesAutoresizingMaskIntoConstraints = false
    addSubview(emailTextField)
    NSLayoutConstraint.activate([
      emailTextField.leadingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.leadingAnchor,
        constant: 15
      ),
      emailTextField.trailingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
      emailTextField.heightAnchor.constraint(equalToConstant: 45),
    ])

    let constant: CGFloat = UIDevice.current.orientation.isLandscape ? 15 : 50
    emailTopConstraint = emailTextField.topAnchor.constraint(
      equalTo: safeAreaLayoutGuide.topAnchor,
      constant: constant
    )
    emailTopConstraint.isActive = true
  }

  private func setupPasswordTextField() {
    passwordTextField = textField(placeholder: "Password", symbolName: "lock.fill")
    passwordTextField.translatesAutoresizingMaskIntoConstraints = false
    addSubview(passwordTextField)
    NSLayoutConstraint.activate([
      passwordTextField.leadingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.leadingAnchor,
        constant: 15
      ),
      passwordTextField.trailingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
      passwordTextField.heightAnchor.constraint(equalToConstant: 45),
    ])

    let constant: CGFloat = UIDevice.current.orientation.isLandscape ? 5 : 20
    passwordTopConstraint =
      passwordTextField.topAnchor.constraint(
        equalTo: emailTextField.bottomAnchor,
        constant: constant
      )
    passwordTopConstraint.isActive = true
  }

  private func setupLoginButton() {
    addSubview(loginButton)
    loginButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      loginButton.leadingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.leadingAnchor,
        constant: 15
      ),
      loginButton.trailingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.trailingAnchor,
        constant: -15
      ),
      loginButton.heightAnchor.constraint(equalToConstant: 45),
      loginButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 5),
    ])
  }

  private func setupCreateAccountButton() {
    addSubview(createAccountButton)
    createAccountButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      createAccountButton.centerXAnchor.constraint(equalTo: centerXAnchor),
      createAccountButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 5),
    ])
  }

  // MARK: - Private Helpers

  private func textField(placeholder: String, symbolName: String) -> UITextField {
    let textfield = UITextField()
    textfield.backgroundColor = .secondarySystemBackground
    textfield.layer.cornerRadius = 14
    textfield.placeholder = placeholder
    textfield.tintColor = .systemOrange
    let symbol = UIImage(systemName: symbolName)
    textfield.setImage(symbol)
    return textfield
  }
}
