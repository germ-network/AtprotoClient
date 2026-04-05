//
//  AuthPDSAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/3/26.
//

import AtprotoTypes

public protocol AuthPDSAgent: PDSAgent, XRPCProxyCallable, XRPCAuthCallable {}

extension AuthPDSAgent {
	// The PDSAgent `repo` must be the same as XRPCAuthCallable `authenticatedDID`
	var isValid: Bool {
		authenticatedDID == repo
	}
}
