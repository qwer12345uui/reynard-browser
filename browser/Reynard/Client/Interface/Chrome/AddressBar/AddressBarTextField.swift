//
//  AddressBarTextField.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class AddressBarTextField: UITextField {
    var isAutocompleteActive = false
    var isSuggestionNavigationEnabled: (() -> Bool)?
    var onMoveSuggestionSelection: ((Int) -> Void)?
    var onDismissEditing: (() -> Void)?
    var onTextInteraction: (() -> Void)?
    
    private lazy var previousSuggestionCommand = makeSuggestionCommand(
        input: UIKeyCommand.inputUpArrow,
        action: #selector(selectPreviousSuggestion(_:))
    )
    private lazy var nextSuggestionCommand = makeSuggestionCommand(
        input: UIKeyCommand.inputDownArrow,
        action: #selector(selectNextSuggestion(_:))
    )
    private lazy var dismissEditingCommand: UIKeyCommand = {
        let command = UIKeyCommand(
            input: UIKeyCommand.inputEscape,
            modifierFlags: [],
            action: #selector(dismissEditing(_:))
        )
        if #available(iOS 15.0, *) {
            command.wantsPriorityOverSystemBehavior = true
        }
        return command
    }()
    
    override var keyCommands: [UIKeyCommand]? {
        let commands = (super.keyCommands ?? []) + [dismissEditingCommand]
        guard isSuggestionNavigationEnabled?() == true else {
            return commands
        }
        return commands + [previousSuggestionCommand, nextSuggestionCommand]
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Clear the visual suggestion before UIKit calculates the insertion
        // point, then pass through the original touch for native caret control.
        onTextInteraction?()
        super.touchesBegan(touches, with: event)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(dismissEditing(_:)) {
            return true
        }
        if action == #selector(selectPreviousSuggestion(_:)) ||
            action == #selector(selectNextSuggestion(_:)) {
            return isSuggestionNavigationEnabled?() == true
        }
        if isAutocompleteActive {
            return false
        }
        
        return super.canPerformAction(action, withSender: sender)
    }
    
    private func makeSuggestionCommand(input: String, action: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(
            input: input,
            modifierFlags: [],
            action: action
        )
        if #available(iOS 15.0, *) {
            command.wantsPriorityOverSystemBehavior = true
        }
        return command
    }
    
    @objc private func selectPreviousSuggestion(_ sender: UIKeyCommand) {
        onMoveSuggestionSelection?(-1)
    }
    
    @objc private func selectNextSuggestion(_ sender: UIKeyCommand) {
        onMoveSuggestionSelection?(1)
    }
    
    @objc private func dismissEditing(_ sender: UIKeyCommand) {
        onDismissEditing?()
    }
}
