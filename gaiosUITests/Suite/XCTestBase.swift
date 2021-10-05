import XCTest
@testable import gaios

class XCTestBase: XCTestCase {
    
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func restoreWallet(walletName: String, words: [String], isSingleSig: Bool) {
        
        Home()
            .tapAddWalletView()
        
        Landing()
            .tapAcceptTerms()
            .pause(1)
            .tapRestoreWallet()
        
        RestoreWallet()
            .tapRestoreCard()
        
        ChooseNetwork()
            .tapTestnetCard()
    
        if isSingleSig {
            ChooseSecurity()
                .tapSingleSigCard()
        } else {
            ChooseSecurity()
                .tapMultiSigCard()
        }

        
        RecoveryPhrase()
            .tapPhraseCard()
        
        Mnemonic()
            .pause(1)
            .typeWords(words)
            .closeKey()
            .pause(1)
            .tapDone()
        
        WalletName()
            .pause(1)
            .typeName(walletName)
            .pause(1)
            .closeKey()
            .pause(1)
            .tapNext()
            .pause(1)
        
        SetPin()
            .pause(1)
            .setPin()
            .pause(1)
            .setPin()
            .tapNext()
        
        WalletSuccess()
            .pause(1)
            .tapNext()
            
        Overview()
            .pause(1)
    }
    
    func setTor(_ value: Bool) {
        
        Home()
            .tapAddWalletView()
        
        Landing()
            .tapAcceptTerms()
            .pause(1)
            .tapNewWallet()
        
        ChooseNetwork()
            .tapTestnetCard()
    
        ChooseSecurity()
            .tapMultiSigCard()
            
        RecoveryInstructions()
            .tapContinue()
        
        RecoveryCreate()
            .cleanWords()
            .readWords()
            .pause(1)
            .tapNext()
            .pause(1)
            .readWords()
            .pause(1)
            .tapNext()
            .pause(1)
        
        RecoveryVerify()
            .pause(1)
            .chooseWord()
            .pause(1)
            .chooseWord()
            .pause(1)
            .chooseWord()
            .pause(1)
        
        RecoverySuccess()
            .pause(1)
            .tapNext()

        WalletName()
            .pause(1)
            .tapSettings()

        WalletSettings()
            .pause(1)


        if WalletSettings().isTorSetTo(value) {

            WalletSettings()
                .pause(1)
                .tapCancel()
        } else {

            WalletSettings()
                .tapTorSwitch()
                .pause(1)
                .tapSave()
        }
        
    }
}
