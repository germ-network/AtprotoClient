//
//  AuthPDSAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/3/26.
//

import AtprotoTypes

public protocol AuthPDSAgent: PDSAgent, XRPCProxyCallable, XRPCAuthCallable {
	// The PDSAgent `repo` must be the same as XRPCAuthCallable `authenticatedDID`
	// So we're enforcing an init with a single, authenticated repo DID
	init(authenticatedRepo: Atproto.DID)
}
