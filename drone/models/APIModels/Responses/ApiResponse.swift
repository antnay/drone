//
//  ApiResponse.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation

struct ApiResponse<T: Codable>: Codable {
    let code: HttpCodes
    let message: T?
    let data: T?
}

enum HttpCodes: Int, Codable {
    case ok = 200
    case created = 201
    case accepted = 202
    case badRequest = 400
    case unautharized = 401
    case notFound = 404
    case methodNotAllowed = 405
    case internalServerError = 500
    case notImplemented = 501
}
