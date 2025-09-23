//
//  ApiError.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation

struct ApiError<T: Codable>: Error {
    let code: HttpCodes
    let message: T?
    let data: T?
}
