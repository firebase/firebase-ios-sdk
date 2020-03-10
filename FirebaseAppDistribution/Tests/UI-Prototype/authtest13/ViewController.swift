//
//  ViewController.swift
//  Test App
//
//  Created by Pranav Rajgopal on 1/16/20.
//  Copyright © 2020 Pranav Rajgopal. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var appDistroSignIn: UIButton!
    @IBOutlet weak var appDistroSignOut: UIButton!

    func checkForAppDistroUpdates() {
        AppDistribution.appDistribution().checkForUpdate(completion: { release, error in
            guard let release = release else {
                return
            }

            self.appDistroSignIn?.setTitle("Already signed in. Check for update?", for: .normal)
            self.appDistroSignOut!.isHidden = false
            let uialert = UIAlertController(title: "New Version Available", message: "Version \(release.displayVersion) (\(release.buildVersion)) is available.", preferredStyle: .alert)

            uialert.addAction(UIAlertAction(title: "Update", style: UIAlertAction.Style.default) {
                alert in
                print(release.downloadURL)
                UIApplication.shared.open(release.downloadURL)
            })
            uialert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {
                alert in
            })
            self.present(uialert, animated: true, completion: nil)
        })
    }

    override func viewDidLoad() {
        print("Loaded!")
        super.viewDidLoad()

        if(!AppDistribution.appDistribution().isTesterSignedIn) {
            print("Hiding sign out")
            self.appDistroSignOut.isHidden = true
        }
        print("Checking for app distro update everytime view loads for the first time")
        self.checkForAppDistroUpdates()
    }

    @IBAction func signoutClick(_ sender: Any) {
        AppDistribution.appDistribution().signOutTester()
        self.appDistroSignIn?.setTitle("Sign in to App DIstribution!", for: .normal)
        self.appDistroSignOut!.isHidden = true
    }

    @IBAction func SignInClick(_ sender: Any) {

        if(!AppDistribution.appDistribution().isTesterSignedIn) {

            AppDistribution.appDistribution().signInTester(completion: { error in
                if(error == nil) {
                    self.appDistroSignIn?.setTitle("Already signed in. Check for update?", for: .normal)
                    self.appDistroSignOut!.isHidden = false
                }
            })
        } else {
            self.checkForAppDistroUpdates()
        }
    }
}

