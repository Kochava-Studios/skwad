import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

@MainActor
final class AgentSheetUITests: XCTestCase {

    private func createAgentManager() -> AgentManager {
        let manager = AgentManager()
        // Ensure there's a workspace
        if manager.workspaces.isEmpty {
            manager.workspaces = [Workspace.createDefault()]
            manager.currentWorkspaceId = manager.workspaces.first?.id
        }
        return manager
    }

    // MARK: - New Agent Mode (using prefill to avoid crash)
    // Note: AgentSheet() without params causes test runner crash, so we use prefill

    func testNewModeRendersNewAgentTitle() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTitle = texts.contains { (try? $0.string() == "New Agent") ?? false }
        XCTAssertTrue(hasTitle, "Should show 'New Agent' title")
    }

    func testNewModeRendersSubtitle() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasSubtitle = texts.contains { (try? $0.string().contains("skwad")) ?? false }
        XCTAssertTrue(hasSubtitle, "Should show subtitle mentioning skwad")
    }

    func testNewModeRendersNameField() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let textField = try? view.inspect().find(ViewType.TextField.self)
        XCTAssertNotNil(textField, "Should have a name TextField")
    }

    func testNewModeRendersNameLabel() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { (try? $0.string() == "Name") ?? false }
        XCTAssertTrue(hasLabel, "Should show 'Name' label")
    }

    func testNewModeRendersAvatarLabel() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { (try? $0.string() == "Avatar") ?? false }
        XCTAssertTrue(hasLabel, "Should show 'Avatar' label")
    }

    func testNewModeRendersCodingAgentLabel() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { (try? $0.string() == "Coding Agent") ?? false }
        XCTAssertTrue(hasLabel, "Should show 'Coding Agent' label in new mode")
    }

    func testNewModeRendersFolderOrRepositoryLabel() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        // Could be "Folder" or "Repository" depending on settings
        let hasLabel = texts.contains { text in
            let str = try? text.string()
            return str == "Folder" || str == "Repository"
        }
        XCTAssertTrue(hasLabel, "Should show 'Folder' or 'Repository' label")
    }

    func testNewModeRendersAvatarView() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let avatarView = try? view.inspect().find(AvatarView.self)
        XCTAssertNotNil(avatarView, "Should render AvatarView for avatar selection")
    }

    func testNewModeRendersFormLayout() throws {
        let prefill = AgentPrefill(name: "", avatar: nil, folder: "", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let form = try? view.inspect().find(ViewType.Form.self)
        XCTAssertNotNil(form, "Should use Form layout")
    }

    // MARK: - Edit Agent Mode

    func testEditModeRendersEditTitle() throws {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        let view = AgentSheet(editing: agent)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTitle = texts.contains { (try? $0.string() == "Edit Agent") ?? false }
        XCTAssertTrue(hasTitle, "Should show 'Edit Agent' title in edit mode")
    }

    func testEditModeRendersUpdateSubtitle() throws {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        let view = AgentSheet(editing: agent)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasSubtitle = texts.contains { (try? $0.string().contains("Update")) ?? false }
        XCTAssertTrue(hasSubtitle, "Should show 'Update' in subtitle in edit mode")
    }

    func testEditModeHidesCodingAgentPicker() throws {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        let view = AgentSheet(editing: agent)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasCodingAgentLabel = texts.contains { (try? $0.string() == "Coding Agent") ?? false }
        XCTAssertFalse(hasCodingAgentLabel, "Should NOT show 'Coding Agent' label in edit mode")
    }

    func testEditModeShowsFolderPath() throws {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        let view = AgentSheet(editing: agent)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        // Should show the folder path (possibly shortened)
        let hasFolderPath = texts.contains { (try? $0.string().contains("test")) ?? false }
        XCTAssertTrue(hasFolderPath, "Should show folder path in edit mode")
    }

    // MARK: - Prefill Mode

    func testPrefillModeShowsNewAgentTitle() throws {
        let prefill = AgentPrefill(name: "Prefilled", avatar: "🚀", folder: "/tmp/prefill", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTitle = texts.contains { (try? $0.string() == "New Agent") ?? false }
        XCTAssertTrue(hasTitle, "Prefill mode should show 'New Agent' title")
    }

    func testPrefillModeShowsCodingAgentPicker() throws {
        let prefill = AgentPrefill(name: "Prefilled", avatar: "🚀", folder: "/tmp/prefill", agentType: "claude", insertAfterId: nil)
        let view = AgentSheet(prefill: prefill)
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { (try? $0.string() == "Coding Agent") ?? false }
        XCTAssertTrue(hasLabel, "Prefill mode should show 'Coding Agent' picker")
    }
}

// MARK: - AvatarPickerView Tests

@MainActor
final class AvatarPickerViewUITests: XCTestCase {

    func testRendersLazyVGrid() throws {
        var selection = "🤖"
        let view = AvatarPickerView(
            selection: .init(get: { selection }, set: { selection = $0 }),
            emojiOptions: ["🤖", "🚀", "💻"],
            onImagePick: {}
        )
        let grid = try? view.inspect().find(ViewType.LazyVGrid.self)
        XCTAssertNotNil(grid, "Should render LazyVGrid for emoji options")
    }

    func testRendersEmojiOptions() throws {
        var selection = "🤖"
        let view = AvatarPickerView(
            selection: .init(get: { selection }, set: { selection = $0 }),
            emojiOptions: ["🤖", "🚀", "💻"],
            onImagePick: {}
        )
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasRocket = texts.contains { (try? $0.string() == "🚀") ?? false }
        XCTAssertTrue(hasRocket, "Should render emoji options")
    }

    func testRendersChooseImageButton() throws {
        var selection = "🤖"
        let view = AvatarPickerView(
            selection: .init(get: { selection }, set: { selection = $0 }),
            emojiOptions: ["🤖"],
            onImagePick: {}
        )
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasChooseImage = texts.contains { (try? $0.string().contains("Choose Image")) ?? false }
        XCTAssertTrue(hasChooseImage, "Should render 'Choose Image' button")
    }

    func testRendersDivider() throws {
        var selection = "🤖"
        let view = AvatarPickerView(
            selection: .init(get: { selection }, set: { selection = $0 }),
            emojiOptions: ["🤖"],
            onImagePick: {}
        )
        let divider = try? view.inspect().find(ViewType.Divider.self)
        XCTAssertNotNil(divider, "Should have Divider between grid and button")
    }
}

// MARK: - ImageCropperSheet Tests

@MainActor
final class ImageCropperSheetUITests: XCTestCase {

    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        return image
    }

    func testRendersTitle() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTitle = texts.contains { (try? $0.string() == "Adjust Avatar") ?? false }
        XCTAssertTrue(hasTitle, "Should render 'Adjust Avatar' title")
    }

    func testRendersInstructions() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasInstructions = texts.contains { (try? $0.string().contains("Drag to position")) ?? false }
        XCTAssertTrue(hasInstructions, "Should render instructions")
    }

    func testRendersCancelButton() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        let hasCancelButton = buttons.contains { button in
            let texts = try? button.findAll(ViewType.Text.self)
            return texts?.contains { (try? $0.string() == "Cancel") ?? false } ?? false
        }
        XCTAssertTrue(hasCancelButton, "Should have Cancel button")
    }

    func testRendersDoneButton() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        let hasDoneButton = buttons.contains { button in
            let texts = try? button.findAll(ViewType.Text.self)
            return texts?.contains { (try? $0.string() == "Done") ?? false } ?? false
        }
        XCTAssertTrue(hasDoneButton, "Should have Done button")
    }

    func testRendersVStackLayout() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "Should render VStack layout")
    }

    func testRendersCircleOverlay() throws {
        let image = createTestImage()
        let view = ImageCropperSheet(image: image) { _ in }
        // Circle is used for the crop overlay
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should have ZStack for overlay")
    }
}

// MARK: - AgentPrefill Tests

final class AgentPrefillTests: XCTestCase {

    func testCreatesWithAllFields() {
        let insertId = UUID()
        let prefill = AgentPrefill(
            name: "Test Agent",
            avatar: "🚀",
            folder: "/tmp/test",
            agentType: "aider",
            insertAfterId: insertId
        )
        XCTAssertEqual(prefill.name, "Test Agent")
        XCTAssertEqual(prefill.avatar, "🚀")
        XCTAssertEqual(prefill.folder, "/tmp/test")
        XCTAssertEqual(prefill.agentType, "aider")
        XCTAssertEqual(prefill.insertAfterId, insertId)
    }

    func testCreatesWithNilAvatar() {
        let prefill = AgentPrefill(
            name: "Test",
            avatar: nil,
            folder: "/tmp",
            agentType: "claude",
            insertAfterId: nil
        )
        XCTAssertNil(prefill.avatar)
    }

    func testHasUniqueId() {
        let prefill1 = AgentPrefill(name: "A", avatar: nil, folder: "/a", agentType: "claude", insertAfterId: nil)
        let prefill2 = AgentPrefill(name: "B", avatar: nil, folder: "/b", agentType: "claude", insertAfterId: nil)
        XCTAssertNotEqual(prefill1.id, prefill2.id)
    }
}
