# Send Message

Use the `send-message` MCP tool based on arguments: $ARGUMENTS.
If arguments are empty, try to deduce the recipient and message from context.
If you can't, ask more details to the user.

`send-message` parameters:
- `from`: Your agent ID (provided at registration)
- `to`: Recipient agent name or ID
- `content`: Message content

First call `list-agents` to find available agents, then send the message.
