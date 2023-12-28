//
//  ViewController.swift
//  SeSACAppleLogin
//
//  Created by 황인호 on 12/28/23.
//

import UIKit
import AuthenticationServices
import KakaoSDKAuth
import KakaoSDKUser

/*
 소셜 로그인(페북/ 구글/ 카카오..), 애플 로그인 구현 필수(미구현 시 리젝사유)
 (ex. 인스타그램은 페북꺼니까(?) 애플 안붙여도 괜찮음!)
 자체 로그인만 구성이 되어 있다면, 애플 로그인 구현 필수 아님
 */

class MainViewController: UIViewController {
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .green
    }
}


class ViewController: UIViewController {

    @IBOutlet weak var appleLoginButton: ASAuthorizationAppleIDButton!
    
    
    @IBOutlet weak var profileImageView: UIImageView!
    
    @IBOutlet weak var infoLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        appleLoginButton.addTarget(self, action: #selector(appleLoginButtonClicked), for: .touchUpInside)
    }
    
    @IBAction func kakaoLoginButtonClicked(_ sender: UIButton) {
        if (UserApi.isKakaoTalkLoginAvailable()) {
            UserApi.shared.loginWithKakaoTalk {(oauthToken, error) in
                if let error = error {
                    print(error)
                }
                else {
                    print("loginWithKakaoTalk() success.")

                   let _ = oauthToken
                    let accessToken = oauthToken?.accessToken
                   
                   self.setUserInfo()
                }
            }
        }
    }
  private func setUserInfo() {
           UserApi.shared.me() {(user, error) in
               if let error = error {
                   print(error)
               }
               else {
                   print("me() success.")
                   //do something
                   _ = user
                   self.infoLabel.text = user?.kakaoAccount?.profile?.nickname
                   
                   if let url = user?.kakaoAccount?.profile?.profileImageUrl,
                       let data = try? Data(contentsOf: url) {
                       self.profileImageView.image = UIImage(data: data)
                   }
               }
           }
       }

    @objc func appleLoginButtonClicked() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
}

extension ViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    
}

extension ViewController: ASAuthorizationControllerDelegate {
    
    //애플로 로그인 실패한 경우
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Login Failed \(error.localizedDescription)")
    }
    
    //애플로 로그인 성공한 경우 -> 메인 페이지로 이동 등..
    
    // 처음 시도: 계속,
    // 두번째 시도: 로그인 할래요?, Email, fullname nil값으로 온다.
    // 사용자 정보를 계속 제공해 주지 않는다! 최초에만 제공
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            print(appleIDCredential)
            let userIdential = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            guard let token = appleIDCredential.identityToken,
                  let tokenToString = String(data: token, encoding: .utf8) else { print("Token Error")
                return
            }
            
            //UserDefaults
            print(userIdential)
            print(fullName ?? "No fullName")
            print(email ?? "No Email")
            print(tokenToString)
            
            if email?.isEmpty ?? false {
                let result = decode(jwtToken: tokenToString)["email"] as? String ?? ""
                print(result) //UserDefaults
            }
            
            //이메일, 토큰, 이름 -> UserDefaults & API로 서버에 POST
            //서버에 Request 후 Response를 받게 되면, 성공시 화면 전환
            
            UserDefaults.standard.setValue(userIdential, forKey: "User")
            
            DispatchQueue.main.async {
                self.present(MainViewController(), animated: true)
            }
            
        case let passwordCredential as ASPasswordCredential:
            
            let username = passwordCredential.user
            let password = passwordCredential.password

            print(username, password)
            
        default: break
        }
    }
}

private func decode(jwtToken jwt: String) -> [String: Any] {
    
    func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 = base64 + padding
        }
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
    
    func decodeJWTPart(_ value: String) -> [String: Any]? {
            guard let bodyData = base64UrlDecode(value),
                  let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any] else {
                return nil
            }

            return payload
        }
        
        let segments = jwt.components(separatedBy: ".")
        return decodeJWTPart(segments[1]) ?? [:]
    }
