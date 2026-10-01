//
//  ModelsTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraNetwork

@Suite("Network models")
struct ModelsTests {

	// MARK: - ResponseStatus

	private static func bucket(_ status: ResponseStatus?) -> String {
		switch status {
		case .information: return "information"
		case .success: return "success"
		case .redirect: return "redirect"
		case .clientError: return "clientError"
		case .serverError: return "serverError"
		case nil: return "nil"
		}
	}

	@Test("ResponseStatus buckets status codes", arguments: [
		(99, "nil"), (100, "information"), (199, "information"),
		(200, "success"), (204, "success"), (299, "success"),
		(300, "redirect"), (304, "redirect"),
		(400, "clientError"), (404, "clientError"), (499, "clientError"),
		(500, "serverError"), (599, "serverError"), (600, "nil")
	])
	func responseStatusBuckets(code: Int, expected: String) {
		#expect(Self.bucket(ResponseStatus(rawValue: code)) == expected)
	}

	@Test("Only 2xx is success", arguments: [100, 200, 250, 299, 301, 404, 503])
	func isSuccess(code: Int) {
		#expect(ResponseStatus(rawValue: code)?.isSuccess == (200..<300).contains(code))
	}

	// MARK: - HeaderField

	@Test("HeaderField renders keys and values")
	func headerFields() {
		let basic = HeaderField.basicAuth(BasicAuth(username: "user", password: "pass"))
		let bearer = HeaderField.authorization(AuthToken(rawValue: "t"))
		let content = HeaderField.contentType(.urlEncoded)

		#expect(basic.key == "Authorization")
		#expect(basic.value == "Basic dXNlcjpwYXNz")
		#expect(bearer.key == "Authorization")
		#expect(bearer.value == "Bearer t")
		#expect(content.key == "Content-Type")
		#expect(content.value == "application/x-www-form-urlencoded")
	}

	@Test("AuthToken is masked in descriptions")
	func authTokenMasked() {
		#expect(String(describing: AuthToken(rawValue: "secret")) == "***********")
	}

	// MARK: - HTTPBody

	@Test("HTTPBody reports its content type")
	func bodyContentType() {
		#expect(HTTPBody.json([:]).contentType?.value == "application/json")
		#expect(HTTPBody.jsonArray([]).contentType?.value == "application/json")
		#expect(HTTPBody.formData([:]).contentType?.value == "application/x-www-form-urlencoded")
		#expect(HTTPBody.data(Data(), .markdown).contentType?.value == "text/markdown")
	}

	// MARK: - NetworkError

	@Test("NetworkError classification per case")
	func networkErrorClassification() {
		let transport = URLError(.timedOut)
		let cases: [(error: NetworkError, retryable: Bool, reauth: Bool, category: String)] = [
			(.noNetworkConnection, true, false, "connectivity"),
			(.noServerOnline, true, false, "server"),
			(.transportError(transport), true, false, "connectivity"),
			(.badURL, false, false, "client"),
			(.invalidResponse(nil), false, false, "client"),
			(.invalidStatusCode(500, nil), true, false, "http"),
			(.invalidStatusCode(408, nil), true, false, "http"),
			(.invalidStatusCode(429, nil), true, false, "http"),
			(.invalidStatusCode(401, nil), false, true, "http"),
			(.invalidStatusCode(404, nil), false, false, "http"),
			(.noData, false, false, "data"),
			(.sessionExpired, false, true, "auth"),
			(.badToken, false, true, "auth"),
			(.badDecode(transport), false, false, "client")
		]

		for item in cases {
			#expect(item.error.isRetryable == item.retryable, "isRetryable for \(item.error)")
			#expect(item.error.requiresReauth == item.reauth, "requiresReauth for \(item.error)")
			#expect(item.error.category == item.category, "category for \(item.error)")
		}
	}
}
