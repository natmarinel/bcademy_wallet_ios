import Foundation

class SessionsManager {

    static var shared = [String: SessionManager]()

    static var current: SessionManager? {
        guard let account = AccountsManager.shared.current else {
            fatalError("no account selected or found")
        }
        return get(for: account)
    }

    static func get(for account: Account) -> SessionManager? {
        if shared.contains(where: { $0.0 == account.id }) {
            return shared[account.id]
        }
        return nil
    }

    static func new(for account: Account) -> SessionManager {
        if let session = shared[account.id] {
            session.destroy()
        }
        let session = SessionManager(account: account)
        shared[account.id] = session
        return session
    }

    static func remove(for account: Account) {
        shared.removeValue(forKey: account.id)
    }
}
