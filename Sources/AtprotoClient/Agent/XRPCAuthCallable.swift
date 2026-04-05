//
//  XRPCAuthCallable.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/3/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

//an implementation (e.g. auth'd PDS) can declare itself capable of authed requests
public protocol XRPCAuthCallable: XRPCCallable {
	var authenticatedDID: Atproto.DID { get }
}

extension XRPCAuthCallable {
	public func createRecord<R: AtprotoRecord>(
		input: Lexicon.Com.Atproto.Repo.CreateRecord<R>.Input,
	) async throws -> Lexicon.Com.Atproto.Repo.CreateRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.CreateRecord<R>.self,
			input: input,
		)
	}

	public func putRecord<R: AtprotoRecord>(
		input: Lexicon.Com.Atproto.Repo.PutRecord<R>.Input,
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: input,
		)
	}

	public func deleteRecord<R: AtprotoRecord>(
		//allows for type inference when clear and explicit defn when not
		type: R.Type = R.self,
		input: Lexicon.Com.Atproto.Repo.DeleteRecord<R>.Input,
	) async throws -> Lexicon.Com.Atproto.Repo.DeleteRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.DeleteRecord<R>.self,
			input: input,
		)
	}
}
