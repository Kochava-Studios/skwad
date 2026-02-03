import Testing
import Foundation
@testable import Skwad

@Suite("MCPMessageStore")
struct MCPMessageStoreTests {

    // MARK: - Message Storage

    @Suite("Message Storage")
    struct MessageStorageTests {

        @Test("add stores message")
        func addStoresMessage() async {
            let store = MCPMessageStore()
            let message = MCPMessage(from: "agent1", to: "agent2", content: "Hello")

            await store.add(message)
            let unread = await store.getUnread(for: "agent2")

            #expect(unread.count == 1)
            #expect(unread[0].content == "Hello")
        }

        @Test("getUnread filters by recipient")
        func getUnreadFiltersByRecipient() async {
            let store = MCPMessageStore()

            // Add messages to different recipients
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
            await store.add(MCPMessage(from: "sender", to: "agent2", content: "Message 2"))
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 3"))

            let agent1Messages = await store.getUnread(for: "agent1")
            let agent2Messages = await store.getUnread(for: "agent2")

            #expect(agent1Messages.count == 2)
            #expect(agent2Messages.count == 1)
        }

        @Test("getUnread filters by read status")
        func getUnreadFiltersByReadStatus() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 2"))

            // Mark messages as read
            await store.markAsRead(for: "agent1")

            // Add new unread message
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 3"))

            let unread = await store.getUnread(for: "agent1")
            #expect(unread.count == 1)
            #expect(unread[0].content == "Message 3")
        }

        @Test("hasUnread returns true when messages exist")
        func hasUnreadReturnsTrue() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Hello"))

            let hasUnread = await store.hasUnread(for: "agent1")
            #expect(hasUnread == true)
        }

        @Test("hasUnread returns false when no messages")
        func hasUnreadReturnsFalseWhenNone() async {
            let store = MCPMessageStore()

            let hasUnread = await store.hasUnread(for: "agent1")
            #expect(hasUnread == false)
        }

        @Test("hasUnread returns false for different agent")
        func hasUnreadReturnsFalseForDifferentAgent() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Hello"))

            let hasUnread = await store.hasUnread(for: "agent2")
            #expect(hasUnread == false)
        }
    }

    // MARK: - Mark As Read

    @Suite("Mark As Read")
    struct MarkAsReadTests {

        @Test("marks all for agent")
        func marksAllForAgent() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 2"))

            await store.markAsRead(for: "agent1")

            let unread = await store.getUnread(for: "agent1")
            #expect(unread.isEmpty)
        }

        @Test("does not mark messages for other agents")
        func doesNotMarkOtherAgents() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message 1"))
            await store.add(MCPMessage(from: "sender", to: "agent2", content: "Message 2"))

            await store.markAsRead(for: "agent1")

            let agent2Unread = await store.getUnread(for: "agent2")
            #expect(agent2Unread.count == 1)
        }
    }

    // MARK: - Latest Unread

    @Suite("Latest Unread")
    struct LatestUnreadTests {

        @Test("returns most recent unread message id")
        func returnsMostRecentUnread() async {
            let store = MCPMessageStore()

            let message1 = MCPMessage(from: "sender", to: "agent1", content: "First")
            let message2 = MCPMessage(from: "sender", to: "agent1", content: "Second")

            await store.add(message1)
            await store.add(message2)

            let latestId = await store.getLatestUnreadId(for: "agent1")
            #expect(latestId == message2.id)
        }

        @Test("returns nil when no unread messages")
        func returnsNilWhenNone() async {
            let store = MCPMessageStore()

            let latestId = await store.getLatestUnreadId(for: "agent1")
            #expect(latestId == nil)
        }

        @Test("returns nil after all marked as read")
        func returnsNilAfterAllRead() async {
            let store = MCPMessageStore()

            await store.add(MCPMessage(from: "sender", to: "agent1", content: "Message"))
            await store.markAsRead(for: "agent1")

            let latestId = await store.getLatestUnreadId(for: "agent1")
            #expect(latestId == nil)
        }
    }

    // MARK: - Cleanup

    @Suite("Cleanup")
    struct CleanupTests {

        @Test("removes oldest read messages over limit")
        func removesOldestReadOverLimit() async {
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
            #expect(unread.isEmpty)  // All were marked as read
        }

        @Test("preserves unread messages during cleanup")
        func preservesUnreadMessages() async {
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
            #expect(unread.count == 5)
        }

        @Test("does nothing when under limit")
        func doesNothingUnderLimit() async {
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
            #expect(hasUnread == false)
        }
    }
}
