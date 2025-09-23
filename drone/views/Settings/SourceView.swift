//
//  SourceView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI

struct SourceView: View {
    @Binding var server: Server
    @State private var domain: String = "https://navidrome.thetickler.antnay.xyz"
    @State private var username: String = "root"
    @State private var password: String = "Preang3f9562"
    @State private var name: String = "main"
    var body: some View {
        if server.provider == nil {
            Form {
                Section(header: Text("Servers")) {
                    TextField("domain:port", text: $domain)
                    TextField("username", text: $username)
                    TextField("password", text: $password)
                    TextField("server name", text: $name)
                    Button("Add") {
                        server = Server(
                            url: domain,
                            credentials: Credentials(
                                username: username, password: password),
                            name: name)
                        Task {
                            do {
                                let res = try await server.ping()
                                server.provider = res?.type
                                server.status = res?.status
                                server.lastScan = 0
                            } catch {
                                //                                    Text("\(error)")
                                print("error when adding server \(error)")
                            }
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("SERVER STATUS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    StatusRow(label: "Status", value: server.status ?? "NIL")
                    StatusRow(
                        label: "Provider", value: server.provider ?? "NIL")
                    StatusRow(
                        label: "Last scan",
                        value: "\((server.lastScan ?? 0) / 3600)")
                }
            }
        }
    }
}

struct StatusRow: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
            Text(value)
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
