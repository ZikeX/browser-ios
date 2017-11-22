//
//  SurfViewController.swift
//  DashboardComponent
//
//  Created by Tim Palade on 8/11/17.
//  Copyright © 2017 Tim Palade. All rights reserved.
//

import UIKit

final class SurfViewController: UIViewController {
    
    private var controllers: [UIViewController] = []
    private var current: Int = 0
    
    private enum Position {
        case center
        case right
        case left
    }
    
    init(viewControllers: [UIViewController], initial: Int = 0) {
        super.init(nibName: nil, bundle: nil)
        self.controllers = viewControllers
        self.current = initial
        setUpComponent()
        setStyling()
        setConstraints()
    }
    
    private func setUpComponent() {
        for controller in controllers {
            addController(viewController: controller)
        }
    }
    
    private func setStyling() {
        self.view.backgroundColor = .clear
    }
    
    private func setConstraints() {
        
        for i in 0..<controllers.count {
            let controller = controllers[i]
            if i == current{
                put(view: controller.view, position: .center)
            }
            else if i < current {
                put(view: controller.view, position: .left)
            }
            else {
                put(view: controller.view, position: .right)
            }
        }
        
    }
    
    func showNext(animated: Bool) {
        if isWithinBounds(number: current + 1) {
            if let currentView = controllers[current].view, let nextView = controllers[current + 1].view {
                show(view: currentView, position: .left, animated: animated)
                show(view: nextView, position: .center, animated: animated)
                
                current += 1
            }
        }
    }
    
    func showPrev(animated: Bool) {
        if isWithinBounds(number: current - 1) {
            if let currentView = controllers[current].view, let prevView = controllers[current - 1].view {
                show(view: currentView, position: .right, animated: animated)
                show(view: prevView, position: .center, animated: animated)
                
                current -= 1
            }
        }
    }
    
    private func show(view: UIView, position: Position, animated: Bool) {
        if animated {
            UIViewPropertyAnimator.init(duration: 0.24, curve: .easeInOut) {
                self.put(view: view, position: position)
                self.view.layoutIfNeeded()
            }.startAnimation()
        }
        else {
            self.put(view: view, position: position)
            self.view.layoutIfNeeded()
        }
    }
    
    private func put(view: UIView, position: Position) {
        if position == .center {
            
            view.alpha = 1.0
            
            view.snp.remakeConstraints({ (make) in
                make.top.bottom.equalToSuperview()
                make.width.equalToSuperview()
                make.centerX.equalToSuperview()
            })
        }
        else if position == .left {
            
            view.alpha = 0.0
            
            view.snp.remakeConstraints({ (make) in
                make.top.bottom.equalToSuperview()
                make.width.equalToSuperview()
                make.right.equalTo(self.view.snp.left)
            })
        }
        else if position == .right {
            
            view.alpha = 0.0
            
            view.snp.remakeConstraints({ (make) in
                make.top.bottom.equalToSuperview()
                make.width.equalToSuperview()
                make.left.equalTo(self.view.snp.right)
            })
        }
    }
    
    private func addController(viewController: UIViewController) {
        self.addChildViewController(viewController)
        self.view.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
    }

    private func removeController(viewController: UIViewController) {
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
    }

    private func isWithinBounds(number: Int)-> Bool {
        if number < controllers.count && number >= 0 {
            return true
        }
        
        return false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
