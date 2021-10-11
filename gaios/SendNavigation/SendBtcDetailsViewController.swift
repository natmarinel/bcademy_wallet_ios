import Foundation
import UIKit
import PromiseKit

class SendBtcDetailsViewController: UIViewController {

    @IBOutlet var content: SendBtcDetailsView!

    var wallet: WalletItem?
    var transaction: Transaction!
    var assetId: String = "btc"

    private var feeLabel: UILabel = UILabel()
    private var uiErrorLabel: UIErrorLabel!
    private var isFiat = false
    private var txTask: TransactionTask?

    private var btc: String {
        return AccountsManager.shared.current?.gdkNetwork?.getFeeAsset() ?? ""
    }

    private var asset: AssetInfo? {
        return Registry.shared.infos[assetId] ?? AssetInfo(assetId: assetId, name: assetId, precision: 0, ticker: "")
    }

    private var oldFeeRate: UInt64? {
        if let prevTx = transaction.details["previous_transaction"] as? [String: Any] {
            return prevTx["fee_rate"] as? UInt64
        }
        return nil
    }

    private var isLiquid: Bool {
        return AccountsManager.shared.current?.gdkNetwork?.liquid ?? false
    }

    private var feeEstimates: [UInt64?] = {
        var feeEstimates = [UInt64?](repeating: 0, count: 4)
        let estimates = getFeeEstimates() ?? []
        for (index, value) in [3, 12, 24, 0].enumerated() {
            feeEstimates[index] = estimates[value]
        }
        feeEstimates[3] = nil
        return feeEstimates
    }()

    private var minFeeRate: UInt64 = {
        guard let estimates = getFeeEstimates() else { return 1000 }
        return estimates[0]
    }()

    private var selectedFee: Int = {
        guard let settings = SessionManager.shared.settings else { return 0 }
        if let pref = TransactionPriority.getPreference() {
            settings.transactionPriority = pref
        }
        switch settings.transactionPriority {
        case .High:
            return 0
        case .Medium:
            return 1
        case .Low:
            return 2
        case .Custom:
            return 3
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        self.view.addGestureRecognizer(tapGesture)

        uiErrorLabel = UIErrorLabel(self.view)
        content.errorLabel.isHidden = true
        content.amountTextField.attributedPlaceholder = NSAttributedString(string: "0.00".localeFormattedString(2), attributes: [NSAttributedString.Key.foregroundColor: UIColor.customTitaniumLight()])

        if let oldFeeRate = oldFeeRate {
            feeEstimates[content.feeRateButtons.count - 1] = oldFeeRate + minFeeRate
            for index in (0..<content.feeRateButtons.count - 1).reversed() {
                guard let feeEstimate = feeEstimates[index] else { break }
                if oldFeeRate < feeEstimate {
                    selectedFee = index
                    break
                }
                content.feeRateButtons[index]?.isEnabled = false
                selectedFee = index
            }
        }

        // set labels
        self.title = NSLocalizedString("id_send", comment: "")
        content.fastFeeButton.setTitle(NSLocalizedString("id_fast", comment: ""))
        content.mediumFeeButton.setTitle(NSLocalizedString("id_medium", comment: ""))
        content.slowFeeButton.setTitle(NSLocalizedString("id_slow", comment: ""))
        content.customFeeButton.setTitle(NSLocalizedString("id_custom", comment: ""))
        content.sendAllFundsButton.setTitle(NSLocalizedString(("id_send_all_funds"), comment: ""), for: .normal)
        content.reviewButton.setTitle(NSLocalizedString("id_review", comment: ""), for: .normal)
        content.recipientTitle.text = NSLocalizedString("id_recipient", comment: "").uppercased()
        content.sendingTitle.text = NSLocalizedString("id_sending", comment: "").uppercased()
        content.minerFeeTitle.text = NSLocalizedString("id_network_fee", comment: "").uppercased()

        // setup liquid view
        content.assetView.isHidden = !isLiquid
        content.currencySwitch.isHidden = isLiquid
        content.assetView.heightAnchor.constraint(equalToConstant: 0).isActive = !isLiquid
        content.assetView.layoutIfNeeded()

        // read-only/increase fee transaction
        content.amountTextField.isEnabled = !transaction.addresseesReadOnly
        content.amountTextField.isUserInteractionEnabled = !transaction.addresseesReadOnly
        content.sendAllFundsButton.isHidden = transaction.addresseesReadOnly
        content.maxAmountLabel.isHidden = transaction.addresseesReadOnly

        view.accessibilityIdentifier = AccessibilityIdentifiers.SendBtcDetailsScreen.view
        content.amountTextField.accessibilityIdentifier = AccessibilityIdentifiers.SendBtcDetailsScreen.amountTextField
        content.recipientTitle.accessibilityIdentifier = AccessibilityIdentifiers.SendBtcDetailsScreen.recipientTitle
        content.reviewButton.accessibilityIdentifier = AccessibilityIdentifiers.SendBtcDetailsScreen.reviewBtn
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isLiquid {
            content.assetIconImageView.image = Registry.shared.image(for: asset?.assetId)
        }
        content.assetNameLabel.text = assetId == btc ? "Liquid Bitcoin" : asset?.name
        content.domainNameLabel.text = asset?.entity?.domain ?? ""
        content.domainNameLabel.isHidden = asset?.entity?.domain.isEmpty ?? true
        content.currencySwitch.isHidden = assetId != btc
        content.amountTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        content.reviewButton.addTarget(self, action: #selector(reviewButtonClick(_:)), for: .touchUpInside)
        content.sendAllFundsButton.addTarget(self, action: #selector(sendAllFundsButtonClick(_:)), for: .touchUpInside)
        content.currencySwitch.addTarget(self, action: #selector(currencySwitchClick(_:)), for: .touchUpInside)
        let assetTap = UITapGestureRecognizer(target: self, action: #selector(self.assetClick(_:)))
        content.assetClickableView.addGestureRecognizer(assetTap)

        let addressee = transaction.addressees.first!
        content.addressLabel.text = addressee.address
        reloadWalletBalance()
        reloadAmount()
        reloadCurrencySwitch()
        updateReviewButton(false)
        updateFeeButtons()
        updateTransaction()
        // Check if user needs to type an amount and open the keyboard
        // since we have converted amounts in reloadAmount()
        if !transaction.addresseesReadOnly && content.amountTextField.text!.isEmpty {
            content.amountTextField.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        content.amountTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        content.reviewButton.removeTarget(self, action: #selector(reviewButtonClick(_:)), for: .touchUpInside)
        content.sendAllFundsButton.removeTarget(self, action: #selector(sendAllFundsButtonClick(_:)), for: .touchUpInside)
        content.currencySwitch.removeTarget(self, action: #selector(currencySwitchClick(_:)), for: .touchUpInside)
    }

    func reloadAmount() {
        if transaction.isSweep {
            // In sweep, addressees are empty
            let satoshi = transaction.satoshi
            let (amount, _) = satoshi == 0 ? ("", "") : Balance.convert(details: ["satoshi": satoshi])?.get(tag: isFiat ? "fiat" : assetId) ?? ("", "")
            content.amountTextField.text = amount
            return
        }
        content.amountTextField.textColor = content.amountTextField.isEnabled ? UIColor.white : UIColor.lightGray
        if content.sendAllFundsButton.isSelected {
            content.amountTextField.text = NSLocalizedString("id_all", comment: "")
            return
        }
        if content.amountTextField.text == NSLocalizedString("id_all", comment: "") {
            content.amountTextField.text = ""
            return
        }
        guard let satoshi = transaction.addressees.first?.satoshi else { return }
        let details = btc != assetId ? ["satoshi": satoshi, "asset_info": asset!.encode()!] : ["satoshi": satoshi]
        let (amount, _) = satoshi == 0 ? ("", "") : Balance.convert(details: details)?.get(tag: isFiat ? "fiat" : assetId) ?? ("", "")
        content.amountTextField.text = amount
    }

    func reloadCurrencySwitch() {
        let isMainnet = AccountsManager.shared.current?.gdkNetwork?.mainnet ?? true
        let settings = SessionManager.shared.settings!
        let currency = isMainnet ? settings.getCurrency() : "FIAT"
        let title = isFiat ? currency : settings.denomination.string
        let color = isFiat ? UIColor.clear : UIColor.customMatrixGreen()
        content.currencySwitch.setTitle(title, for: UIControl.State.normal)
        content.currencySwitch.backgroundColor = color
        content.currencySwitch.setTitleColor(UIColor.white, for: UIControl.State.normal)
        updateFeeButtons()
    }

    func reloadWalletBalance() {
        let satoshi = wallet!.satoshi?[assetId] ?? 0
        let details = btc != assetId ? ["satoshi": satoshi, "asset_info": asset!.encode()!] : ["satoshi": satoshi]
        if let balance = Balance.convert(details: details) {
            let (amount, denom) = balance.get(tag: isFiat ? "fiat" : assetId)
            content.maxAmountLabel.text =  "\(amount ?? "N.A.") \(denom)"
        }
    }

    @objc func sendAllFundsButtonClick(_ sender: UIButton) {
        content.sendAllFundsButton.isSelected = !content.sendAllFundsButton.isSelected
        content.amountTextField.isEnabled = !content.sendAllFundsButton.isSelected
        content.amountTextField.isUserInteractionEnabled = !content.sendAllFundsButton.isSelected
        updateTransaction()
        reloadAmount()
    }

    @objc func reviewButtonClick(_ sender: UIButton) {
        self.performSegue(withIdentifier: "next", sender: self)
    }

    @objc func assetClick(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func currencySwitchClick(_ sender: UIButton) {
        isFiat = !isFiat
        reloadCurrencySwitch()
        reloadWalletBalance()
        reloadAmount()
        updateTransaction()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.wallet = wallet
            nextController.transaction = transaction
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateTransaction()
    }

    func getSatoshi() -> UInt64? {
        var amountText = content.amountTextField.text!
        amountText = amountText.isEmpty ? "0" : amountText
        amountText = amountText.unlocaleFormattedString(8)
        guard let number = Double(amountText), number > 0 else { return nil }
        let isBtc = assetId == btc
        let denominationBtc = SessionManager.shared.settings!.denomination.rawValue
        let key = isFiat ? "fiat" : (isBtc ? denominationBtc : assetId)
        let details: [String: Any]
        if isBtc {
            details = [key: amountText]
        } else {
            details = [key: amountText, "asset_info": asset!.encode()!]
        }
        return Balance.convert(details: details)?.satoshi
    }

    func updateTransaction() {
        guard let feeEstimate = feeEstimates[selectedFee] else { return }
        transaction.sendAll = content.sendAllFundsButton.isSelected
        transaction.feeRate = feeEstimate

        if !transaction.addresseesReadOnly {
            let satoshi = self.getSatoshi() ?? 0
            let address = content.addressLabel.text!
            // AssetId must not be present for bitcoin
            let addressee = isLiquid ? Addressee(address: address, satoshi: satoshi, assetId: assetId) : Addressee(address: address, satoshi: satoshi)
            transaction.addressees = [addressee]
        }
        txTask?.cancel()
        txTask = TransactionTask(tx: transaction)
        txTask?.execute().get { tx in
            self.transaction = tx
        }.done { tx in
            if !tx.error.isEmpty {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.uiErrorLabel.isHidden = true
            self.updateReviewButton(true)
            self.updateFeeButtons()
        }.catch { error in
            switch error {
            case TransactionError.invalid(let localizedDescription):
                self.uiErrorLabel.text = localizedDescription
            case GaError.ReconnectError, GaError.SessionLost, GaError.TimeoutError:
                self.uiErrorLabel.text = NSLocalizedString("id_you_are_not_connected", comment: "")
            default:
                self.uiErrorLabel.text = error.localizedDescription
            }
            self.uiErrorLabel.isHidden = false
            self.updateReviewButton(false)
            self.updateFeeButtons()
        }
    }

    func updateReviewButton(_ enable: Bool) {
        content.reviewButton.setGradient(enable)
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer?) {
        content.amountTextField.resignFirstResponder()
    }

    func updateFeeButtons() {
        for index in 0..<feeEstimates.count {
            guard let feeButton = content.feeRateButtons[index] else { break }
            if feeButton.gestureRecognizers == nil && feeButton.isEnabled {
                let tap = UITapGestureRecognizer(target: self, action: #selector(clickFeeButton))
                feeButton.addGestureRecognizer(tap)
                feeButton.isUserInteractionEnabled = true
            }
            feeButton.isSelect = false
            let tp = TransactionPriority(rawValue: [3, 12, 24, 0][index]) ?? TransactionPriority.Medium
            feeButton.timeLabel.text = tp == .Custom ? "" : "~ \(tp.time)"
            guard let fee = feeEstimates[index] else {
                feeButton.feerateLabel.text = NSLocalizedString("id_set_custom_fee_rate", comment: "")
                break
            }
            let feeSatVByte = Double(fee) / 1000.0
            let txSize = transaction.size
            let feeSatoshi = UInt64(feeSatVByte * Double(txSize))

            if let (amount, denom) = Balance.convert(details: ["satoshi": feeSatoshi])?.get(tag: isFiat ? "fiat" : btc) { // 'btc' or btc var? 'btc' -> nil btc -> amount
                let feeRate = feeSatVByte.description.localeFormattedString(1)
                feeButton.feerateLabel.text =  "\(amount ?? "N.A.") \(denom) (\(feeRate) satoshi / vbyte)"
            }
        }
        content.feeRateButtons[selectedFee]?.isSelect = true
    }

    func showFeeCustomPopup() {
        let alert = UIAlertController(title: NSLocalizedString("id_set_custom_fee_rate", comment: ""), message: "satoshi / byte", preferredStyle: .alert)
        alert.addTextField { (textField) in
            let feeRate: UInt64
            if let storedFeeRate = self.feeEstimates[self.content.feeRateButtons.count - 1] {
                feeRate = storedFeeRate
            } else if let oldFeeRate = self.oldFeeRate {
                feeRate = (oldFeeRate + self.minFeeRate)
            } else if let settings = SessionManager.shared.settings {
                feeRate = UInt64(settings.customFeeRate ?? self.minFeeRate)
            } else {
                feeRate = self.minFeeRate
            }
            textField.keyboardType = .decimalPad
            textField.attributedPlaceholder = NSAttributedString(string: String(Double(feeRate) / 1000),
                                                                          attributes: [NSAttributedString.Key.foregroundColor: UIColor.customTitaniumLight()])
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { [weak alert] (_) in
            alert?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_save", comment: ""), style: .default) { [weak alert] (_) in
            guard var amountText = alert!.textFields![0].text else { return }
            amountText = amountText.isEmpty ? "0" : amountText
            amountText = amountText.unlocaleFormattedString(8)
            guard let number = Double(amountText), number > 0 else { return }
            if 1000 * number >= Double(UInt64.max) { return }
            let feeRate = UInt64(1000 * number)
            if feeRate < self.minFeeRate {
                DropAlert().warning(message: String(format: NSLocalizedString("id_fee_rate_must_be_at_least_s", comment: ""), String(self.minFeeRate)))
                return
            }
            self.selectedFee = self.content.feeRateButtons.count - 1
            self.feeEstimates[self.content.feeRateButtons.count - 1] = feeRate
            self.updateFeeButtons()
            self.updateTransaction()
        })
        self.present(alert, animated: true, completion: nil)
    }

    @objc func clickFeeButton(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        let settings = SessionManager.shared.settings!
        switch view {
        case content.fastFeeButton:
            settings.transactionPriority = .High
            self.selectedFee = 0
        case content.mediumFeeButton:
            settings.transactionPriority = .Medium
            self.selectedFee = 1
        case content.slowFeeButton:
            settings.transactionPriority = .Low
            self.selectedFee = 2
        case content.customFeeButton:
            showFeeCustomPopup()
        default:
            break
        }
        updateFeeButtons()
        updateTransaction()
        dismissKeyboard(nil)
    }

    func showAlert(_ error: Error) {
        let text: String
        if let error = error as? TwoFactorCallError {
            switch error {
            case .failure(let localizedDescription), .cancel(let localizedDescription):
                text = localizedDescription
            }
            self.showAlert(title: NSLocalizedString("id_error", comment: ""), message: text)
        }
    }
}

class TransactionTask {
    var tx: Transaction
    private var cancelme = false
    private var task: DispatchWorkItem?

    init(tx: Transaction) {
        self.tx = tx
        task = DispatchWorkItem {
            let call = try? SessionManager.shared.createTransaction(details: self.tx.details)
            let data = try? call?.resolve().wait()
            let result = data?["result"] as? [String: Any]
            self.tx = Transaction(result ?? [:])
        }
    }

    func execute() -> Promise<Transaction> {
        let bgq = DispatchQueue.global(qos: .background)
        return Promise<Transaction> { seal in
            self.task!.notify(queue: bgq) {
                guard !self.cancelme else { return seal.reject(PMKError.cancelled) }
                seal.fulfill(self.tx)
            }
            bgq.async(execute: self.task!)
        }
    }

    func cancel() {
        cancelme = true
        task?.cancel()
    }
}

@IBDesignable
class SendBtcDetailsView: UIView {
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var maxAmountLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var currencySwitch: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var recipientTitle: UILabel!
    @IBOutlet weak var sendAllFundsButton: UIButton!
    @IBOutlet weak var minerFeeTitle: UILabel!
    @IBOutlet weak var fastFeeButton: FeeButton!
    @IBOutlet weak var mediumFeeButton: FeeButton!
    @IBOutlet weak var slowFeeButton: FeeButton!
    @IBOutlet weak var customFeeButton: FeeButton!
    @IBOutlet weak var sendingTitle: UILabel!
    @IBOutlet weak var assetView: UIView!
    @IBOutlet weak var assetNameLabel: UILabel!
    @IBOutlet weak var domainNameLabel: UILabel!
    @IBOutlet weak var assetClickableView: UIView!
    @IBOutlet weak var assetIconImageView: UIImageView!

    lazy var feeRateButtons = [fastFeeButton, mediumFeeButton, slowFeeButton, customFeeButton]

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
        reviewButton.updateGradientLayerFrame()
    }
}
