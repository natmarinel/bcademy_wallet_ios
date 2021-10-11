import Foundation
import PromiseKit

class SessionManager: Session {

    static var shared = SessionManager()

    var account: Account?
    var connected = false
    var notificationManager: NotificationManager
    var twoFactorConfig: TwoFactorConfig?
    var settings: Settings?

    var isResetActive: Bool? {
        get { twoFactorConfig?.twofactorReset.isResetActive }
    }

    var activeWallet: UInt32 {
        get {
            let pointerKey = String(format: "%@_wallet_pointer", self.account?.id ?? "")
            let pointer = UserDefaults.standard.integer(forKey: pointerKey)
            return UInt32(pointer)
        }
        set {
            let pointerKey = String(format: "%@_wallet_pointer", self.account?.id ?? "")
            UserDefaults.standard.set(Int(newValue), forKey: pointerKey)
            UserDefaults.standard.synchronize()
        }
    }

    public init() {
        notificationManager = NotificationManager()
        try! super.init(notificationCompletionHandler: notificationManager.newNotification)
    }

    public static func newSession() -> SessionManager {
        // Todo: destroy the session in a thread-safe way
        //SessionManager.shared = SessionManager()
        let session = SessionManager.shared
        try? session.disconnect()
        session.connected = false
        session.twoFactorConfig = nil
        session.settings = nil
        return SessionManager.shared
    }

    public func connect(_ account: Account) throws {
        self.account = account
        try connect(network: account.networkName)
    }

    public func connect(network: String, params: [String: Any]? = nil) throws {
        let networkSettings = params ?? getUserNetworkSettings()
        let useProxy = networkSettings["proxy"] as? Bool ?? false
        let socks5Hostname = useProxy ? networkSettings["socks5_hostname"] as? String ?? "" : ""
        let socks5Port = useProxy ? networkSettings["socks5_port"] as? String ?? "" : ""
        let useTor = getGdkNetwork(network).serverType == "green" ? networkSettings["tor"] as? Bool ?? false : false
        let proxyURI = useProxy ? String(format: "socks5://%@:%@/", socks5Hostname, socks5Port) : ""
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? CVarArg ?? ""
        let userAgent = String(format: "green_ios_%@", version)
        var netParams: [String: Any] = ["name": network, "use_tor": useTor, "proxy": proxyURI, "user_agent": userAgent]
        #if DEBUG
        netParams["log_level"] = "debug"
        #endif
        do {
            try super.connect(netParams: netParams)
            connected = true
        } catch {
            throw AuthenticationTypeHandler.AuthError.ConnectionFailed
        }
    }

    func transactions(first: UInt32 = 0) -> Promise<Transactions> {
        let bgq = DispatchQueue.global(qos: .background)
        let pointer = activeWallet
        return Guarantee().then(on: bgq) {_ in
            try SessionManager.shared.getTransactions(details: ["subaccount": pointer, "first": first, "count": Constants.trxPerPage]).resolve()
        }.compactMap(on: bgq) { data in
            let result = data["result"] as? [String: Any]
            let dict = result?["transactions"] as? [[String: Any]]
            let list = dict?.map { Transaction($0) }
            return Transactions(list: list ?? [])
        }
    }

    func subaccount() -> Promise<WalletItem> {
        let bgq = DispatchQueue.global(qos: .background)
        let pointer = activeWallet
        return Guarantee().then(on: bgq) {
            try self.getSubaccount(subaccount: pointer).resolve()
        }.recover {_ in
            return Guarantee().compactMap { [self] in
                activeWallet = 0
            }.then(on: bgq) {
                try self.getSubaccount(subaccount: 0).resolve()
            }
        }.compactMap(on: bgq) { data in
            let result = data["result"] as? [String: Any]
            let jsonData = try JSONSerialization.data(withJSONObject: result ?? [:])
            return try JSONDecoder().decode(WalletItem.self, from: jsonData)
        }
    }

    func subaccounts() -> Promise<[WalletItem]> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().then(on: bgq) {
            try self.getSubaccounts().resolve()
        }.compactMap(on: bgq) { data in
            let result = data["result"] as? [String: Any]
            let subaccounts = result?["subaccounts"] as? [[String: Any]]
            let jsonData = try JSONSerialization.data(withJSONObject: subaccounts ?? [:])
            let wallets = try JSONDecoder().decode([WalletItem].self, from: jsonData)
            return wallets
        }
    }

    func loadTwoFactorConfig() -> Promise<TwoFactorConfig> {
        guard let acc = AccountsManager.shared.current, !acc.isWatchonly else {
            return Promise<TwoFactorConfig> { seal in seal.reject(GaError.GenericError) }
        }
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().compactMap(on: bgq) {
            try SessionManager.shared.getTwoFactorConfig()
        }.compactMap { dataTwoFactorConfig in
            let twoFactorConfig = try JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig, options: []))
            self.twoFactorConfig = twoFactorConfig
            return twoFactorConfig
        }
    }

    func loadSettings() -> Promise<Settings> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().compactMap(on: bgq) {
            try SessionManager.shared.getSettings()
        }.compactMap { data in
            self.settings = Settings.from(data)
            return self.settings
        }
    }

    func loadSystemMessage() -> Promise<String> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().map(on: bgq) {
            try SessionManager.shared.getSystemMessage()
        }
    }

    func login(details: [String: Any], hwDevice: HWDevice? = nil)-> Promise<Void> {
        guard let hwDevice = hwDevice,
            let data = try? JSONEncoder().encode(hwDevice),
            let device = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
                return Promise<Void> { seal in seal.reject(GaError.GenericError) }
        }
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().then(on: bgq) {
                try super.loginUser(details: details, hw_device: ["device": device]).resolve()
            }.then { _ in
                self.loadTwoFactorConfig()
            }.then { _ -> Promise<Void> in
                if self.account?.network == "liquid" {
                    return Registry.shared.load()
                }
                return Promise<Void>()
            }
    }
}
