import UIKit

class WalletSettingsViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var cardTor: UIView!
    @IBOutlet weak var lblTorTitle: UILabel!
    @IBOutlet weak var lblTorHint: UILabel!

    @IBOutlet weak var cardProxy: UIView!
    @IBOutlet weak var lblProxyTitle: UILabel!
    @IBOutlet weak var lblProxyHint: UILabel!
    @IBOutlet weak var cardProxyDetail: UIView!
    @IBOutlet weak var fieldProxyIp: UITextField!

    @IBOutlet weak var cardTxCheck: UIView!
    @IBOutlet weak var lblTxCheckTitle: UILabel!
    @IBOutlet weak var lblTxCheckHint: UILabel!

    @IBOutlet weak var cardMulti: UIView!
    @IBOutlet weak var lblMultiTitle: UILabel!
    @IBOutlet weak var lblMultiHint: UILabel!

    @IBOutlet weak var cardElectBtc: UIView!
    @IBOutlet weak var lblElectBtcTitle: UILabel!
    @IBOutlet weak var lblElectBtcHint: UILabel!

    @IBOutlet weak var cardElectLiquid: UIView!
    @IBOutlet weak var lblElectLiquidTitle: UILabel!
    @IBOutlet weak var lblElectLiquidHint: UILabel!

    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnSave: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        setActions()
        hideKeyboardWhenTappedAround()
    }

    func setContent() {
        title = ""
        lblTitle.text = "Connection & Validation Settings"
        lblHint.text = "These settings apply for every wallet you use on Green"

        lblTorTitle.text = "Connect with Tor"
        lblTorHint.text = "Private, but less stable connection"
        lblProxyTitle.text = "Connect with proxy"
        lblProxyHint.text = ""
        lblTxCheckTitle.text = "SPV verification"
        lblTxCheckHint.text = "Verify your transactions are included in a block"
        lblMultiTitle.text = "Multi Server Validation"
        lblMultiHint.text = "Double check SPV with other servers"
        lblElectBtcTitle.text = "Bitcoin Electrum Backend"
        lblElectBtcHint.text = "Choose the Bitcoin Electrum servers you trust"
        lblElectLiquidTitle.text = "Liquid Electrum Backend"
        lblElectLiquidHint.text = "Chhose the Liquid Electrum servers you trust"

        btnCancel.setTitle("Cancel", for: .normal)
        btnSave.setTitle("Save", for: .normal)

        cardProxyDetail.isHidden = true
    }

    func setStyle() {
        btnCancel.cornerRadius = 4.0
        btnSave.cornerRadius = 4.0
        fieldProxyIp.setLeftPaddingPoints(10.0)
        fieldProxyIp.setRightPaddingPoints(10.0)
    }

    func setActions() {

    }

    @IBAction func switchProxyChange(_ sender: UISwitch) {

        cardProxyDetail.isHidden = !sender.isOn
    }

    @IBAction func btnCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func btnSave(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}