import UIKit

class TransactionAmountCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblRecipient: UILabel!

    private var btc: String {
        return AccountsManager.shared.current?.gdkNetwork?.getFeeAsset() ?? ""
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.layer.cornerRadius = 5.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        lblAmount.text = ""
        lblAsset.text = ""
        self.icon.image = UIImage()
        lblFiat.isHidden = true
        lblRecipient.isHidden = true
    }

    func configure(transaction: Transaction, network: String?, index: Int) {

        let isIncoming = transaction.type == "incoming"
        let isOutgoing = transaction.type == "outgoing"
        let color: UIColor = isOutgoing ? UIColor.white : UIColor.customMatrixGreen()

        lblTitle.text = NSLocalizedString("id_recipient", comment: "")
        if isIncoming {
            lblTitle.text = NSLocalizedString("id_received", comment: "")
            lblRecipient.isHidden = true
        }
        lblRecipient.text = transaction.address()
        lblAmount.textColor = color
        lblFiat.textColor = color

        if network == "mainnet" {
            icon.image = UIImage(named: "ntw_btc")
        } else if network == "testnet" {
            icon.image = UIImage(named: "ntw_testnet")
        } else {
            icon.image = Registry.shared.image(for: transaction.defaultAsset)
        }

        if transaction.defaultAsset == btc {
            if let balance = Balance.convert(details: ["satoshi": transaction.satoshi]) {
                let (amount, denom) = balance.get(tag: btc)
                lblAmount.text = String(format: "%@", amount ?? "")
                lblAsset.text = "\(denom)"
                if let fiat = balance.fiat {
                    lblFiat.text = "≈ \(fiat) \(balance.fiatCurrency)"
                }
                let (fiat, fiatCurrency) = balance.get(tag: "fiat")
                lblFiat.text = "≈ \(fiat ?? "N.A.") \(fiatCurrency)"
            }
        } else {
            let amounts = Transaction.sort(transaction.amounts)
            if let amount = isIncoming ? amounts[index] : amounts.filter({ $0.key == transaction.defaultAsset}).first {
                let info = Registry.shared.infos[amount.key]
                let icon = Registry.shared.image(for: amount.key)
                let tag = amount.key
                let asset = info ?? AssetInfo(assetId: tag, name: tag, precision: 0, ticker: "")
                let satoshi = transaction.amounts[amount.key] ?? 0
                let details = ["satoshi": satoshi, "asset_info": asset.encode()!] as [String: Any]

                if let balance = Balance.convert(details: details) {
                    let (amount, denom) = balance.get(tag: tag)
                    lblAmount.text = String(format: "%@", amount ?? "")
                    lblAsset.text = denom
                    self.icon.image = icon
                    lblFiat.isHidden = true
                    lblRecipient.isHidden = true
                }
            }
        }
    }
}