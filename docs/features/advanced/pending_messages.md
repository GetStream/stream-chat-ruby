Pending Messages features lets you introduce asynchronous moderation on messages being sent on channel. To use this feature please get in touch with support so that we can enable it for your organisation.

## Sending Pending Messages

Messages can be made pending by default by setting the channel config property `mark_messages_pending` to true.

```ruby
# require 'stream-chat'

@client.update_channel_type('messaging', mark_messages_pending: true)
```

You can also set the `pending` property on a message to mark it as pending on server side (this will override the channel configuration). **Please note that this is only server-side feature** .

```ruby
options = {
   pending: true,
   pending_message_metadata: {
    metadata: 'some_data'
   }
  }
  msg = @channel.send_message({ text: 'hi' }, @random_user[:id], **options)
```

Pending messages will only be visible to the user that sent them. They will not be query-able by other users.

## Callbacks

When a pending message is either sent or deleted, the message and its associated pending message metadata are forwarded to your configured callback endpoint via HTTP(s). You may set up to two pending message hooks per application. Only the first commit to a pending message will succeed; any subsequent commit attempts will return an error, as the message is no longer pending. If multiple hooks specify a `timeout_ms`, the system will use the longest timeout value.

You can configure this callback using the dashboard or server-side SDKs.

### Using the Dashboard

1. Go to the [Stream Dashboard](https://getstream.io/dashboard/)
2. Select your app
3. Navigate to your app's settings until "Webhook & Event Configuration" section
4. Click on "Add Integration"
5. Add and configure pending message hook

![](@chat/_default/_assets/images/pending_message_dashboard.png)

### Using Server-Side SDKs

```ruby
# Note: Any previously existing hooks not included in event_hooks array will be deleted.
# Get current settings first to preserve your existing configuration.

# STEP 1: Get current app settings to preserve existing hooks
response = client.get_app_settings
existing_hooks = response["event_hooks"] || []
puts "Current event hooks:", existing_hooks

# STEP 2: Add pending message hook while preserving existing hooks
new_pending_message_hook = {
  "enabled" => true,
  "hook_type" => "pending_message",
  "webhook_url" => "https://example.com/pending-messages",
  "timeout_ms" => 10000, # how long messages should stay pending before being deleted
  "callback" => {
    "mode" => "CALLBACK_MODE_REST"
  }
}

# STEP 3: Update with complete array including existing hooks
client.update_app_settings(
  event_hooks: existing_hooks + [new_pending_message_hook]
)
```

See the [Webhooks](/chat/docs/ruby/webhooks_overview/) documentation for complete details.

### Callback Request

For example, if your callback server url is <https://example.com>, we would send callbacks:

- When pending message is sent

`POST https://example.com/PassOnPendingMessage`

- When a pending message is deleted

`POST https://https://example.com/DeletedPendingMessage`

In both callbacks, the body of the POST request will be of the form:

```json
{
  "message": {
    // the message object
  },
  "metadata": {
    // keys and values that you passed as pending_message_metadata
  },
  "request_info": {
    // request info of the request that sent the pending message. Example:
    /*
    "type": "client",
    "ip": "127.0.0.1",
    "user_agent": "Mozilla/5.0...",
    "sdk": "stream-chat-js",
    "ext": "additional-data"
    */
  }
}
```

## Deleting pending messages

Pending messages can be deleted using the normal delete message endpoint. Users are only able to delete their own pending messages. The messages must be hard deleted. Soft deleting a pending message will return an error.

## Updating pending messages

Pending messages cannot be updated.

## Querying pending messages

A user can retrieve their own pending messages using the following endpoints:

```ruby
# To retrieve single message
message = @client.get_message(msg_id)[:message]

# To retrieve multiple messages
messages = @channel.get_messages(['message-1', 'message-2'])[:messages]
```

## Query channels

Each channel that is returned from query channels will also have an array of `pending_messages` . These are pending messages that were sent to this channel, and belong to the user who made the query channels call. This array will contain a maximum of 100 messages and these will be the 100 most recently sent messages.

```ruby
response = @client.query_channels({ 'members' => { '$in' => ['legolas'] } }, sort: { 'id' => 1 })

# Access pending messages
# response['channels'][0]['pending_messages']
```

## Committing pending messages

Calling the commit message endpoint will promote a pending message into a normal message. This message will then be visible to other users and any events/push notifications associated with the message will be sent.

The commit message endpoint is server-side only.

```ruby
@client.commit_message('message-1')
```

If a message has been in the pending state longer than the `timeout_ms` defined for your app, then the pending message will be deleted. The default timeout for a pending message is 3 days.
