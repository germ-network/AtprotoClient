//
//  AuthPDSAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/3/26.
//

import AtprotoTypes

public protocol AuthPDSAgent: Atproto.PDSAgent, Atproto.XRPC.ProxyCallable, Atproto.XRPC
		.AuthCallable
{
}
