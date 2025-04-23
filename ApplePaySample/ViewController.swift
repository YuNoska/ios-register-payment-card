import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    @IBAction func applePayButtonTapped(_ sender: UIButton) {
        
        let applePayService = ApplePayService(presentingViewController: self)
        applePayService.startProvisioning(
            cardholderName: "山田 太郎",
            primaryAccountSuffix: "1234",
            localizedDescription: "クレジットカード",
            paymentNetwork: .visa,
            encryptedCardData: Data() // 暗号化されたカードデータをここに設定
        ) { success, error in
            if success {
                print("カードの追加に成功しました。")
                return
            }
            print("カードの追加に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
        }
    }
}

import PassKit

class ApplePayService: NSObject {

    private weak var presentingViewController: UIViewController?
    private var completion: ((Bool, Error?) -> Void)?

    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }

    func startProvisioning(
        cardholderName: String,
        primaryAccountSuffix: String,
        localizedDescription: String,
        paymentNetwork: PKPaymentNetwork,
        encryptedCardData: Data,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        self.completion = completion

        
        guard PKAddPaymentPassViewController.canAddPaymentPass() else {
            // Apple Pay登録不可
            completion(
                false,
                NSError(
                    domain: "ApplePayService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "このデバイスではカードを追加できません。"]
                )
            )
            return
        }

        /**
            PKAddPaymentPassRequestConfiguration
            https://developer.apple.com/documentation/passkit/pkaddpaymentpassrequestconfiguration
         */
        // 暗号化スキーム
        // https://developer.apple.com/documentation/passkit/pkencryptionscheme
        let configuration = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)
        // カード所有者名
        configuration?.cardholderName = cardholderName
        // プライマリアカウントのサフィックス
        configuration?.primaryAccountSuffix = primaryAccountSuffix
        configuration?.localizedDescription = localizedDescription
        // https://developer.apple.com/documentation/passkit/pkaddpaymentpassrequestconfiguration/paymentnetwork
        configuration?.paymentNetwork = paymentNetwork

        guard
            let _configuration = configuration,
            // https://developer.apple.com/documentation/passkit/pkaddpaymentpassviewcontroller
            let addPaymentPassVC = PKAddPaymentPassViewController(requestConfiguration: _configuration, delegate: self)
        else {
            completion(
                false,
                NSError(
                    domain: "ApplePayService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "PKAddPaymentPassViewControllerの初期化に失敗しました。"]
                )
            )
            return
        }

        presentingViewController?.present(addPaymentPassVC, animated: true, completion: nil)
    }
}

// https://developer.apple.com/documentation/passkit/pkaddpaymentpassviewcontrollerdelegate
extension ApplePayService: PKAddPaymentPassViewControllerDelegate {
    
    func addPaymentPassViewController(_ controller: PKAddPaymentPassViewController,
                                      generateRequestWithCertificateChain certificates: [Data],
                                      nonce: Data,
                                      nonceSignature: Data,
                                      completionHandler handler: @escaping (PKAddPaymentPassRequest) -> Void) {
        // カード発行会社のAPIに必要な情報を送信し、暗号化されたカード情報を取得
        // ここでは、既に取得済みのencryptedCardDataを使用

        let request = PKAddPaymentPassRequest()
        request.encryptedPassData = Data() //encryptedCardData
        request.activationData = Data() // 必要に応じて設定
        request.ephemeralPublicKey = Data() // 必要に応じて設定

        handler(request)
    }

    func addPaymentPassViewController(_ controller: PKAddPaymentPassViewController,
                                      didFinishAdding pass: PKPaymentPass?,
                                      error: Error?) {
        controller.dismiss(animated: true) {
            self.completion?(error == nil, error)
        }
    }
}
