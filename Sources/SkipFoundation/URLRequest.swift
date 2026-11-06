// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP

public typealias NSURLRequest = URLRequest

public struct URLRequest : Hashable, CustomStringConvertible {
    public var url: URL?
    public var httpMethod: String? = "GET" {
        didSet {
            if let method = httpMethod,
                method != method.uppercased(),
               ["GET", "PUT", "HEAD", "POST", "DELETE", "CONNECT", "OPTIONS"].contains(method.uppercased())
            {
                // standard method names are always uppercase
                self.httpMethod = method.uppercased()
            }
        }
    }
    public var httpBody: Data? = nil
    public var allHTTPHeaderFields: [String : String]? = nil
    public var cachePolicy: CachePolicy = CachePolicy.useProtocolCachePolicy
    public var timeoutInterval: TimeInterval = 0.0
    public var allowsCellularAccess: Bool = true
    public var allowsExpensiveNetworkAccess: Bool = true
    public var allowsConstrainedNetworkAccess: Bool = true
    public var assumesHTTP3Capable: Bool = true
    public var requiresDNSSECValidation: Bool = false
    public var httpShouldHandleCookies: Bool = true
    public var httpShouldUsePipelining: Bool = true
    public var mainDocumentURL: URL? = nil
    public var networkServiceType: URLRequest.NetworkServiceType = URLRequest.NetworkServiceType.default
    public var attribution: URLRequest.Attribution = URLRequest.Attribution.developer
    @available(*, unavailable)
    public var httpBodyStream: Any? {
        get {
            fatalError()
        }
        set {
        }
    }

    public init(url: URL, cachePolicy: CachePolicy = CachePolicy.useProtocolCachePolicy, timeoutInterval: TimeInterval = 0.0) {
        self.url = url
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }

    public var description: String {
        return url?.toString() ?? "url: nil"
    }

    public func value(forHTTPHeaderField field: String) -> String? {
        return Self.value(forHTTPHeaderField: field, in: allHTTPHeaderFields ?? [:])
    }

    /// Perform a case-insensitive header lookup for the given field name in the header fields.
    internal static func value(forHTTPHeaderField fieldName: String, in headerFields: [String: String]) -> String? {
        if let value = headerFields[fieldName] {
            // fast case-sensitive match
            return value.description
        } else {
            // case-insensitive key lookup
            let fieldKey = fieldName.lowercased()
            for (key, value) in headerFields {
                if fieldKey == key.lowercased() {
                    return value
                }
            }
            return nil // not found
        }
    }

    private func transformHeaderKey(value: String) -> String {
        let lowerName = value.lowercased()
        if lowerName == "accept" {
            return "Accept"
        }
        return value
    }

    public mutating func setValue(_ value: String?, forHTTPHeaderField field: String) {
        // URLRequest stores every header name, including names a transport may manage.
        // Replace/remove the logical field regardless of casing, preserving other values.
        let lowerField = field.lowercased()
        var fields: [String: String] = [:]
        for (key, existing) in self.allHTTPHeaderFields ?? [:] {
            if key.lowercased() != lowerField {
                fields[key] = existing
            }
        }
        fields[transformHeaderKey(field)] = value
        self.allHTTPHeaderFields = fields
    }

    public mutating func addValue(_ value: String, forHTTPHeaderField field: String) {
        let fieldValue: String
        // Foundation keeps the comma even when either existing or appended text is empty.
        if let existingValue = self.value(forHTTPHeaderField: field) {
            fieldValue = existingValue + "," + value
        } else {
            fieldValue = value
        }
        setValue(fieldValue, forHTTPHeaderField: field)
    }

    public enum Attribution : Int {
        case developer
        case user
    }

    public enum CachePolicy : Int {
        case useProtocolCachePolicy = 0
        case reloadIgnoringLocalCacheData = 1
        case reloadIgnoringLocalAndRemoteCacheData = 4
        case returnCacheDataElseLoad = 2
        case returnCacheDataDontLoad = 3
        case reloadRevalidatingCacheData = 5
    }

    public enum NetworkServiceType : Int {
        case `default`
        case voip
        case video
        case background
        case voice
        case responsiveData
        case avStreaming
        case responsiveAV
        case callSignaling
    }
}

#endif
