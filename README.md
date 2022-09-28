# Official Ruby SDK for [Stream Chat](https://getstream.io/chat/)

[![build](https://github.com/GetStream/stream-chat-ruby/workflows/build/badge.svg)](https://github.com/GetStream/stream-chat-ruby/actions) [![Gem Version](https://badge.fury.io/rb/stream-chat-ruby.svg)](http://badge.fury.io/rb/stream-chat-ruby)

<p align="center">
    <img src="./assets/logo.svg" width="50%" height="50%">
</p>
<p align="center">
    Official Ruby API client for Stream Chat, a service for building chat applications.
    <br />
    <a href="https://getstream.io/chat/docs/"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/GetStream/rails-chat-example">Code Samples</a>
    ·
    <a href="https://github.com/GetStream/stream-chat-ruby/issues">Report Bug</a>
    ·
    <a href="https://github.com/GetStream/stream-chat-ruby/issues">Request Feature</a>
</p>

## 📝 About Stream

You can sign up for a Stream account at our [Get Started](https://getstream.io/chat/get_started/) page.

You can use this library to access chat API endpoints server-side.

For the client-side integrations (web and mobile) have a look at the JavaScript, iOS and Android SDK libraries ([docs](https://getstream.io/chat/)).

## ⚙️ Installation

[`stream-chat-ruby`](https://rubygems.org/gems/stream-chat-ruby) supports:

- Ruby (2.5, 2.6, 2.7, 3.0, 3.1)

```bash
$ gem install stream-chat-ruby
```

## ✨ Getting started

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')
```

> 💡 Note: since v2.21.0 we implemented [Sorbet](https://sorbet.org/) type checker. As of v2.x.x we only use it for static type checks and you won't notice any difference, but from v3.0.0 **we will enable runtime checks** 🚨 🚨 🚨.

> What this means, is that you'll receive an error during runtime if you pass an invalid type to our methods. To prepare for that, just make sure whatever you pass in, matches the method signature (`sig { ... }`).

> **Update (2022-May-24)**: we have relased [v3.0.0](https://github.com/GetStream/stream-chat-ruby/releases/tag/v3.0.0) with enabled runtime checks.
 
---

> Additionally, in a future major version, we would like to enforce symbol hash keys during runtime to conform to Ruby best practises. It's a good idea to prepare your application for that.
> ```ruby
> # Wrong:
> user = { "user" => { "id" => "bob-1"}}
> # Correct:
> user = { :user => { :id => "bob-1" }}
> ```

### Generate a token for client-side usage:

```ruby
client.create_token('bob-1')
```

### Create/Update users

```ruby
client.upsert_user({
    :id => 'bob-1',
    :role => 'admin',
    :name => 'Robert Tables'
})

# Batch update is also supported
jane = {:id => 'jane-1'}
june = {:id => 'june-1'}
client.upsert_users([jane, june])
```

### Channel types

```ruby
client.create_channel_type({
    :name => 'livechat',
    :automod => 'disabled',
    :commands => ['ban'],
    :mutes => true
})

channel_types = client.list_channel_types()
```

### Channels

```ruby
# Create a channel with members from the start
chan = client.channel("messaging", channel_id: "bob-and-jane", data: {:members => ['bob-1', 'jane-77']})
chan.create('bob-1')

# Create a channel and then add members
chan = client.channel("messaging", channel_id: "bob-and-jane")
chan.create('bob-1')
chan.add_members(['bob-1', 'jane-77'])
```

### Reactions
```ruby
chan.send_reaction(m1['id'], {:type => 'like'}, 'bob-1')
```

### Moderation
```ruby
chan.add_moderators(['jane-77'])
chan.demote_moderators(['bob-1'])

chan.ban_user('bob-1', timeout: 30)

chan.unban_user('bob-1')
```

### Messages

```ruby
m1 = chan.send_message({:text => 'Hi Jane!'}, 'bob-1')

deleted_message = client.delete_message(m1['message']['id'])

```

### Devices

```ruby
jane_phone = client.add_device({:id => 'iOS Device Token', :push_provider => push_provider.apn, :user_id => 'jane-77'})

client.get_devices('jane-77')

client.remove_device(jane_phone['id'], jane_phone['user_id'])
```

### Blocklists

```ruby
client.create_blocklist('my_blocker', %w[fudge cream sugar])

# Enable it on 'messaging' channel type
client.update_channel_type('messaging', blocklist: 'my_blocker', blocklist_behavior: 'block')

client.get_blocklist('my_blocker')

client.delete_blocklist('my_blocker')
```

### Export Channels

```ruby
# Register an export
response = client.export_channels({:type => 'messaging', :id => 'jane'})

# Check completion
status_response = client.get_export_channel_status(response['task_id'])
# status_response['status'] == 'pending', 'completed'
```

### Rate limits

```ruby
# Get all rate limits
limits = client.get_rate_limits

# Get rate limits for specific platform(s)
limits = client.get_rate_limits(server_side: true)

# Get rate limits for specific platforms and endpoints
limits = client.get_rate_limits(android: true, ios: true, endpoints: ['QueryChannels', 'SendMessage'])
```

## ✍️ Contributing

We welcome code changes that improve this library or fix a problem, please make sure to follow all best practices and add tests if applicable before submitting a Pull Request on Github. We are very happy to merge your code in the official repository. Make sure to sign our [Contributor License Agreement (CLA)](https://docs.google.com/forms/d/e/1FAIpQLScFKsKkAJI7mhCr7K9rEIOpqIDThrWxuvxnwUq2XkHyG154vQ/viewform) first. See our [license file](./LICENSE) for more details.

Head over to [CONTRIBUTING.md](./CONTRIBUTING.md) for some development tips.

## 🧑‍💻 We are hiring!

We've recently closed a [$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.

Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).
