//
//  KeychainService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import Security

public struct KeychainService {
	public func getSecret(service: String, account: String) -> String? {
		let query = [
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecReturnData: true,
			kSecMatchLimit: kSecMatchLimitOne,
			kSecClass: kSecClassGenericPassword
		] as CFDictionary
		
		var dataTypeRef: AnyObject?
		let status = SecItemCopyMatching(query, &dataTypeRef)
		
		if status == errSecSuccess, let data = dataTypeRef as? Data {
			return String(data: data, encoding: .utf8)
		} else {
			return nil
		}
	}
	
	public func saveSecret(service: String, account: String, secret: String) -> Bool {
		let keychainItem = [
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecValueData: secret.data(using: .utf8)!,
			kSecClass: kSecClassGenericPassword
		] as CFDictionary
		
		let status = SecItemAdd(keychainItem, nil)
		return status == errSecSuccess
	}
	
	public func deleteSecret(service: String, account: String) -> Bool {
		let query = [
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecClass: kSecClassGenericPassword
		] as CFDictionary
		
		let status = SecItemDelete(query)
		return status == errSecSuccess
	}
	
	public func updateSecret(service: String, account: String, secret: String) -> Bool {
		let query = [
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecClass: kSecClassGenericPassword
		] as CFDictionary
		
		let field = [
			kSecValueData: secret.data(using: .utf8)!,
		] as CFDictionary
		
		let status = SecItemUpdate(query, field)
		return status == errSecSuccess
	}
	
	public func clearAllSecrets() -> Bool {
		let secClasses = [
			kSecClassGenericPassword,
			kSecClassInternetPassword,
			kSecClassCertificate,
			kSecClassKey,
			kSecClassIdentity
		]
		
		var allSuccess = true
		
		for secClass in secClasses {
			let query: [String: Any] = [
				kSecClass as String: secClass
			]
			
			let status = SecItemDelete(query as CFDictionary)
			// errSecItemNotFound считается успехом (нечего удалять)
			if status != errSecSuccess && status != errSecItemNotFound {
				allSuccess = false
			}
		}
		
		return allSuccess
	}
}
