import SwiftUI
import AppKit

struct ContentView: View {
  @Environment(AgentManager.self) var agentManager
  @ObservedObject private var settings = AppSettings.shared
  @State private var voiceManager = VoiceInputManager.shared
  @State private var pushToTalk = PushToTalkMonitor.shared
  @State private var showGitPanel = false
  @State private var sidebarWidth: CGFloat = 250
  @State private var showVoiceOverlay = false
  @State private var escapeMonitor: Any?
  @State private var sidebarVisible = true
  @State private var dragStartRatio: CGFloat?

  // Bindings from SkwadApp for menu commands
  @Binding var showNewAgentSheet: Bool
  @Binding var toggleGitPanel: Bool
  @Binding var toggleSidebar: Bool

  private let minSidebarWidth: CGFloat = 200
  private let maxSidebarWidth: CGFloat = 400

  private var activeAgent: Agent? {
    guard let id = agentManager.activeAgentId else { return nil }
    return agentManager.agents.first { $0.id == id }
  }

  private var canShowGitPanel: Bool {
    guard let agent = activeAgent else { return false }
    return GitWorktreeManager.shared.isGitRepo(agent.folder)
  }

  var body: some View {
    HStack(spacing: 0) {
      // Workspace bar (always visible when workspaces exist)
      if !agentManager.workspaces.isEmpty {
        WorkspaceBarView(sidebarVisible: $sidebarVisible)
          .transition(.move(edge: .leading).combined(with: .opacity))
      }

      if !agentManager.currentWorkspaceAgents.isEmpty && sidebarVisible {
        SidebarView(sidebarVisible: $sidebarVisible)
          .frame(width: sidebarWidth)
          .transition(.move(edge: .leading).combined(with: .opacity))

        // Resize handle
        Rectangle()
          .fill(Color.clear)
          .frame(width: 6)
          .contentShape(Rectangle())
          .onHover { hovering in
            if hovering {
              NSCursor.resizeLeftRight.push()
            } else {
              NSCursor.pop()
            }
          }
          .gesture(
            DragGesture()
              .onChanged { value in
                let newWidth = sidebarWidth + value.translation.width
                sidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
              }
          )
      }

      GeometryReader { geo in
        ZStack(alignment: .topLeading) {
          // Keep all terminals alive, show/hide via frame+offset per pane
          ForEach(agentManager.agents) { agent in
            
            let rect = paneRect(for: agent.id, in: geo.size)
            let visible = agentManager.activeAgentIds.contains(agent.id)

            let paneIdx = agentManager.paneIndex(for: agent.id) ?? 0

            AgentTerminalView(
              agent: agent,
              paneIndex: paneIdx,
              sidebarVisible: $sidebarVisible,
              onGitStatsTap: {
                if GitWorktreeManager.shared.isGitRepo(agent.folder) {
                  // Focus this agent's pane first so git panel opens for it
                  if let pane = agentManager.paneIndex(for: agent.id) {
                    agentManager.focusPane(pane)
                  }
                  withAnimation(.easeInOut(duration: 0.2)) {
                    showGitPanel.toggle()
                  }
                }
              },
              onPaneTap: {
                if let pane = agentManager.paneIndex(for: agent.id) {
                  agentManager.focusPane(pane)
                }
              }
            )
              .id("\(agent.id)-\(agent.restartToken)")
              .frame(width: rect.width, height: rect.height)
              .offset(x: rect.minX, y: rect.minY)
              .opacity(visible ? 1 : 0)
              .allowsHitTesting(visible)
          }

          // Empty state - no workspaces or empty workspace
          if agentManager.workspaces.isEmpty || agentManager.currentWorkspaceAgents.isEmpty {
            VStack(spacing: 16) {

              Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

              VStack(spacing: 0) {
                Text("Welcome to Skwad!")
                  .font(.system(size: 36, weight: .semibold))
                  .foregroundColor(.primary)

                Text(agentManager.workspaces.isEmpty
                    ? "Start by creating your first workspace"
                    : "Add an agent to your workspace")
                  .font(.title)
                  .foregroundColor(.secondary)
              }

              VStack(spacing: 32) {

                Button {
                  showNewAgentSheet = true
                } label: {
                  Label("Create New Agent", systemImage: "plus")
                    .font(.title2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 8) {
                  ForEach(settings.recentAgents.prefix(5)) { savedAgent in
                    Button {
                      agentManager.addAgent(folder: savedAgent.folder, name: savedAgent.name, avatar: savedAgent.avatar, agentType: savedAgent.agentType)
                    } label: {
                      HStack(spacing: 6) {
                        AvatarView(avatar: savedAgent.avatar, size: 20, font: .caption)
                        Text(savedAgent.name)
                          .font(.caption)
                          .lineLimit(1)
                      }
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Color.gray.opacity(0.2))
                      .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                  }
                }

              }.padding(.vertical, 32)

              VStack(spacing: 12) {

                Text("Install Skwad MCP Server to enable agent‑to‑agent communication")
                  .font(.title2)
                  .foregroundColor(.secondary)

                MCPCommandView(
                  serverURL: settings.mcpServerURL,
                  fontSize: .title3,
                  backgroundColor: Color.black.opacity(0.08),
                  iconSize: 20
                )
                .frame(maxWidth: 820)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(settings.effectiveBackgroundColor)
          }

          // Layout toggle button — positioned in top-right corner
          if agentManager.currentWorkspaceAgents.count >= 2 {
            HStack {
              Spacer()
              layoutToggleButton
            }
            .padding(.top, sidebarVisible ? 76 : 36)
            .padding(.trailing, 12)
          }

          // Git toggle button — positioned in bottom-right of active pane
          if canShowGitPanel {
            let activeRect = computePaneRect(agentManager.focusedPaneIndex, in: geo.size)
            VStack {
              Spacer()
              HStack {
                Spacer()
                gitToggleButton
                  .padding(16)
              }
            }
            .frame(width: activeRect.width, height: activeRect.height)
            .offset(x: activeRect.minX, y: activeRect.minY)
          }

          // Split mode overlays
          if agentManager.layoutMode != .single {
            // Dim the unfocused panes
            ForEach(0..<(agentManager.layoutMode == .gridFourPane ? 4 : 2), id: \.self) { pane in
              if pane != agentManager.focusedPaneIndex {
                let rect = computePaneRect(pane, in: geo.size)
                Rectangle()
                  .fill(Color.black.opacity(Theme.unfocusedOverlayOpacity))
                  .frame(width: rect.width, height: rect.height)
                  .offset(x: rect.minX, y: rect.minY)
                  .allowsHitTesting(false)
              }
            }

            if agentManager.layoutMode != .gridFourPane {
              // Use NSView-based divider to sit above terminal NSViews
              let isVertical = agentManager.layoutMode == .splitVertical
              let pos = isVertical ? geo.size.width * agentManager.splitRatio : geo.size.height * agentManager.splitRatio
              let dividerWidth: CGFloat = 12
              SplitDividerView(
                isVertical: isVertical,
                onDrag: { delta in
                  if dragStartRatio == nil {
                    dragStartRatio = agentManager.splitRatio
                  }
                  let totalSize = isVertical ? geo.size.width : geo.size.height
                  let startPos = totalSize * dragStartRatio!
                  let newRatio = (startPos + delta) / totalSize
                  agentManager.splitRatio = max(0.25, min(0.75, newRatio))
                },
                onDragEnd: {
                  dragStartRatio = nil
                  for id in agentManager.activeAgentIds {
                    agentManager.notifyTerminalResize(for: id)
                  }
                }
              )
              .frame(
                width: isVertical ? dividerWidth : geo.size.width,
                height: isVertical ? geo.size.height : dividerWidth
              )
              .offset(
                x: isVertical ? pos - dividerWidth / 2 : 0,
                y: isVertical ? 0 : pos - dividerWidth / 2
              )
            } else {
              // Grid mode: vertical and horizontal dividers at center (not draggable)
              let dividerWidth: CGFloat = 12
              // Vertical divider
              SplitDividerView(
                isVertical: true,
                onDrag: { _ in },
                onDragEnd: { }
              )
              .frame(width: dividerWidth, height: geo.size.height)
              .offset(x: geo.size.width / 2 - dividerWidth / 2)
              // Horizontal divider
              SplitDividerView(
                isVertical: false,
                onDrag: { _ in },
                onDragEnd: { }
              )
              .frame(width: geo.size.width, height: dividerWidth)
              .offset(y: geo.size.height / 2 - dividerWidth / 2)
            }
          }
        }
      }

      // Git panel (sliding from right)
      if showGitPanel, let agent = activeAgent {
        GitPanelView(folder: agent.folder) {
          withAnimation(.easeInOut(duration: 0.2)) {
            showGitPanel = false
          }
        }
        .transition(.move(edge: .trailing))
      }
    }
    .background(settings.sidebarBackgroundColor)
    .frame(minWidth: 900, minHeight: 600)
    .ignoresSafeArea()
    .animation(.easeInOut(duration: 0.25), value: agentManager.currentWorkspaceAgents.count)
    .animation(.easeInOut(duration: 0.25), value: agentManager.currentWorkspaceId)
    .overlay {
      // Voice input overlay
      if showVoiceOverlay {
        voiceOverlay
      }
    }
    .onChange(of: agentManager.activeAgentIds) { _, _ in
      if showGitPanel { showGitPanel = false }
    }
    .onChange(of: agentManager.focusedPaneIndex) { _, _ in
      if showGitPanel { showGitPanel = false }
    }
    .onChange(of: showGitPanel) { _, _ in
      // Notify terminal to resize when git panel toggles
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        if let activeId = agentManager.activeAgentId {
          agentManager.notifyTerminalResize(for: activeId)
        }
      }
    }
    .onChange(of: sidebarVisible) { _, _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        for id in agentManager.activeAgentIds {
          agentManager.notifyTerminalResize(for: id)
        }
      }
    }
    .onAppear {
      if settings.voiceEnabled {
        pushToTalk.start()
      }
    }
    .onChange(of: settings.voiceEnabled) { _, enabled in
      if enabled {
        pushToTalk.start()
      } else {
        pushToTalk.stop()
      }
    }
    .onChange(of: pushToTalk.isKeyDown) { _, isDown in
      handleVoiceKeyStateChange(isDown: isDown)
    }
    .onChange(of: showVoiceOverlay) { _, showing in
      if showing {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
          if event.keyCode == 53 {  // Escape key
            DispatchQueue.main.async {
              self.dismissVoiceOverlay()
            }
            return nil  // Consume the event
          }
          return event
        }
      } else {
        if let monitor = escapeMonitor {
          NSEvent.removeMonitor(monitor)
          escapeMonitor = nil
        }
      }
    }
    .sheet(isPresented: $showNewAgentSheet) {
      AgentSheet()
        .environment(agentManager)
    }
    .onChange(of: toggleGitPanel) { _, _ in
      if canShowGitPanel {
        withAnimation(.easeInOut(duration: 0.2)) {
          showGitPanel.toggle()
        }
      }
    }
    .onChange(of: toggleSidebar) { _, _ in
      withAnimation(.easeInOut(duration: 0.25)) {
        sidebarVisible.toggle()
      }
    }
  }

  // MARK: - Split Pane Layout Helpers

  /// Compute the rect for an agent based on its pane assignment
  private func paneRect(for agentId: UUID, in size: CGSize) -> CGRect {
    if agentManager.layoutMode == .single {
      return CGRect(origin: .zero, size: size)
    }
    let pane = agentManager.paneIndex(for: agentId) ?? 0
    return computePaneRect(pane, in: size)
  }

  /// Compute rect for a pane index given layout mode and split ratio
  private func computePaneRect(_ pane: Int, in size: CGSize) -> CGRect {
    let ratio = agentManager.splitRatio
    switch agentManager.layoutMode {
    case .single:
      return CGRect(origin: .zero, size: size)
    case .splitVertical:  // left | right
      let w0 = size.width * ratio
      let w1 = size.width - w0
      return pane == 0
        ? CGRect(x: 0, y: 0, width: w0, height: size.height)
        : CGRect(x: w0, y: 0, width: w1, height: size.height)
    case .splitHorizontal:  // top / bottom
      let h0 = size.height * ratio
      let h1 = size.height - h0
      return pane == 0
        ? CGRect(x: 0, y: 0, width: size.width, height: h0)
        : CGRect(x: 0, y: h0, width: size.width, height: h1)
    case .gridFourPane:  // 4-pane grid
      let w = size.width / 2
      let h = size.height / 2
      switch pane {
      case 0: return CGRect(x: 0, y: 0, width: w, height: h)        // top-left
      case 1: return CGRect(x: w, y: 0, width: w, height: h)        // top-right
      case 2: return CGRect(x: 0, y: h, width: w, height: h)        // bottom-left
      case 3: return CGRect(x: w, y: h, width: w, height: h)        // bottom-right
      default: return CGRect(origin: .zero, size: size)
      }
    }
  }




  // MARK: - Voice Input

  @ViewBuilder
  private var voiceOverlay: some View {
    ZStack {
      Color.black.opacity(0.4)
        .ignoresSafeArea()
        .onTapGesture {
          dismissVoiceOverlay()
        }

      VStack(spacing: 20) {
        // Header with close button
        HStack(spacing: 16) {
          Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
            .font(.system(size: 32))
            .foregroundColor(voiceManager.isListening ? .red : .secondary)
            .symbolEffect(.pulse, isActive: voiceManager.isListening)

          VStack(alignment: .leading, spacing: 6) {
            Text(voiceManager.isListening ? "Listening..." : "Voice Input")
              .font(.title2.bold())

            if let error = voiceManager.error {
              Text(error)
                .font(.body)
                .foregroundColor(.red)
                .lineLimit(2)
            } else {
              Text("Release key to stop • Escape to cancel")
                .font(.body)
                .foregroundColor(.secondary)
            }
          }

          Spacer()

          Button {
            dismissVoiceOverlay()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title)
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .keyboardShortcut(.escape, modifiers: [])
        }

        // Audio waveform visualization
        if voiceManager.isListening {
          AudioWaveformView(samples: voiceManager.waveformSamples)
            .frame(height: 32)
        }

        // Transcribed text
        if !voiceManager.transcribedText.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Transcription:")
              .font(.body)
              .foregroundColor(.secondary)

            Text(voiceManager.transcribedText)
              .font(.title3)
              .padding(14)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.black.opacity(0.2))
              .cornerRadius(8)
          }

          // Action buttons (only if not auto-insert)
          if !settings.voiceAutoInsert && !voiceManager.isListening {
            HStack {
              Button("Cancel") {
                dismissVoiceOverlay()
              }
              .font(.body)

              Spacer()

              Button("Insert") {
                insertVoiceText()
              }
              .font(.body)
              .keyboardShortcut(.return, modifiers: [])
              .buttonStyle(.borderedProminent)
            }
          }
        }
      }
      .padding(24)
      .frame(width: 480)
      .background(settings.effectiveBackgroundColor)
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
    .onKeyPress(.escape) {
      dismissVoiceOverlay()
      return .handled
    }
  }

  private func handleVoiceKeyStateChange(isDown: Bool) {
    guard settings.voiceEnabled else { return }

    if isDown {
      // Key pressed - start recording
      showVoiceOverlay = true
      Task {
        await voiceManager.startListening()
      }
    } else {
      // Key released - only inject if overlay wasn't cancelled
      guard showVoiceOverlay else { return }

      let finalText = voiceManager.transcribedText
      voiceManager.stopListening()

      // Always insert text if we have it
      if !finalText.isEmpty {
        voiceManager.injectText(finalText, into: agentManager, submit: settings.voiceAutoInsert)
      }
      dismissVoiceOverlay()
    }
  }

  private func insertVoiceText() {
    guard !voiceManager.transcribedText.isEmpty else { return }
    voiceManager.injectText(voiceManager.transcribedText, into: agentManager, submit: settings.voiceAutoInsert)
    dismissVoiceOverlay()
  }

  private func dismissVoiceOverlay() {
    voiceManager.stopListening()
    voiceManager.transcribedText = ""
    voiceManager.error = nil
    showVoiceOverlay = false
  }

  private var layoutToggleButton: some View {
    Menu {
      Button {
        agentManager.layoutMode = .single
        if agentManager.activeAgentIds.count > 1 {
          agentManager.activeAgentIds = [agentManager.activeAgentIds[agentManager.focusedPaneIndex]]
        }
      } label: {
        Label("Single Pane", systemImage: "square")
      }
      
      Button {
        agentManager.layoutMode = .splitVertical
        let workspaceAgents = agentManager.currentWorkspaceAgents
        if agentManager.activeAgentIds.count == 1, workspaceAgents.count >= 2 {
          let currentId = agentManager.activeAgentIds[0]
          let otherAgent = workspaceAgents.first { $0.id != currentId }
          if let otherId = otherAgent?.id {
            agentManager.activeAgentIds = [currentId, otherId]
          }
        } else if agentManager.activeAgentIds.count > 2 {
          agentManager.activeAgentIds = Array(agentManager.activeAgentIds.prefix(2))
        }
      } label: {
        Label("Split Vertical", systemImage: "square.split.2x1")
      }

      Button {
        agentManager.layoutMode = .splitHorizontal
        let workspaceAgents = agentManager.currentWorkspaceAgents
        if agentManager.activeAgentIds.count == 1, workspaceAgents.count >= 2 {
          let currentId = agentManager.activeAgentIds[0]
          let otherAgent = workspaceAgents.first { $0.id != currentId }
          if let otherId = otherAgent?.id {
            agentManager.activeAgentIds = [currentId, otherId]
          }
        } else if agentManager.activeAgentIds.count > 2 {
          agentManager.activeAgentIds = Array(agentManager.activeAgentIds.prefix(2))
        }
      } label: {
        Label("Split Horizontal", systemImage: "square.split.1x2")
      }

      if agentManager.currentWorkspaceAgents.count >= 3 {
        Button {
          agentManager.layoutMode = .gridFourPane
          let workspaceAgents = agentManager.currentWorkspaceAgents
          if agentManager.activeAgentIds.count < 3 {
            // Fill up to 4 agents (or however many we have)
            var newIds = agentManager.activeAgentIds
            let availableAgents = workspaceAgents.filter { !newIds.contains($0.id) }
            for agent in availableAgents.prefix(4 - newIds.count) {
              newIds.append(agent.id)
            }
            agentManager.activeAgentIds = newIds
          }
        } label: {
          Label("4-Pane Split", systemImage: "square.grid.2x2")
        }
      }
    } label: {
      Image(systemName: "menubar.rectangle")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Theme.secondaryText)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Layout options")
  }

  private var gitToggleButton: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        showGitPanel.toggle()
      }
    } label: {
      Image(systemName: showGitPanel ? "xmark" : "arrow.triangle.branch")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white)
        .frame(width: 36, height: 36)
        .background(Color.accentColor)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
    .buttonStyle(.plain)
    .help(showGitPanel ? "Close Git panel" : "Open Git panel")
  }
}

#Preview {
  @Previewable @State var showNewAgentSheet = false
  @Previewable @State var toggleGitPanel = false
  @Previewable @State var toggleSidebar = false

  ContentView(
    showNewAgentSheet: $showNewAgentSheet,
    toggleGitPanel: $toggleGitPanel,
    toggleSidebar: $toggleSidebar
  )
    .environment(AgentManager())
}

// MARK: - Split Pane Preview

private struct SplitPanePreview: View {
  @State private var manager = previewSplitManager()
  @State private var focusedPane = 0

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        ForEach(0..<2) { pane in
          let rect = computeRect(pane, in: geo.size)
          let agent = manager.agents[pane]
          let isFocused = pane == focusedPane

          VStack(spacing: 0) {
            AgentFullHeader(agent: agent, isFocused: isFocused, onGitStatsTap: {}, onPaneTap: {
              focusedPane = pane
            })
            // Placeholder terminal body
            Rectangle()
              .fill(pane == 0 ? Color.blue.opacity(0.08) : Color.green.opacity(0.08))
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .overlay(
                Text("Pane \(pane + 1) — \(agent.name)")
                  .font(.title3)
                  .foregroundColor(.secondary)
              )
          }
          .frame(width: rect.width, height: rect.height)
          .offset(x: rect.minX, y: rect.minY)
        }

        // Dim unfocused pane
        let unfocusedRect = computeRect(1 - focusedPane, in: geo.size)
        Rectangle()
          .fill(Color.black.opacity(Theme.unfocusedOverlayOpacity))
          .frame(width: unfocusedRect.width, height: unfocusedRect.height)
          .offset(x: unfocusedRect.minX, y: unfocusedRect.minY)
          .allowsHitTesting(false)

        // Divider
        let pos = geo.size.width * manager.splitRatio
        Rectangle()
          .fill(Color.clear)
          .frame(width: 6, height: geo.size.height)
          .overlay(
            Rectangle()
              .fill(Color.primary.opacity(0.15))
              .frame(width: 1, height: geo.size.height)
          )
          .offset(x: pos - 3)
      }
    }
    .environment(manager)
    .frame(width: 900, height: 600)
  }

  private func computeRect(_ pane: Int, in size: CGSize) -> CGRect {
    let w0 = size.width * manager.splitRatio
    return pane == 0
      ? CGRect(x: 0, y: 0, width: w0, height: size.height)
      : CGRect(x: w0, y: 0, width: size.width - w0, height: size.height)
  }
}

@MainActor private func previewSplitManager() -> AgentManager {
  var a1 = Agent(name: "skwad", avatar: "🐱", folder: "/Users/nbonamy/src/skwad")
  a1.status = .running
  a1.terminalTitle = "Editing ContentView.swift"
  a1.gitStats = .init(insertions: 42, deletions: 7, files: 3)

  var a2 = Agent(name: "witsy", avatar: "🤖", folder: "/Users/nbonamy/src/witsy")
  a2.status = .idle
  a2.gitStats = .init(insertions: 0, deletions: 0, files: 0)

  let m = AgentManager()
  m.agents = [a1, a2]
  m.activeAgentIds = [a1.id, a2.id]
  m.layoutMode = .splitVertical
  return m
}

#Preview("Split Pane") {
  SplitPanePreview()
}

// MARK: - Audio Waveform Visualization (Dictation style)

struct AudioWaveformView: View {
  let samples: [Float]
  private let barCount = 64
  private let barWidth: CGFloat = 2
  private let spacing: CGFloat = 1.5

  var body: some View {
    TimelineView(.animation(minimumInterval: 1/60)) { _ in
      Canvas { context, size in
        let totalWidth = CGFloat(barCount) * (barWidth + spacing) - spacing
        let startX = (size.width - totalWidth) / 2
        let midY = size.height / 2
        let maxHeight = size.height * 0.9

        for i in 0..<barCount {
          // Map bar index to sample index
          let sampleIndex = samples.count > 0 ? i * samples.count / barCount : 0
          let sample = sampleIndex < samples.count ? samples[sampleIndex] : 0

          // Minimum bar height of 2 for visibility
          let height = max(2, CGFloat(sample) * maxHeight)

          let x = startX + CGFloat(i) * (barWidth + spacing)
          let rect = CGRect(
            x: x,
            y: midY - height / 2,
            width: barWidth,
            height: height
          )

          context.fill(
            Path(roundedRect: rect, cornerRadius: 1),
            with: .color(.white.opacity(0.85))
          )
        }
      }
    }
  }
}
