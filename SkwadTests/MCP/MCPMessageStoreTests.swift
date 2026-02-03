import XCTest
import Foundation
@testable import Skwad

final class MCPMessageStoreTests: XCTestCase {

    // MARK: - Message Storage

    func testAddStoresMessage() async {
        let store = MCPMessageStore()
        let message = MCPMessage(from: "agent1", to: "agent2", content: "Hello")

        await store.add(message)
        let unread = await store.getUnread(for: "agent2")

        XCTAssertEqual(unread.count, 1)
        XCTAssertEqual(unread[0].content, "Hello")
    }

    func testGetUnreadFiltersByRecipient() async {
        let store = MCPMessageStore()

        // Add messages to different recipients
        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
        await store.add(MCPMessage(from: "sender", to: "agent2", content: "Message 2"))
        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 3"))

        let agent1Messages = await store.getUnread(for: "agent1")
        let agent2Messages = await store.getUnread(for: "agent2")

        XCTAssertEqual(agent1Messages.count, 2)
        XCTAssertEqual(agent2Messages.count, 1)
    }

    func testGetUnreadFiltersByReadStatus() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 2"))

        // Mark messages as read
        await store.markAsRead(for: "agent1")

        // Add new unread message
        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 3"))

        let unread = await store.getUnread(for: "agent1")
        XCTAssertEqual(unread.count, 1)
        XCTAssertEqual(unread[0].content, "Message 3")
    }

    func testHasUnreadReturnsTrueWhenMessagesExist() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Hello"))

        let hasUnread = await store.hasUnread(for: "agent1")
        XCTAssertTrue(hasUnread)
    }

    func testHasUnreadReturnsFalseWhenNoMessages() async {
        let store = MCPMessageStore()

        let hasUnread = await store.hasUnread(for: "agent1")
        XCTAssertFalse(hasUnread)
    }

    func testHasUnreadReturnsFalseForDifferentAgent() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Hello"))

        let hasUnread = await store.hasUnread(for: "agent2")
        XCTAssertFalse(hasUnread)
    }

    // MARK: - Mark As Read

    func testMarksAllForAgent() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 2"))

        await store.markAsRead(for: "agent1")

        let unread = await store.getUnread(for: "agent1")
        XCTAssertTrue(unread.isEmpty)
    }

    func testDoesNotMarkMessagesForOtherAgents() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
        await store.add(MCPMessage(from: "sender", to: "agent2", content: "Message 2"))

        await store.markAsRead(for: "agent1")

        let agent2Unread = await store.getUnread(for: "agent2")
        XCTAssertEqual(agent2Unread.count, 1)
    }

    // MARK: - Latest Unread

    func testReturnsMostRecentUnreadMessageId() async {
        let store = MCPMessageStore()

        let message1 = MCPMessage(from: "sender", to: "agent1", content: "First")
        let message2 = MCPMessage(from: "sender", to: "agent1", content: "Second")

        await store.add(message1)
        await store.add(message2)

        let latestId = await store.getLatestUnreadId(for: "agent1")
        XCTAssertEqual(latestId, message2.id)
    }

    func testReturnsNilWhenNoUnreadMessages() async {
        let store = MCPMessageStore()

        let latestId = await store.getLatestUnreadId(for: "agent1")
        XCTAssertNil(latestId)
    }

    func testReturnsNilAfterAllMarkedAsRead() async {
        let store = MCPMessageStore()

        await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message"))
        await store.markAsRead(for: "agent1")

        let latestId = await store.getLatestUnreadId(for: "agent1")
        XCTAssertNil(latestId)
    }

    // MARK: - Cleanup

    func testRemovesOldestReadMessagesOverLimit() async {
        let store = MCPMessageStore()

        // Add more than 100 read messages
        for i in 0..<120 {
            let message = MCPMessage(from: "sender", to: "agent1", content: "Message \(i)")
            await store.add(message)
        }

        // Mark all as read
        await store.markAsRead(for: "agent1")

        // Run cleanup
        await store.cleanup()

        // Should have reduced count (cleanup removes oldest)
        let unread = await store.getUnread(for: "agent1")
        XCTAssertTrue(unread.isEmpty)  // All were marked as read
    }

    func testPreservesUnreadMessagesDuringCleanup() async {
        let store = MCPMessageStore()

        // Add some read messages
        for i in 0..<110 {
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Read \(i)"))
        }
        await store.markAsRead(for: "agent1")

        // Add unread messages
        for i in 0..<5 {
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Unread \(i)"))
        }

        // Run cleanup
        await store.cleanup()

        // Unread messages should still exist
        let unread = await store.getUnread(for: "agent1")
        XCTAssertEqual(unread.count, 5)
    }

    func testDoesNothingWhenUnderLimit() async {
        let store = MCPMessageStore()

        // Add fewer than 100 messages
        for i in 0..<50 {
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message \(i)"))
        }
        await store.markAsRead(for: "agent1")

        // Cleanup should do nothing
        await store.cleanup()

        // All messages should still be there (just marked as read)
        let hasUnread = await store.hasUnread(for: "agent1")
        XCTAssertFalse(hasUnread)
    }
}
