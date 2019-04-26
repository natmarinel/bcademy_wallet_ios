import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class WatchOnlySignIn: KeyboardViewController {
    var username: String? {
        get {
            return UserDefaults.standard.string(forKey: getNetwork() + "_username")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: getNetwork() + "_username")
        }
    }
    @IBOutlet var content: WatchOnlySignInView!
    var buttonConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        content.titlelabel.text = NSLocalizedString("id_log_in_via_watchonly_to_receive", comment: "")
        content.rememberTitle.text = NSLocalizedString("id_remember_username", comment: "")
        content.warningLabel.text = NSLocalizedString("id_watchonly_mode_can_be_activated", comment: "")
        content.rememberSwitch.addTarget(self, action: #selector(rememberSwitch), for: .valueChanged)
        content.loginButton.setTitle(NSLocalizedString("id_log_in", comment: ""), for: .normal)
        content.loginButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        content.loginButton.setGradient(true)
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.customTitaniumLight()]
        content.usernameTextField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("id_username", comment: ""), attributes: attributes)
        content.passwordTextField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("id_password", comment: ""), attributes: attributes)
        let height = content.usernameTextField.frame.height
        content.usernameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: height))
        content.passwordTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: height))
        content.usernameTextField.leftViewMode = .always
        content.passwordTextField.leftViewMode = .always
        if username != nil {
            content.usernameTextField.text = username!
            content.rememberSwitch.isOn = true
        }
    }

    @objc func rememberSwitch(_ sender: UISwitch) {
        if sender.isOn {
            let alert = UIAlertController(title: NSLocalizedString("id_warning_the_username_will_be", comment: ""), message: NSLocalizedString("id_your_watchonly_username_will_be", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in
                sender.isOn = false
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { _ in
                sender.isOn = true
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            self.username = nil
        }
    }

    override func keyboardWillShow(notification: NSNotification) {
        super.keyboardWillShow(notification: notification)
        buttonConstraint?.isActive = false
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        buttonConstraint = content.loginButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -keyboardFrame.height)
        buttonConstraint?.isActive = true
    }

    override func keyboardWillHide(notification: NSNotification) {
        super.keyboardWillShow(notification: notification)
        buttonConstraint?.isActive = false
    }

    @objc func click(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        let appDelegate = getAppDelegate()!

        firstly {
            self.startAnimating(message: NSLocalizedString("id_logging_in", comment: ""))
            return Guarantee()
        }.compactMap(on: bgq) {
            appDelegate.disconnect()
        }.compactMap(on: bgq) {
            try appDelegate.connect()
        }.compactMap {
            let username = self.content.usernameTextField.text
            let password = self.content.passwordTextField.text
            if self.content!.rememberSwitch.isOn {
                self.username = username
            }
            return (username!, password!)
        }.compactMap(on: bgq) { (username, password) in
            try getSession().loginWatchOnly(username: username!, password: password!)
        }.ensure {
            self.stopAnimating()
        }.done {
            getGAService().isWatchOnly = true
            appDelegate.instantiateViewControllerAsRoot(storyboard: "Wallet", identifier: "TabViewController")
        }.catch { error in
            let message: String
            if let err = error as? GaError, err != GaError.GenericError {
                message = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
            } else {
                message = NSLocalizedString("id_login_failed", comment: "")
            }
            Toast.show(message, timeout: Toast.SHORT)
        }
    }
}

@IBDesignable
class WatchOnlySignInView: UIView {
    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var rememberSwitch: UISwitch!
    @IBOutlet weak var rememberTitle: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var warningLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        loginButton.updateGradientLayerFrame()
    }
}
