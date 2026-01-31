//
//  AppDelegate.swift
//  Skwad
//
//  Application delegate for handling app lifecycle events
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var agentManager: AgentManager?
    var mcpServer: MCPServer?

    func applicationWillTerminate(_ notification: Notification) {
        print("[skwad] Application terminating - cleaning up resources")

        // Terminate all agent processes first
        agentManager?.terminateAll()

        // Clean up Ghostty resources
        GhosttyAppManager.shared.cleanup()

        // Stop MCP server (fire and forget - system will kill process anyway)
        if let server = mcpServer {
            Task {
                await server.stop()
            }
            mcpServer = nil
        }

        print("[skwad] Cleanup complete")
    }
}
