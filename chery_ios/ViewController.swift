//
//  ViewController.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import QXWebView
class ViewController: UIViewController {
    
 
     required init?(coder: NSCoder) {
         super.init(coder: coder)
     }
     
   
     init() {
         super.init(nibName: nil, bundle: nil)
     }
     

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.view.backgroundColor = .red
        
        self.view.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer.init()
        tap.addTarget(self, action: #selector(viewClickAction))
        self.view.addGestureRecognizer(tap)
        
        
        let vc = QXWebViewController.init(url: "https://fr.dongxie.top/fr/#/")
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    // MARK: - 视图点击事件 (跳转网页VC)
    @objc private func viewClickAction() {
        let vc = QXWebViewController.init(url: "https://fr.dongxie.top/fr/#/")
        self.navigationController?.pushViewController(vc, animated: true)
    }

}

