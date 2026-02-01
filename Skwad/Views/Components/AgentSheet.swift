import SwiftUI
import UniformTypeIdentifiers

struct AgentPrefill: Identifiable {
    let id = UUID()
    let name: String
    let avatar: String?
    let folder: String
    let agentType: String
    let insertAfterId: UUID?
}

struct AgentSheet: View {
    @EnvironmentObject var agentManager: AgentManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var repoDiscovery = RepoDiscoveryService.shared

    let editingAgent: Agent?
    let prefill: AgentPrefill?

    // Folder selection state
    @State private var selectedFolder: String = ""
    @State private var selectedRepo: RepoInfo?
    @State private var selectedWorktree: WorktreeInfo?
    @State private var showingNewWorktreeSheet = false
    @State private var validationError: String?

    // Agent details
    @State private var name: String = ""
    @State private var avatar: String = "🤖"
    @State private var selectedAgentType: String = "claude"
    @State private var showingEmojiPicker = false
    @State private var selectedImage: NSImage?
    @State private var showingCropper = false

    // Git data
    @State private var recentRepoInfos: [RepoInfo] = []
    @State private var allRepos: [RepoInfo] = []
    @State private var isLoadingRepos = false
    @State private var worktrees: [WorktreeInfo] = []
    @State private var shouldApplyPrefillWorktree = false

    private var isEditing: Bool { editingAgent != nil }
    private var hasWorktreeFeatures: Bool { settings.hasValidSourceBaseFolder }

    private let avatarOptions = [
        // Agent icons (from our available agents)
        "claude", "openai", "opencode", "gemini", "copilot",
        // Tech & coding emojis
        "🤖", "🧠", "💻", "🖥️", "⌨️", "👨‍💻", "👩‍💻", "🦾",
        // Symbols & tools
        "🚀", "⚡️", "🔧", "🛠️", "⚙️", "🔥", "💡", "🎯", "📡",
        // Animals (smart/tech themed)
        "🦊", "🐙", "🦄", "🐺", "🦅", "🦉", "🐝", "🦋", "🐲",
        // Fun & symbols
        "🌟", "👾", "🎮", "💎", "🌈", "🔮", "🎨", "⭐️"
    ]

    init(editing agent: Agent? = nil, prefill: AgentPrefill? = nil) {
        self.editingAgent = agent
        self.prefill = prefill

        if let agent = agent {
            _selectedFolder = State(initialValue: agent.folder)
            _name = State(initialValue: agent.name)
            _avatar = State(initialValue: agent.avatar ?? "🤖")
            _selectedAgentType = State(initialValue: agent.agentType)
        } else if let prefill = prefill {
            _selectedFolder = State(initialValue: prefill.folder)
            _name = State(initialValue: prefill.name)
            _avatar = State(initialValue: prefill.avatar ?? "🤖")
            _selectedAgentType = State(initialValue: prefill.agentType)
            _shouldApplyPrefillWorktree = State(initialValue: !prefill.folder.isEmpty)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(isEditing ? "Edit Agent" : "New Agent")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(isEditing ? "Update agent settings" : "Add a new Claude to your skwad")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Form {
                // Section 1: Name & Avatar
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $name, prompt: Text("Agent name"))
                            .textFieldStyle(.plain)
                    }

                    LabeledContent("Avatar") {
                        HStack(spacing: 12) {
                            Button {
                                showingEmojiPicker.toggle()
                            } label: {
                                AvatarView(avatar: avatar, size: 40, font: .title)
                                    .frame(width: 40, height: 40)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showingEmojiPicker) {
                                AvatarPickerView(
                                    selection: $avatar,
                                    emojiOptions: avatarOptions,
                                    onImagePick: {
                                        showingEmojiPicker = false
                                        pickImage()
                                    }
                                )
                            }

                            Text("Click to change")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 2: Coding Agent (only when creating)
                if !isEditing {
                    Section {
                        AgentTypePicker(label: "Coding Agent", selection: $selectedAgentType)
                    }
                }

                // Section 3: Folder/Repository
                Section {
                    if isEditing {
                        // Editing mode: show folder read-only
                        LabeledContent("Folder") {
                            Text(shortenedPath)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } else if hasWorktreeFeatures {
                        // Worktree mode: repo + worktree pickers
                        worktreeSelectionView
                    } else {
                        // Fallback: simple folder picker with hint
                        simpleFolderPickerView
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: hasWorktreeFeatures && !isEditing ? 420 : 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add Agent") {
                    if isEditing {
                        updateAgent()
                    } else {
                        validateAndCreateAgent()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCropper) {
            if let image = selectedImage {
                ImageCropperSheet(image: image) { croppedImage in
                    if let croppedImage = croppedImage {
                        avatar = imageToBase64(croppedImage)
                    }
                    showingCropper = false
                    selectedImage = nil
                }
            }
        }
        .sheet(isPresented: $showingNewWorktreeSheet) {
            if let repo = selectedRepo {
                NewWorktreeSheet(repo: repo) { worktree in
                    if let worktree = worktree {
                        worktrees = GitWorktreeManager.shared.listWorktrees(for: repo.path)
                        selectedWorktree = worktree
                        selectedFolder = worktree.path
                        if name.isEmpty {
                            name = URL(fileURLWithPath: worktree.path).lastPathComponent
                        }
                    }
                }
            }
        }
        .alert("Cannot Add Agent", isPresented: .init(
            get: { validationError != nil },
            set: { if !$0 { validationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationError ?? "")
        }
        .onAppear {
            if hasWorktreeFeatures && !isEditing {
                loadRepos()
            }
            applyPrefillWorktreeIfNeeded()
        }
        .onReceive(repoDiscovery.$repos) { repos in
            allRepos = repos
            updateRecentRepos(from: repos)
            applyPrefillWorktreeIfNeeded()
        }
        .onReceive(repoDiscovery.$isLoading) { loading in
            isLoadingRepos = loading
        }
    }

    // MARK: - Worktree Selection View

    @ViewBuilder
    private var worktreeSelectionView: some View {
        // Repository picker
        LabeledContent("Repository") {
            Menu {
                // Recent repos first
                if !recentRepoInfos.isEmpty {
                    ForEach(recentRepoInfos, id: \.path) { repo in
                        Button {
                            selectRepo(repo)
                        } label: {
                            HStack {
                                Text(repo.name)
                                Spacer()
                                Text("recent")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    Divider()
                }

                // All repos (excluding recent)
                if isLoadingRepos {
                    Text("Loading repositories...")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(nonRecentRepos, id: \.path) { repo in
                        Button {
                            selectRepo(repo)
                        } label: {
                            Text(repo.name)
                        }
                    }
                }

                Divider()

                Button {
                    browseForFolder()
                } label: {
                    Label("Browse Other...", systemImage: "folder")
                }
            } label: {
                HStack {
                    Text(selectedRepo?.name ?? "Select repository")
                        .foregroundColor(selectedRepo == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }

        // Worktree picker (only shown when repo is selected)
        if selectedRepo != nil {
            LabeledContent("Worktree") {
                Menu {
                    ForEach(worktrees, id: \.path) { worktree in
                        Button {
                            selectWorktree(worktree)
                        } label: {
                            HStack {
                                Text(worktree.branch)
                                if worktree.isMain {
                                    Text("(main)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if !worktrees.isEmpty {
                        Divider()
                    }

                    Button {
                        showingNewWorktreeSheet = true
                    } label: {
                        Label("New Worktree...", systemImage: "plus")
                    }
                } label: {
                    HStack {
                        Text(selectedWorktree?.branch ?? "Select worktree")
                            .foregroundColor(selectedWorktree == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
            }
        }

        // Show selected folder path
        if !selectedFolder.isEmpty {
            LabeledContent("Folder") {
                Text(shortenedPath)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Simple Folder Picker View

    @ViewBuilder
    private var simpleFolderPickerView: some View {
        LabeledContent("Folder") {
            HStack {
                Text(selectedFolder.isEmpty ? "No folder selected" : shortenedPath)
                    .foregroundColor(selectedFolder.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Choose...") {
                    browseForFolder()
                }
            }
        }

        // Hint about worktree features
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
            Text("Configure source folder in Settings → General to enable git worktree features")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    private var shortenedPath: String {
        let path = selectedFolder
        if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private var nonRecentRepos: [RepoInfo] {
        return allRepos
    }

    // MARK: - Actions

    private func loadRepos() {
        repoDiscovery.start()

        allRepos = repoDiscovery.repos
        isLoadingRepos = repoDiscovery.isLoading
        updateRecentRepos(from: allRepos)

        if allRepos.isEmpty && !repoDiscovery.isLoading {
            populateRecentReposFallback()
        }
    }

    private func updateRecentRepos(from repos: [RepoInfo]) {
        let recentNames = settings.recentRepos
        recentRepoInfos = repos.filter { recentNames.contains($0.name) }
            .sorted { repo1, repo2 in
                let idx1 = recentNames.firstIndex(of: repo1.name) ?? Int.max
                let idx2 = recentNames.firstIndex(of: repo2.name) ?? Int.max
                return idx1 < idx2
            }
    }

    private func populateRecentReposFallback() {
        let recentNames = settings.recentRepos
        guard !recentNames.isEmpty else { return }

        let basePath = NSString(string: settings.sourceBaseFolder).expandingTildeInPath
        recentRepoInfos = recentNames.compactMap { name -> RepoInfo? in
            let repoPath = (basePath as NSString).appendingPathComponent(name)
            let gitPath = (repoPath as NSString).appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return RepoInfo(name: name, path: repoPath, worktreeCount: 0)
            }
            return nil
        }
    }

    private func selectRepo(_ repo: RepoInfo) {
        selectedRepo = repo
        worktrees = GitWorktreeManager.shared.listWorktrees(for: repo.path)

        // Auto-select first worktree
        if let first = worktrees.first {
            selectWorktree(first)
        } else {
            selectedWorktree = nil
            selectedFolder = ""
        }
    }

    private func selectWorktree(_ worktree: WorktreeInfo) {
        selectedWorktree = worktree
        selectedFolder = worktree.path

        if name.isEmpty {
            name = URL(fileURLWithPath: worktree.path).lastPathComponent
        }
    }

    private func applyPrefillWorktreeIfNeeded() {
        guard shouldApplyPrefillWorktree else { return }
        guard let prefill = prefill, !prefill.folder.isEmpty else { return }
        guard !isEditing else { return }

        shouldApplyPrefillWorktree = false

        if !hasWorktreeFeatures {
            selectedFolder = prefill.folder
            return
        }

        let folder = prefill.folder
        let reposByPath = Dictionary(uniqueKeysWithValues: allRepos.map { ($0.path, $0) })

        for (repoPath, repoWorktrees) in repoDiscovery.worktreesByRepoPath {
            if let match = repoWorktrees.first(where: { $0.path == folder }) {
                selectedRepo = reposByPath[repoPath]
                worktrees = repoWorktrees
                selectedWorktree = match
                selectedFolder = match.path
                return
            }
        }
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select the folder for this agent"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url.path
            selectedRepo = nil
            selectedWorktree = nil
            if name.isEmpty {
                name = url.lastPathComponent
            }
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select an image for the avatar"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                selectedImage = image
                showingCropper = true
            }
        }
    }

    private func imageToBase64(_ image: NSImage) -> String {
        let targetSize = NSSize(width: 128, height: 128)
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return "🤖"
        }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    private func validateAndCreateAgent() {
        // Validate folder selection
        if selectedFolder.isEmpty {
            if selectedRepo != nil && selectedWorktree == nil {
                validationError = "Please select a worktree for this repository."
            } else {
                validationError = "Please select a folder for the agent."
            }
            return
        }

        // Validate folder exists
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: selectedFolder, isDirectory: &isDirectory) || !isDirectory.boolValue {
            validationError = "The selected folder does not exist."
            return
        }

        createAgent()
    }

    private func createAgent() {
        // Track recent repo if using worktree features
        if let repo = selectedRepo {
            settings.addRecentRepo(repo.name)
        }

        agentManager.addAgent(
            folder: selectedFolder,
            name: name.isEmpty ? nil : name,
            avatar: avatar,
            agentType: selectedAgentType,
            insertAfterId: prefill?.insertAfterId
        )
        dismiss()
    }

    private func updateAgent() {
        guard let agent = editingAgent else { return }
        agentManager.updateAgent(
            id: agent.id,
            name: name.isEmpty ? agent.folder.split(separator: "/").last.map(String.init) ?? "Agent" : name,
            avatar: avatar
        )
        dismiss()
    }
}

// MARK: - Avatar Picker View

struct AvatarPickerView: View {
    @Binding var selection: String
    let emojiOptions: [String]
    let onImagePick: () -> Void
    @Environment(\.dismiss) private var dismiss

    let columns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 10)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(emojiOptions, id: \.self) { option in
                    Button {
                        // Convert icon name to data URI for consistent handling
                        if let image = NSImage(named: option) {
                            // Resize the icon to 40x40 then add transparent padding to 64x64
                            let resizedImage = image.scalePreservingAspectRatio(
                                targetSize: NSSize(width: 40, height: 40)
                            )
                            
                            // Create a 64x64 canvas with transparent background
                            let paddedImage = NSImage(size: NSSize(width: 64, height: 64))
                            paddedImage.lockFocus()
                            
                            // Draw the resized image centered in the 64x64 canvas
                            let x = (64 - resizedImage.size.width) / 2
                            let y = (64 - resizedImage.size.height) / 2
                            resizedImage.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .copy, fraction: 1.0)
                            
                            paddedImage.unlockFocus()
                            
                            if let tiffData = paddedImage.tiffRepresentation,
                               let bitmapImage = NSBitmapImageRep(data: tiffData),
                               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                                let base64 = pngData.base64EncodedString()
                                selection = "data:image/png;base64,\(base64)"
                            }
                        } else {
                            selection = option
                        }
                        dismiss()
                    } label: {
                        // Check if it's an agent icon or emoji
                        if let image = NSImage(named: option) {
                            // Agent icon
                            let scaledImage = image.scalePreservingAspectRatio(
                                targetSize: NSSize(width: 24, height: 24)
                            )
                            Image(nsImage: scaledImage)
                                .frame(width: 32, height: 32)
                                .background(Color.clear)
                                .cornerRadius(6)
                        } else {
                            // Emoji
                            Text(option)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(selection == option ? Color.accentColor.opacity(0.3) : Color.clear)
                                .cornerRadius(6)
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }

            Divider()

            Button {
                onImagePick()
            } label: {
                HStack {
                    Image(systemName: "photo")
                    Text("Choose Image...")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Image Cropper Sheet

struct ImageCropperSheet: View {
    let image: NSImage
    let onComplete: (NSImage?) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 200

    var body: some View {
        VStack(spacing: 20) {
            Text("Adjust Avatar")
                .font(.headline)

            ZStack {
                ScrollWheelView { delta in
                    let zoomFactor = 1.0 + (delta * 0.01)
                    scale = max(0.5, min(4.0, scale * zoomFactor))
                    lastScale = scale
                } content: {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.5, min(4.0, lastScale * value))
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )

                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)

                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: cropSize, height: cropSize)
                    .mask(
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: cropSize, height: cropSize)
            .clipped()
            .background(Color.black)
            .cornerRadius(8)

            Text("Drag to position, scroll to zoom")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                Button("Cancel") {
                    onComplete(nil)
                }
                .keyboardShortcut(.cancelAction)

                Button("Done") {
                    let cropped = cropImage()
                    onComplete(cropped)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 300, height: 350)
    }

    private func cropImage() -> NSImage {
        let imageSize = image.size

        let widthRatio = cropSize / imageSize.width
        let heightRatio = cropSize / imageSize.height
        let fillScale = max(widthRatio, heightRatio)

        let fillWidth = imageSize.width * fillScale
        let fillHeight = imageSize.height * fillScale

        let finalWidth = fillWidth * scale
        let finalHeight = fillHeight * scale

        let drawX = (cropSize - finalWidth) / 2 + offset.width
        let drawY = (cropSize - finalHeight) / 2 - offset.height

        let outputImage = NSImage(size: NSSize(width: cropSize, height: cropSize))
        outputImage.lockFocus()

        let circlePath = NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: cropSize, height: cropSize))
        circlePath.addClip()

        image.draw(
            in: NSRect(x: drawX, y: drawY, width: finalWidth, height: finalHeight),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )

        outputImage.unlockFocus()
        return outputImage
    }
}

// MARK: - ScrollWheelView Helper

struct ScrollWheelView<Content: View>: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    let content: Content
    
    init(onScroll: @escaping (CGFloat) -> Void, @ViewBuilder content: () -> Content) {
        self.onScroll = onScroll
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = ScrollWheelHostingView(rootView: content, onScroll: onScroll)
        return hostingView
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

// MARK: - Previews

#Preview("New Agent") {
    AgentSheet()
        .environmentObject(AgentManager())
}

#Preview("Edit Agent") {
    var agent = Agent(name: "skwad", avatar: "🐱", folder: "/Users/nbonamy/src/skwad")
    agent.status = .running
    return AgentSheet(editing: agent)
        .environmentObject(AgentManager())
}

#Preview("Fork Agent") {
    let prefill = AgentPrefill(
        name: "skwad (fork)",
        avatar: "🐱",
        folder: "/Users/nbonamy/src/skwad",
        agentType: "claude",
        insertAfterId: nil
    )
    return AgentSheet(prefill: prefill)
        .environmentObject(AgentManager())
}

private class ScrollWheelHostingView<Content: View>: NSHostingView<Content> {
    let onScroll: (CGFloat) -> Void
    
    init(rootView: Content, onScroll: @escaping (CGFloat) -> Void) {
        self.onScroll = onScroll
        super.init(rootView: rootView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(rootView: Content) {
        fatalError("init(rootView:) has not been implemented")
    }
    
    override func scrollWheel(with event: NSEvent) {
        onScroll(event.scrollingDeltaY)
    }
}
