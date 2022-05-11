import Foundation
import UIKit
import PromiseKit
import SwiftUI

enum NftCellType: CaseIterable {
    case name
    case assetId
    case domain
    case description
}

class NftViewController: UIViewController {

    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var nftImage: UIImageView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    private var assetDetailCellTypes = NftCellType.allCases
    var asset: AssetInfo?
    var nftBtender: AssetData?
    var obs: NSKeyValueObservation?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.alpha = 0.0
        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            self?.tableViewHeight.constant = table.contentSize.height
        }
        let imageUrlString = "https://btender.bcademy.xyz" + nftBtender!.nftContract!.media!.fileUrl
        let imageUrl:URL = URL(string: imageUrlString)!
        // Start background thread so that image loading does not make app unresponsive
        DispatchQueue.global(qos: .userInitiated).async {
            let imageData:NSData =  NSData(contentsOf: imageUrl)!
            
            // When from background thread, UI needs to be updated on main_queue
            DispatchQueue.main.async {
                let image = UIImage(data: imageData as Data)
                self.nftImage.image = image
               
            }

        }
       
    }

    
        

    func setContent() {
    }

    func setStyle() {
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss(_ value: MnemonicLengthOption?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(nil)
    }

    func onAssetsUpdated(_ notification: Notification) {
        guard let session = SessionsManager.current else { return }
        Guarantee()
            .compactMap { Registry.shared.cache(session: session) }
            .done { self.tableView.reloadData() }
            .catch { err in
                print(err.localizedDescription)
        }
    }

    

    

}

extension NftViewController: UITableViewDelegate, UITableViewDataSource {

    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assetDetailCellTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetDetailCell") as? AssetDetailCell {
            cell.selectionStyle = .none
            let cellType = assetDetailCellTypes[indexPath.row]
            switch cellType {
                case .name:
                    cell.configure(String("Title"), asset?.name ?? NSLocalizedString("id_no_registered_name_for_this", comment: ""))
                case .assetId:
                    cell.configure(String("Asset Id"), nftBtender!.assetId )
                case .domain:
                    cell.configure(String("Domain"), nftBtender!.domain )
                case .description:
                    cell.configure(String("Description"), nftBtender?.nftContract?.meta[0]?.description ?? String("No description")  )
            }
            return cell
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

}
