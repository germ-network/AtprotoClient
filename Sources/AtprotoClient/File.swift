//
//  HTTPFieldName+atprotoProxy.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/27/26.
//

import Foundation
import HTTPTypes

extension HTTPField.Name {
	//https://atproto.com/specs/xrpc#service-proxying
	public static var atprotoProxy: Self? {
		.init("atproto-proxy")
	}
}
