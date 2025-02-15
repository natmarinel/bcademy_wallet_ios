import Foundation
import UIKit
import PromiseKit
import SwiftUI

enum DetailCellType: CaseIterable {
    case image
    case name
    case identifier
    case amount
    case precision
    case ticker
    case issuer
}

struct AssetData: Codable {
    let assetId: String
    let domain: String
    let name: String
    let nftContract: NftData?
}

struct NftData: Codable {
    let domain: String
    let media: MediaData?
    let meta: [MetaData?]
    let attachments: [AttachmentsData?]
}

struct MediaData: Codable {
    let fileUrl: String
    let contentType: String
}

struct MetaData: Codable {
    let language: String
    let name: String
    let description: String
}

struct AttachmentsData: Codable {
    let fileUrl: String
    let name: String
    let contentType: String
}


class DialogAssetDetailViewController: UIViewController {

    var nftBtender : AssetData?
    var tag: String!
    var asset: AssetInfo?
    var satoshi: UInt64?
    private var assetDetailCellTypes = DetailCellType.allCases
    private var isLBTC: Bool {
        get {
            return tag == getGdkNetwork("liquid").policyAsset
        }
    }
    private var assetsUpdatedToken: NSObjectProtocol?
    var obs: NSKeyValueObservation?

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var nftImageView: UIImageView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!

                    
    override func viewDidLoad() {
        
        btender(assetId: asset!.assetId){ (a) in
                self.nftBtender = a                
                }
        super.viewDidLoad()
        
        setContent()
        setStyle()
        
        view.alpha = 0.0
        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            self?.tableViewHeight.constant = table.contentSize.height
        }
    }

    func btender(assetId: String, completion: @escaping (_ assetData: AssetData) -> Void){
        let urlString = "https://btender.bcademy.xyz/api/v1/assets_contract/" + assetId;
        URLSession.shared.dataTask(with: URL(string: urlString)!, completionHandler: {data, response, error in
            guard let data = data, error == nil else {
                return
            }
            
            var result: AssetData?
            do {
                
                result = try JSONDecoder().decode(AssetData.self, from: data)
            }
            catch {
            }
            
            guard let json = result else {
                return
            }

            DispatchQueue.main.async {
                  self.tableView.reloadData()
             }
            
            completion(json)
            
        }).resume()
        
    }

    func setContent() {
        lblTitle.text = NSLocalizedString("id_asset_details", comment: "")
    }

    func setStyle() {
        cardView.layer.cornerRadius = 20
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isLBTC { assetDetailCellTypes.remove(at: 1) }
        assetsUpdatedToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.AssetsUpdated.rawValue), object: nil, queue: .main, using: onAssetsUpdated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = assetsUpdatedToken {
            NotificationCenter.default.removeObserver(token)
            assetsUpdatedToken = nil
        }
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

    func onAssetsUpdated(_ notification: Notification) {
        guard let session = SessionsManager.current else { return }
        Guarantee()
            .compactMap { Registry.shared.cache(session: session) }
            .done { self.tableView.reloadData() }
            .catch { err in
                print(err.localizedDescription)
        }
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(nil)
    }

    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        let tappedImage = tapGestureRecognizer.view

        // Your action
        let storyBoard : UIStoryboard = UIStoryboard(name: "Nft", bundle:nil)
        if let nextViewController = storyBoard.instantiateViewController(withIdentifier: "NftViewController") as? NftViewController {
            nextViewController.asset = asset
            nextViewController.nftBtender = nftBtender
            self.present(nextViewController, animated: true)
        }
        
    }

}

extension DialogAssetDetailViewController: UITableViewDelegate, UITableViewDataSource {

    
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
     
            if nftBtender?.assetId != nil {
                switch cellType {
                case .image:
                
                    let imageUrlString = "https://btender.bcademy.xyz" + nftBtender!.nftContract!.media!.fileUrl
                    let imageUrl:URL = URL(string: imageUrlString)!

                    // Start background thread so that image loading does not make app unresponsive
                    DispatchQueue.global(qos: .userInitiated).async {
                        let imageData:NSData =  NSData(contentsOf: imageUrl)!
                        //let imageView = UIImageView(frame: CGRect(x:0, y:-100, width:100, height:100))
                        //imageView.center = self.view.center
                        
                        // When from background thread, UI needs to be updated on main_queue
                        DispatchQueue.main.async {
                            let image = UIImage(data: imageData as Data)
                            self.nftImageView.contentMode = UIView.ContentMode.scaleAspectFit
                            self.nftImageView.frame = CGRect(x:(self.tableView.frame.width - 300)/2,y:self.tableView.frame.minY + 20 , width:300, height:250);
                            self.nftImageView.image = image
                            
                            
                            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped(tapGestureRecognizer:)))
                            self.nftImageView.isUserInteractionEnabled = true
                            self.nftImageView.addGestureRecognizer(tapGestureRecognizer)
                        }

                    }
                
                case .name:
                    cell.configure(NSLocalizedString("id_asset_name", comment: ""), isLBTC ? "Liquid Bitcoin" : asset?.name ?? NSLocalizedString("id_no_registered_name_for_this", comment: ""))
                case .identifier:
                    cell.configure("","")
                case .amount:
                    cell.configure("","")
                case .precision:
                    cell.configure("","")
                case .ticker:
                    cell.configure("","")
                case .issuer:
                    cell.configure("","")
                default:
                    cell.configure("","")
                }

            }
            else{
            
            switch cellType {
                case .name:
                    cell.configure(NSLocalizedString("id_asset_name", comment: ""), isLBTC ? "Liquid Bitcoin" : asset?.name ?? NSLocalizedString("id_no_registered_name_for_this", comment: ""))
                case .identifier:
                    cell.configure(NSLocalizedString("id_asset_id", comment: ""), tag)
                case .amount:
                    if nftBtender?.assetId == nil {
                        var assetInfo = asset ?? AssetInfo(assetId: tag, name: tag, precision: 0, ticker: "")
                        var balance = Balance.convert(details: ["satoshi": satoshi ?? 0, "asset_info": assetInfo.encode()!])
                        cell.configure(NSLocalizedString("id_total_balance", comment: ""), balance?.get(tag: tag).0 ?? "")
                    }
                    else {
                        cell.configure("", "")
                    }
                case .precision:
                    cell.configure(NSLocalizedString("id_precision", comment: ""), isLBTC ? "8" : String(asset?.precision ?? 0))
                case .ticker:
                    cell.configure(NSLocalizedString("id_ticker", comment: ""), isLBTC ? "L-BTC" : asset?.ticker ?? NSLocalizedString("id_no_registered_ticker_for_this", comment: ""))
                case .issuer:
                    cell.configure(NSLocalizedString("id_issuer", comment: ""), isLBTC ? NSLocalizedString("id_lbtc_has_no_issuer_and_is", comment: "") : asset?.entity?.domain ?? NSLocalizedString("id_unknown", comment: ""))

                default:
                    cell.configure("","")
                }
            }
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if assetDetailCellTypes[indexPath.row] == .issuer && isLBTC {
            if let url = URL(string: "https://docs.blockstream.com/liquid/technical_overview.html#watchmen") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }
}
