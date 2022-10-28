//
//  Copyright © 2021 Yahoo
//    

import Foundation
import BGSwift

class LoginExtent: BGExtent {
    let email: BGState<String>
    let password: BGState<String>
    let loginClick: BGMoment
    let emailValid: BGState<Bool>
    let passwordValid: BGState<Bool>
    let loginEnabled: BGState<Bool>
    let loggingIn: BGState<Bool>
    let loginComplete: BGTypedMoment<Bool>
    
    weak var loginForm: ViewController?
    var savedLoginBlock: ((Bool) -> Void)?
    
    init(graph: BGGraph) {
        let bld: BGExtentBuilder<LoginExtent> = BGExtentBuilder(graph: graph)
        email = bld.state("")
        password = bld.state("")
        loginClick = bld.moment()
        emailValid = bld.state(false)
        passwordValid = bld.state(false)
        loginEnabled = bld.state(false)
        loggingIn = bld.state(false)
        loginComplete = bld.typedMoment()

        
        bld.behavior()
            .supplies([emailValid])
            .demands([email, bld.added])
            .runs { extent in
                extent.emailValid.update(LoginExtent.validEmailAddress(extent.email.value))
                extent.sideEffect {
                    extent.loginForm?.emailFeedback.text = extent.emailValid.value ? "✅" : "❌"
                }
            }
        
        bld.behavior()
            .supplies([passwordValid])
            .demands([password, bld.added])
            .runs { extent in
                extent.passwordValid.update(extent.password.value.count > 0)
                extent.sideEffect {
                    extent.loginForm?.passwordFeedback.text = extent.passwordValid.value ? "✅" : "❌"
                }
            }
        
        bld.behavior()
            .supplies([loginEnabled])
            .demands([emailValid, passwordValid, loggingIn, bld.added])
            .runs { extent in
                let enabled = extent.emailValid.value && extent.passwordValid.value && !extent.loggingIn.value;
                extent.loginEnabled.update(enabled)
                extent.sideEffect {
                    extent.loginForm?.loginButton.isEnabled = extent.loginEnabled.value
                }
            }
        
        bld.behavior()
            .supplies([loggingIn])
            .demands([loginClick, loginComplete, bld.added])
            .runs { extent in
                if extent.loginClick.justUpdated() && extent.loginEnabled.traceValue {
                    extent.loggingIn.update(true)
                } else if extent.loginComplete.justUpdated() && extent.loggingIn.value {
                    extent.loggingIn.update(false)
                }
                
                if extent.loggingIn.justUpdated(to: true) {
                    extent.sideEffect {
                        extent.loginCall(email: extent.email.value, password: extent.password.value) { success in
                            
                            extent.graph.action {
                                extent.loginComplete.update(success)
                            }
                            
                        }
                    }
                }
            }
        
        bld.behavior()
            .demands([loggingIn, loginComplete, bld.added])
            .runs { extent in
                extent.sideEffect {
                    var status = ""
                    if extent.loggingIn.value {
                        status = "Logging in...";
                    } else if let loginComplete = extent.loginComplete.updatedValue {
                        if loginComplete {
                            status = "Login Success"
                        } else {
                            status = "Login Failed"
                        }
                    }
                    extent.loginForm?.loginStatus.text = status;
                }
            }
        
        super.init(builder: bld)

    }

    static func validEmailAddress(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let pred = NSPredicate(format: "SELF matches %@", regex)
        return pred.evaluate(with: email)
    }
    
    func loginCall(email: String, password: String, complete: @escaping (Bool) -> Void) {
        self.savedLoginBlock = complete
    }
    
    func completeLogin(success: Bool) {
        self.savedLoginBlock?(success)
        self.savedLoginBlock = nil
    }

}
