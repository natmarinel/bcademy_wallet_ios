import UIKit

class HomeViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lblVersion: UILabel!
    @IBOutlet weak var btnSettings: UIButton!

    var swAccounts =  [Account]()
    var hwAccounts =  [Account]()

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        updateUI()
        view.accessibilityIdentifier = AccessibilityIdentifiers.HomeScreen.view
        btnSettings.accessibilityIdentifier = AccessibilityIdentifiers.HomeScreen.appSettingsBtn
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        swAccounts = AccountsManager.shared.swAccounts
        hwAccounts = AccountsManager.shared.hwAccounts
        tableView.reloadData()
    }

    func setContent() {
        lblVersion.text = String(format: NSLocalizedString("id_version_1s", comment: ""), "\(Bundle.main.versionNumber)")
        btnSettings.setTitle(NSLocalizedString("id_app_settings", comment: ""), for: .normal)
    }

    func setStyle() {
    }

    func updateUI() {
    }

    func enterWallet(_ index: Int) {
        // watch only wallet
        let account = swAccounts[index]
        if let session = SessionsManager.get(for: account),
           session.connected && session.logged {
            session.subaccount().done { wallet in
                AccountsManager.shared.current = account
                let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
                let nav = storyboard.instantiateViewController(withIdentifier: "TabViewController") as? UINavigationController
                if let vc = nav?.topViewController as? ContainerViewController {
                    vc.presentingWallet = wallet
                }
                UIApplication.shared.keyWindow?.rootViewController = nav
            }.catch { err in
                print("subaccount error: \(err.localizedDescription)")
            }
            return
        }
        let homeS = UIStoryboard(name: "Home", bundle: nil)
        let onBoardS = UIStoryboard(name: "OnBoard", bundle: nil)
        if account.isWatchonly {
            if let nav = homeS.instantiateViewController(withIdentifier: "HomeViewController") as? UINavigationController,
                let vc = onBoardS.instantiateViewController(withIdentifier: "WatchOnlyLoginViewController") as? WatchOnlyLoginViewController {
                    vc.account = account
                    nav.pushViewController(vc, animated: false)
                    UIApplication.shared.keyWindow?.rootViewController = nav
            }
            return
        }
        if let nav = homeS.instantiateViewController(withIdentifier: "HomeViewController") as? UINavigationController,
            let vc = homeS.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                vc.account = account
                nav.pushViewController(vc, animated: false)
                UIApplication.shared.keyWindow?.rootViewController = nav
        }
    }

    func showHardwareWallet(_ index: Int) {
        if let account = AccountsManager.shared.current {
            if account.isJade || account.isLedger {
                BLEManager.shared.dispose()
            }
        }
        let storyboard = UIStoryboard(name: "HWW", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWWScanViewController") as? HWWScanViewController {
            vc.account = hwAccounts[index]
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func didPressAddWallet() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "LandingViewController")
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            present(vc, animated: true) {}
        }
    }
}

extension HomeViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch section {
        case 0:
            return swAccounts.count == 0 ? 1 : swAccounts.count
        case 1:
            return hwAccounts.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case 0:
            if swAccounts.count == 0 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletEmptyCell") as? WalletEmptyCell {
                    cell.configure(NSLocalizedString("id_it_looks_like_you_have_no", comment: ""), UIImage(named: "ic_logo_green")!)
                    cell.selectionStyle = .none
                    return cell
                }
            } else {
                let account = swAccounts[indexPath.row]
                if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletCell") as? WalletCell {
                    let selected = { () -> Bool in
                        if let session = SessionsManager.get(for: account) {
                            return session.connected && session.logged
                        }
                        return false
                    }
                    cell.configure(account, selected())
                    cell.selectionStyle = .none
                    return cell
                }
            }
        case 1:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletHDCell") as? WalletHDCell {
                let hw = hwAccounts[indexPath.row]
                cell.configure(hw.name, hw.icon)
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerH
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return footerH
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return headerView(NSLocalizedString("id_all_wallets", comment: "").uppercased())
        /*case 1:
            return headerView(NSLocalizedString("id_devices", comment: "").uppercased())*/
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return footerView(NSLocalizedString("id_add_wallet", comment: ""))
        case 1:
            return nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            if swAccounts.count > 0 {
                enterWallet(indexPath.row)
            }
        case 1:
            showHardwareWallet(indexPath.row)
        default:
            break
        }
    }
}

extension HomeViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.customTitaniumDark()
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 14.0, weight: .semibold)
        title.text = txt
        title.textColor = UIColor.customGrayLight()
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -24)
        ])

        return section
    }

    func footerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: footerH))
        section.backgroundColor = UIColor.customTitaniumDark()

        let icon = UIImageView(frame: .zero)
        icon.image = UIImage(named: "ic_plus")?.maskWithColor(color: .white)
        icon.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(icon)

        let title = UILabel(frame: .zero)
        title.text = txt
        title.textColor = .white
        title.font = .systemFont(ofSize: 17.0, weight: .semibold)
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 40.0),
            icon.heightAnchor.constraint(equalToConstant: 40.0)
        ])

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: (40 + 16 * 2)),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -24)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didPressAddWallet))
        section.addGestureRecognizer(tapGesture)
        section.accessibilityIdentifier = AccessibilityIdentifiers.HomeScreen.addWalletView
        return section
    }
}
