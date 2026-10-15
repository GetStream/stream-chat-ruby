Scheduled messages let a user write a message now and have it sent to a channel later. Server-side, you can schedule, edit, cancel and list scheduled messages on behalf of any user.

Scheduled messages must be enabled for your app. Until the message is sent, only the user who scheduled it can see it; nothing is sent to the channel.

## Scheduling a Message

Send a message with a `scheduled_at` time. It must be at least 1 minute and at most the app's maximum lead time (120 days by default) from now. Slash commands and pending messages cannot be scheduled.

```ruby
response = channel.schedule_message({ 'text' => 'Good morning!' }, 'user-id', Time.now.utc + 3600)

scheduled_message_id = response['scheduled_message']['id']
```

The response carries `scheduled_message`. Its `id` is used to edit, cancel or send the message now. The `message` object in the response holds the content as it will be sent; it is not in the channel yet.

## Updating a Scheduled Message

Change the message, the send time, or both. A new message replaces the scheduled one as a whole; the sender stays the user it was scheduled for.

```ruby
client.update_scheduled_message(scheduled_message_id, message: { 'text' => 'Good afternoon!' })

client.update_scheduled_message(scheduled_message_id, scheduled_at: Time.now.utc + 7200)
```

## Sending a Scheduled Message Now

```ruby
client.send_scheduled_message_now(scheduled_message_id)
```

## Deleting a Scheduled Message

Deleting cancels a scheduled message so it is never sent, or removes a failed one.

```ruby
client.delete_scheduled_message(scheduled_message_id)
```

Updating, deleting or sending now fails with a 409 error while the message is being sent.

## Querying Scheduled Messages

List the scheduled messages of a user across channels: pending ones first, then failed ones, each by `scheduled_at`. You can filter by channel and status (`scheduled`, `sending`, `failed`).

```ruby
response = client.query_scheduled_messages('user-id', filter: { cid: 'messaging:general', status: ['failed'] }, limit: 20)

response['scheduled_messages'].each do |scheduled_message|
  puts scheduled_message['status']
end

# next page
client.query_scheduled_messages('user-id', limit: 20, next: response['next']) if response['next']
```

## Failed Messages

When a scheduled message cannot be sent, its status becomes `failed` and `failure_reason` says why: `banned`, `no_permission`, `channel_frozen`, `channel_deleted`, `user_deleted`, `moderation_blocked`, `hook_rejected`, `expired`, `internal_error`, `invalid_message` or `pending_not_supported`. A failed message is not retried; delete it, and schedule it again if needed.

## Webhooks

The `scheduled_message.sent` and `scheduled_message.failed` events are sent to webhooks. `scheduled_message.sent` carries the ID of the sent message in `message_id`.
