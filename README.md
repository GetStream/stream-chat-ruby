# stream-chat-ruby

 [![build](https://github.com/GetStream/stream-chat-ruby/workflows/build/badge.svg)](https://github.com/GetStream/stream-chat-ruby/actions) [![Gem Version](https://badge.fury.io/rb/stream-chat-ruby.svg)](http://badge.fury.io/rb/stream-chat-ruby)

stream-chat-ruby is the official Ruby client for [Stream chat](https://getstream.io/chat/) a service for building chat applications.

You can sign up for a Stream account at https://getstream.io/chat/get_started/.

You can use this library to access chat API endpoints server-side. For the
client-side integrations (web and mobile) have a look at the Javascript, iOS and
Android SDK libraries (https://getstream.io/chat/).

### Installation

stream-chat-ruby supports:

- Ruby (2.7, 2.6, 2.5)

#### Install

```bash
gem install stream-chat-ruby
```

### Documentation

[Official API docs](https://getstream.io/chat/docs/)

### Supported features

- Chat channel type, channels and members
- Messages
- User management
- Moderation API
- Push configuration
- User devices
- User search
- Channel search
- Blocklists
- Export channels

### Import

```ruby
require 'stream-chat'
```

### Initialize client

```ruby
client = StreamChat::Client.new(api_key='STREAM_KEY', api_secret='STREAM_SECRET')
```

### Generate a token for client side use

```ruby
client.create_token('bob-1')
```

### Create/Update users

```ruby
client.update_user({
    :id => 'bob-1',
    :role => 'admin',
    :name => 'Robert Tables'
})

# batch update is also supported
jane = ...
june = ...
client.update_users([jane, june])
```

### Channel types CRUD

```ruby
# Create
client.create_channel_type({
    'name' => 'livechat',
    'automod' => 'disabled',
    'commands' => ['ban'],
    'mutes' => true
})

# Update
client.update_channel_type('livechat', 'automod' => 'enabled'})

# Get
client.get_channel_type('livechat')

# List
client.list_channel_types

# Delete
client.delete_channel_type('livechat')
```

### Channels

```ruby
# Create a channel with members from the start
chan = client.channel("messaging", channel_id: "bob-and-jane", data: {'members'=> ['bob-1', 'jane-77']})
chan.create('bob-1')

# Create a channel and then add members
chan = client.channel("messaging", channel_id: "bob-and-jane")
chan.create('bob-1')
chan.add_members(['bob-1', 'jane-77'])

# Send messages
m1 = chan.send_message({'text' => 'Hi Jane!'}, 'bob-1')
m2 = chan.send_message({'text' => 'Hi Bob'}, 'jane-77')

# Send replies
r1 = chan.send_message({'text' => 'And a good day!', 'parent_id' => m1['id']}, 'bob-1')

# Send reactions
chan.send_reaction(m1['id'], {'type' => 'like'}, 'bob-1')

# Add/remove moderators
chan.add_moderators(['jane-77'])
chan.demote_moderators(['bob-1'])

# Add a ban with a timeout
chan.ban_user('bob-1', timeout: 30)

# Remove a ban
chan.unban_user('bob-1')

# Query channel state
chan.query({'messages' => { 'limit' => 10, 'id_lte' => m1['id']}})

# Update metadata (overwrite)
chan.update({'motd' => 'one apple a day....'})

# Update partial
# 1. key-value pairs to set
# 2. keys to unset (remove)
chan.update_partial({color: 'blue', age: 30}, ['motd'])

# Query channel members
chan.query_members({name: {'$autocomplete': 'test'}}, sort: {last_created_at: -1}, offset: 5, limit: 5)
```

### Messages

```ruby
# Delete a message from any channel by ID
deleted_message = client.delete_message(r1['id'])

```

### Devices

```ruby
# Add device
jane_phone = client.add_device({'id' => 'iOS Device Token', 'push_provider' => push_provider.apn, 'user_id' => 'jane-77'})

# List devices
client.get_devices('jane-77')

# Remove device
client.remove_device(jane_phone['id'], jane_phone['user_id'])
```

### Blocklists
```ruby
# Create a blocklist
client.create_blocklist('my_blocker', %w[fudge cream sugar])

# Enable it on messaging channel type
client.update_channel_type('messaging', blocklist: 'my_blocker', blocklist_behavior: 'block')

# Get the details of the blocklist
client.get_blocklist('my_blocker')

# Delete the blocklist
client.delete_blocklist('my_blocker')
```

### Export Channels
```ruby
# Register an export
response = client.export_channels({type: 'messaging', id: 'jane'})

# Check completion
status_response = client.get_export_channel_status(response['task_id'])
# status_response['status'] == 'pending', 'completed'
```

### Example Rails application

See [an example rails application using the Ruby SDK](https://github.com/GetStream/rails-chat-example).

### Contributing

First, make sure you can run the test suite. Tests are run via rspec

```bash
STREAM_CHAT_API_KEY=my_api_key STREAM_CHAT_API_SECRET=my_api_secret bundle exec rake spec
```

### Releasing a new version

In order to release new version you need to be a maintainer of the library.

- Update CHANGELOG
- Update the version in `lib/stream-chat/version.rb`
- Commit and push to GitHub
- Build the gem with `bundle exec rake build`
- Publish the gem with `bundle exec rake release`
