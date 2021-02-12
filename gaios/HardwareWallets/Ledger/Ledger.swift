import Foundation
import RxSwift
import RxBluetoothKit
import CoreBluetooth

final class Ledger: LedgerCommands, HWResolverProtocol {
    public static let shared = Ledger()

    let hwDevice: [String: Any] = ["name": "Ledger", "supports_arbitrary_scripts": true, "supports_low_r": false]
    var xPubsCached = [String: String]()
    let SIGHASH_ALL: UInt8 = 1
    var connected: Bool { get { !self.xPubsCached.isEmpty }}

    func signTransaction(tx: [String: Any], inputs: [[String: Any]], outputs: [[String: Any]],
                         transactions: [String: String], addressTypes: [String]) -> Observable<[String]> {
        return signSW(tx: tx, inputs: inputs, outputs: outputs)
    }

    func signSW(tx: [String: Any], inputs: [[String: Any]], outputs: [[String: Any]]) -> Observable<[String]> {
        let hwInputs = inputs.map { input -> [String: Any] in
            let bytes = inputBytes(input, isSegwit: true)!
            let sequence = (input["sequence"] as? UInt)!.uint32LE()
            return ["value": bytes, "sequence": Data(sequence), "trusted": false, "segwit": true]
        }
        // Prepare the pseudo transaction
        // Provide the first script instead of a null script to initialize the P2SH confirmation logic
        let version = tx["transaction_version"] as? UInt
        let prevoutScript = inputs.first?["prevout_script"] as? String
        let script0 = hexToData(prevoutScript!)
        let locktime = tx["transaction_locktime"] as? UInt
        return startUntrustedTransaction(txVersion: version!, newTransaction: true, inputIndex: 0, usedInputList: hwInputs, redeemScript: script0, segwit: true)
        .flatMap { _ -> Observable<[String: Any]> in
            let bytes = self.outputBytes(outputs)
            return self.finalizeInputFull(data: bytes!)
        }.flatMap { _ -> Observable<[Data]> in
            return self.signSWInputs(hwInputs: hwInputs, inputs: inputs, version: version!, locktime: locktime!)
        }.flatMap { sigs -> Observable<[String]> in
            var strings = [String]()
            for sig in sigs {
                let string = Array(sig).map { String(format: "%02hhx", $0) }.joined()
                strings.append(string)
            }
            return Observable.just(strings)
        }
    }

    func signSWInputs(hwInputs: [[String: Any]], inputs: [[String: Any]], version: UInt, locktime: UInt) -> Observable<[Data]> {
        let allObservables = hwInputs
            .enumerated()
            .map { hwInput -> Observable<Data> in
                return Observable.just(hwInput.element)
                    .flatMap { _ in self.signSWInput(hwInput: hwInput.element, input: inputs[hwInput.offset], version: version, locktime: locktime) }
                    .asObservable()
                    .take(1)
        }
        return Observable.concat(allObservables).reduce([], accumulator: { result, element in
            result + [element]
        })
    }

    func signSWInput(hwInput: [String: Any], input: [String: Any], version: UInt, locktime: UInt) -> Observable<Data> {
        let prevoutScript = input["prevout_script"] as? String
        let script = hexToData(prevoutScript!)
        return startUntrustedTransaction(txVersion: version, newTransaction: false, inputIndex: 0, usedInputList: [hwInput], redeemScript: script, segwit: true)
        .flatMap { _ -> Observable <Data> in
            let paths = input["user_path"] as? [Int64]
            let userPaths: [Int] = paths!.map { Int($0) }
            return self.untrustedHashSign(privateKeyPath: userPaths, pin: "0", lockTime: locktime, sigHashType: self.SIGHASH_ALL)
        }
    }

    func signMessage(path: [Int], message: String) -> Observable<String> {
        return signMessagePrepare(path: path, message: message.data(using: .utf8) ?? Data())
            .flatMap { _ in self.signMessageSign(pin: [0])}
            .flatMap { res -> Observable<String> in
                let signature = res["signature"] as? [UInt8]
                let hexSig = signature!.map { String(format: "%02hhx", $0) }.joined()
                return Observable.just(hexSig)
        }
    }

    func xpubs(paths: [[Int]]) -> Observable<[String]> {
        let allObservables = paths
            .map {
                Observable.just($0)
                    .flatMap { self.xpubs(path: $0) }
                    .asObservable()
                    .take(1)
        }
        return Observable.concat(allObservables)
        .reduce([], accumulator: { result, element in
            result + [element]
        })
    }

    func xpubs(path: [Int]) -> Observable<String> {
        let key = path.map { String($0) }.joined(separator: "/")
        if let base58 = xPubsCached[key] {
            return Observable.just(base58)
        }
        let isMainnet = getGdkNetwork(getNetwork()).mainnet
        return self.pubKey(path: path)
            .flatMap { data -> Observable<String> in
                let chainCode = Array((data["chainCode"] as? Data)!)
                let publicKey = Array((data["publicKey"] as? Data)!)
                let compressed = try! compressPublicKey(publicKey)
                let base58 = try! bip32KeyToBase58(isMainnet: isMainnet, pubKey: compressed, chainCode: chainCode)
                self.xPubsCached[key] = base58
                return Observable.just(base58)
        }
    }

    func newReceiveAddress(network: String, subaccount: UInt32, branch: UInt32, pointer: UInt32, recoveryChainCode: String?, recoveryPubKey: String?, csvBlocks: UInt32) -> Observable<String> {
        return Observable.error(JadeError.Abort(""))
    }

    // Liquid not support
    func getBlindingKey(scriptHex: String) -> Observable<String?> {
        return Observable.error(JadeError.Abort(""))
    }

    func getBlindingNonce(pubkey: String, scriptHex: String) -> Observable<String?> {
        return Observable.error(JadeError.Abort(""))
    }

    func signLiquidTransaction(pubkey: String, scriptHex: String) -> Observable<String?> {
        return Observable.error(JadeError.Abort(""))
    }

    func signLiquidTransaction(inputs: [[String: Any]], outputs: [[String: Any]], transactions: [String: String], addressTypes: [String]) -> Observable<LiquidHWResult> {
        return Observable.error(JadeError.Abort(""))
    }

    func nonces(bscripts: [[String: Any]]) -> Observable<[String?]> {
        return Observable.error(JadeError.Abort(""))
    }

    func blindingKey(scriptHex: String) -> Observable<String?> {
        return Observable.error(JadeError.Abort(""))
    }
    func getSharedNonce(pubkey: String, scriptHex: String) -> Observable<String?> {
        return Observable.error(JadeError.Abort(""))
    }

}
