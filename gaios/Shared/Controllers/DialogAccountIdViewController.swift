import Foundation
import UIKit
import PromiseKit

class DialogAccountIdViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblAccountId: UILabel!

    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    var wallet: WalletItem?
    var buttonConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        lblTitle.text = NSLocalizedString("id_amp_id", comment: "")
        lblHint.text = "Provide this ID to the asset issuer if requested"
        cardView.layer.cornerRadius = 20
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.alpha = 0.0

        lblAccountId.text = wallet?.receivingId ?? ""
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss()
    }

    @IBAction func btnCopy(_ sender: Any) {
        if let address = lblAccountId.text {
            UIPasteboard.general.string = address
            DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 2.0)
            dismiss()
        }
    }
}
