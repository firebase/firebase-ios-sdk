//
//  ViewController.swift
//  Test App
//
//  Created by Pranav Rajgopal on 1/16/20.
//  Copyright © 2020 Pranav Rajgopal. All rights reserved.
//

import UIKit
import SafariServices

class ViewController: UIViewController {
    
    var safariViewController: SFSafariViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate
        
        appDelegate.mainViewController = self
        AppDistribution.appDistribution().checkForUpdate(completion: { release, error in
            guard let release = release else {
                return
            }

            let uialert = UIAlertController(title: "New Version Available", message: "Version \(release.bundleShortVersion) (\(release.bundleVersion)) is available.", preferredStyle: .alert)
            
            uialert.addAction(UIAlertAction(title: "Update", style: UIAlertAction.Style.default) {
                UIAlertAction in
            })
            uialert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {
                UIAlertAction in
            })
            self.present(uialert, animated: true, completion: nil)
        })
    }
    
    func updateHandler(action: UIAlertAction) {
        
    }
    
    func cancelHandler(action: UIAlertAction) {
        
    }
    
    @IBAction func touch(_ sender: Any) {
        print("this works!!!")
        if let url = URL(string: "https://appdistribution.firebase.dev/app_distro/projects/5e20b15eccbee769cb4582ee") {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true

            let vc = SFSafariViewController(url: url, configuration: config)
            safariViewController = vc
            present(vc, animated: true)
        }
////
//        guard let url = URL(string: "https://tinyurl.com/ua8tka3") else { return}
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

