import Foundation
import UIKit
import PromiseKit

class PgpViewController: KeyboardViewController {

    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var textarea: UITextView!
    @IBOutlet weak var btnSave: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_pgp_key", comment: "")
        subtitle.text = NSLocalizedString("id_enter_a_pgp_public_key_to_have", comment: "")
        textarea.text = SessionsManager.current?.settings?.pgp ?? ""
        btnSave.setTitle(NSLocalizedString("id_save", comment: ""), for: .normal)
        btnSave.addTarget(self, action: #selector(save), for: .touchUpInside)
        setStyle()
    }

    func setStyle() {
        btnSave.setStyle(.primary)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textarea.becomeFirstResponder()
    }

    @objc func save(_ sender: UIButton) {
        guard let session = SessionsManager.current,
              let settings = session.settings else { return }
        let bgq = DispatchQueue.global(qos: .background)
        let value = settings.pgp
        settings.pgp = textarea.text
        firstly {
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings), options: .allowFragments) as? [String: Any]
        }.compactMap(on: bgq) { details in
            try session.changeSettings(details: details)
        }.then(on: bgq) { call in
            call.resolve()
        }.ensure {
            self.stopAnimating()
        }.done {_ in
            self.navigationController?.popViewController(animated: true)
        }.catch {_ in
            settings.pgp = value
            let alert = UIAlertController(title: NSLocalizedString("id_pgp_key", comment: ""), message: NSLocalizedString("id_invalid_pgp_key", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in
            })
            self.present(alert, animated: true, completion: nil)
        }
    }
}
