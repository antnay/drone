//
//  NetworkManager.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private let session: URLSession

    private init() {
        self.session = URLSession(
            configuration: URLSessionConfiguration.default)
    }

}
