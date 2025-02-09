//
//  MouseKeyboardControlApp.swift
//  MouseKeyboardControl
//
//  Created by 张重言 on 2025/1/27.
//

import ApplicationServices
import SwiftUI

struct Permission: Identifiable {
    let id = UUID()
    let type: PermissionType
    let description: String
    var isGranted: Bool
}

enum PermissionType {
    case screenCapture
    case accessibility

    var displayName: String {
        switch self {
        case .screenCapture: return "录屏与系统录音"
        case .accessibility: return "辅助功能"
        }
    }
}

@main
struct MouseKeyboardControlApp: App {
    @State private var permissions: [Permission] = [
        Permission(
            type: .screenCapture,
            description: "捕获屏幕内容",
            isGranted: false
        ),
        Permission(
            type: .accessibility,
            description: "控制鼠标和键盘",
            isGranted: false
        ),
    ]

    private var allPermissionsGranted: Bool {
        permissions.allSatisfy { $0.isGranted }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if allPermissionsGranted {
                    ContentView()
                } else {
                    PermissionListView(permissions: $permissions)
                }
            }
            .onAppear(perform: checkPermissions)
            .onReceive(
                Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            ) { _ in
                checkPermissions()
            }
        }
    }

    private func checkPermissions() {
        permissions = permissions.map { permission in
            var newPermission = permission
            newPermission.isGranted = checkPermissionStatus(
                for: permission.type)
            return newPermission
        }
    }

    private func checkPermissionStatus(for type: PermissionType) -> Bool {
        switch type {
        case .screenCapture:
            return CGPreflightScreenCaptureAccess()
        case .accessibility:
            return AXIsProcessTrusted()
        }
    }
}

struct PermissionListView: View {
    @Binding var permissions: [Permission]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("需要以下权限才能继续")
                .font(.title2.bold())
                .padding(.bottom, 10)

            ForEach($permissions) { $permission in
                HStack(spacing: 15) {
                    Image(
                        systemName: permission.isGranted
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .font(.title2)
                    .foregroundColor(permission.isGranted ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(permission.type.displayName)
                            .font(.headline)
                        Text(permission.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !permission.isGranted {
                        Button(action: {
                            requestPermission(for: permission.type)
                        }) {
                            Text("立即授权")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 1, y: 1)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func requestPermission(for type: PermissionType) {
        switch type {
        case .screenCapture:
            let _ = CGRequestScreenCaptureAccess()
        case .accessibility:
            let options =
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
