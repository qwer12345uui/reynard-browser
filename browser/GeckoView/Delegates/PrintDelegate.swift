//
//  PrintDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/9/26.
//

import Foundation

public protocol PrintDelegate: AnyObject {
    @MainActor
    func onPrint(session: GeckoSession, browsingContextId: Int64?) async throws
}

private enum PrintEvents: String, CaseIterable {
    case request = "GeckoView:DotPrintRequest"
}

func newPrintHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewPrint",
        events: PrintEvents.allCases.map(\.rawValue),
        session: session
    ) { @MainActor session, delegate, type, message in
        guard PrintEvents(rawValue: type) == .request else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        var succeeded = false
        defer {
            session.dispatcher.dispatch(
                type: "GeckoView:DotPrintFinish",
                message: ["isPdfSuccessful": succeeded]
            )
        }
        
        guard let delegate = delegate as? PrintDelegate else {
            return nil
        }
        
        let browsingContextId = PayloadValue.int64(message?["canonicalBrowsingContextId"])
        try await delegate.onPrint(session: session, browsingContextId: browsingContextId)
        succeeded = true
        
        return nil
    }
}
