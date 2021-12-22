import UIKit
import PromiseKit

class WalletNameViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var fieldName: UITextField!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var lblSubtitleHint: UILabel!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var btnNext: UIButton!

    private var networkSettings: [String: Any] {
        get {
            UserDefaults.standard.value(forKey: "network_settings") as? [String: Any] ?? [:]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        fieldName.delegate = self
        fieldName.text = OnBoardManager.shared.params?.walletName ?? ""
        setContent()
        setStyle()
        updateUI()
        hideKeyboardWhenTappedAround()

        view.accessibilityIdentifier = AccessibilityIdentifiers.WalletNameScreen.view
        fieldName.accessibilityIdentifier = AccessibilityIdentifiers.WalletNameScreen.nameField
        btnNext.accessibilityIdentifier = AccessibilityIdentifiers.WalletNameScreen.nextBtn
        btnSettings.accessibilityIdentifier = AccessibilityIdentifiers.WalletNameScreen.settingsBtn
    }

    func setContent() {
        lblTitle.text = NSLocalizedString("id_wallet_name", comment: "")
        lblHint.text = NSLocalizedString("id_choose_a_name_for_your_wallet", comment: "")
        lblSubtitle.text = NSLocalizedString("id_app_settings", comment: "")
        lblSubtitleHint.text = NSLocalizedString("id_you_can_change_these_later_on", comment: "")
        btnSettings.setTitle(NSLocalizedString("id_app_settings", comment: ""), for: .normal)
        btnNext.setTitle(NSLocalizedString("id_continue", comment: ""), for: .normal)
    }

    func setStyle() {
        fieldName.setLeftPaddingPoints(10.0)
        fieldName.setRightPaddingPoints(10.0)

        btnSettings.cornerRadius = 4.0
        btnSettings.borderWidth = 1.0
        btnSettings.borderColor = UIColor.customGrayLight()
        btnSettings.setTitleColor(UIColor.customMatrixGreen(), for: .normal)
    }

    func updateUI() {
        if fieldName.text?.count ?? 0 > 2 {
            btnNext.setStyle(.primary)
        } else {
            btnNext.setStyle(.primaryDisabled)
        }
    }

    func nameIsSet() {
        OnBoardManager.shared.params?.walletName = fieldName.text ?? ""
        if LandingViewController.flowType == .add {
            // Register new user
            register()
        } else {
            // Test credential on server side
            checkCredential()
        }
    }

    @IBAction func nameDidChange(_ sender: Any) {
        updateUI()
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            vc.account = OnBoardManager.shared.account
            present(vc, animated: true) {}
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        if networkSettings["tor"] as? Bool ?? false &&
            OnBoardManager.shared.params?.singleSig ?? false &&
            !UserDefaults.standard.bool(forKey: AppStorage.dontShowTorAlert) {
            presentDialogTorUnavailable()
        } else {
            nameIsSet()
        }
    }

    func presentDialogTorUnavailable() {
        let storyboard = UIStoryboard(name: "Shared", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogTorSingleSigViewController") as? DialogTorSingleSigViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.present(vc, animated: false, completion: nil)
            }
        }
    }

    fileprivate func register() {
        let bgq = DispatchQueue.global(qos: .background)
        let params = OnBoardManager.shared.params
        let session = SessionsManager.new(for: OnBoardManager.shared.account)
        firstly {
            self.startLoader(message: NSLocalizedString("id_setting_up_your_wallet", comment: ""))
            return Guarantee()
        }.then(on: bgq) {
            session.registerLogin(mnemonic: params?.mnemonic ?? "", password: params?.mnemomicPassword ?? "")
        }.then(on: bgq) { _ -> Promise<[String: Any]> in
            if params?.singleSig ?? false {
                return try session.createSubaccount(details: ["name": "Segwit Account", "type": AccountType.segWit.rawValue]).resolve()
            } else {
                return Promise<[String: Any]> { seal in seal.fulfill([:]) }
            }
        }.ensure {
            self.stopLoader()
        }.done { _ in
            self.next()
        }.catch { error in
            session.disconnect()
            switch error {
            case AuthenticationTypeHandler.AuthError.ConnectionFailed:
                DropAlert().error(message: NSLocalizedString("id_connection_failed", comment: ""))
            default:
                DropAlert().error(message: NSLocalizedString("id_login_failed", comment: ""))
            }
        }
    }

    func checkCredential() {
        let params = OnBoardManager.shared.params
        let bgq = DispatchQueue.global(qos: .background)
        let session = SessionsManager.new(for: OnBoardManager.shared.account)
        firstly {
            self.startLoader(message: NSLocalizedString("id_setting_up_your_wallet", comment: ""))
            return Guarantee()
        }.compactMap(on: bgq) {
            return try session.connect()
        }.then(on: bgq) {
            session.login(details: ["mnemonic": params?.mnemonic ?? "", "password": params?.mnemomicPassword ?? ""])
        }.ensure {
            self.stopLoader()
        }.done { _ in
            self.next()
        }.catch { error in
            session.disconnect()
            switch error {
            case AuthenticationTypeHandler.AuthError.ConnectionFailed:
                DropAlert().error(message: NSLocalizedString("id_connection_failed", comment: ""))
            default:
                DropAlert().error(message: NSLocalizedString("id_login_failed", comment: ""))
            }
        }
    }

    func next() {
        DispatchQueue.main.async {
            AccountsManager.shared.current = OnBoardManager.shared.account
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController")
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

}

extension WalletNameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}

extension WalletNameViewController: DialogTorSingleSigViewControllerDelegate {
    func didContinue() {
        nameIsSet()
    }
}
