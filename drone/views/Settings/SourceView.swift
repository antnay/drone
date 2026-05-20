//
//  SourceView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData

struct SourceView: View {
    @EnvironmentObject var server: Server
    @Environment(\.modelContext) private var modelContext
    
    @State private var domain: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var errorMessage: String?

    var body: some View {
        if server.baseURL.isEmpty {
            Form {
                Section(header: Text("Add Subsonic Server")) {
                    TextField("Server Address (e.g. music.example.com)", text: $domain)
                        .textFieldStyle(.roundedBorder)
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    TextField("Display Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Button("Connect") {
                        connectServer()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(domain.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
            .onAppear {
                domain = server.baseURL
                username = server.username
                password = server.password
                name = server.name
            }
        } else {
            List {
                Section(header: Text("Active Server")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(server.name.isEmpty ? "Server" : server.name)
                                .font(.headline)
                            Text(server.baseURL)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: server.status)
                    }
                    
                    Button("Sync Library", systemImage: "arrow.clockwise") {
                        Task {
                            await server.sync(modelContext: modelContext)
                        }
                    }
                    .disabled(server.isLoading)

                    Button("Disconnect", role: .destructive) {
                        disconnectServer()
                    }
                }
                
                Section(header: Text("Details")) {
                    StatusRow(label: "Provider", value: server.provider)
                    StatusRow(label: "Username", value: server.username)
                    StatusRow(label: "Last scan", value: server.lastScan > 0 ? "\(Int(server.lastScan / 3600))h ago" : "Never")
                }
            }
        }
    }

    private func connectServer() {
        errorMessage = nil
        server.updateConnection(url: domain, username: username, password: password, name: name)
        
        Task {
            do {
                if let res = try await server.ping() {
                    server.provider = res.type
                    server.status = res.status
                    errorMessage = nil
                    try modelContext.save()
                } else {
                    errorMessage = "Server returned an empty response"
                }
            } catch {
                errorMessage = "Failed to connect: \(error.localizedDescription)"
            }
        }
    }

    private func disconnectServer() {
        server.updateConnection(url: "", username: "", password: "", name: "")
        server.status = ""
        server.provider = ""
        try? modelContext.save()
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == "ok" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(status == "ok" ? .green : .red)
            .clipShape(Capsule())
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}
