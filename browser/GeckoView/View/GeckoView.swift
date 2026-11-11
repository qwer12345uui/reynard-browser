//
//  GeckoView.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import UIKit

public class GeckoView: UIView {
    public weak var interactionDelegate: GeckoViewInteractionDelegate? {
        didSet {
            session?.window?.setInteractionDelegate(interactionDelegate)
        }
    }
    
    public weak var keyCommandDelegate: GeckoViewKeyCommandDelegate? {
        didSet {
            session?.window?.setKeyCommandDelegate(keyCommandDelegate)
        }
    }
    
    public var session: GeckoSession? {
        didSet {
            oldValue?.window?.setInteractionDelegate(nil)
            oldValue?.window?.setKeyCommandDelegate(nil)
            embedSessionView()
            session?.window?.setInteractionDelegate(interactionDelegate)
            session?.window?.setKeyCommandDelegate(keyCommandDelegate)
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        session?.window?.setInteractionDelegate(nil)
        session?.window?.setKeyCommandDelegate(nil)
    }
    
    private func embedSessionView() {
        subviews.forEach { $0.removeFromSuperview() }
        
        guard let session else {
            return
        }
        
        guard let window = session.window else {
            NSLog("GeckoView: session window is unavailable during assignment")
            return
        }
        
        guard let engineView = window.view() else {
            NSLog("GeckoView: session window has no view!")
            return
        }
        
        if engineView.superview != nil {
            fatalError("attempt to assign GeckoSession to multiple GeckoView instances")
        }
        
        engineView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(engineView)
        
        NSLayoutConstraint.activate([
            engineView.topAnchor.constraint(equalTo: topAnchor),
            engineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            engineView.bottomAnchor.constraint(equalTo: bottomAnchor),
            engineView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        setNeedsLayout()
        layoutIfNeeded()
    }
}
