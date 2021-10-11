//
//  Copyright © 2021 Yahoo
//

import UIKit
import BGSwift

class ViewController: UIViewController {

    @IBOutlet var emailField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var loginButton: UIButton!
    @IBOutlet var emailFeedback: UILabel!
    @IBOutlet var passwordFeedback: UILabel!
    @IBOutlet var loginStatus: UILabel!
    @IBOutlet var loginSuccess: UIButton!
    @IBOutlet var loginFail: UIButton!

    let graph: BGGraph
    let loginExtent: LoginExtent
    
    required init?(coder: NSCoder) {
        graph = BGGraph()
        loginExtent = LoginExtent(graph: graph)
        super.init(coder: coder)
        loginExtent.loginForm = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loginExtent.addToGraphWithAction()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func didUpdateEmailField(sender: UITextField) {
        graph.action {
            self.loginExtent.email.update(self.emailField.text ?? "")
        }
    }
    
    @IBAction func didUpdatePasswordField(sender: UITextField) {
        graph.action {
            self.loginExtent.password.update(self.passwordField.text ?? "")
        }
    }

    @IBAction func loginButtonClicked(sender: UIButton) {
        graph.action {
            self.loginExtent.loginClick.update()
        }
    }
    
    @IBAction func loginSucceeded(sender: UIButton) {
        loginExtent.completeLogin(success: true)
    }
    
    @IBAction func loginFailed(sender: UIButton) {
        loginExtent.completeLogin(success: false)
    }
}
