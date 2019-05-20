# stream-chat-ruby

[![Build Status](https://travis-ci.com/GetStream/stream-chat-ruby.svg?branch=master)](https://travis-ci.com/GetStream/stream-chat-ruby) [![Gem Version](https://badge.fury.io/rb/stream-chat-ruby.svg)](http://badge.fury.io/rb/stream-chat-ruby)

stream-chat-ruby is the official Ruby client for [Stream chat](https://getstream.io/chat/) a service for building chat applications.

You can sign up for a Stream account at https://getstream.io/chat/get_started/.

You can use this library to access chat API endpoints server-side. For the
client-side integrations (web and mobile) have a look at the Javascript, iOS and
Android SDK libraries (https://getstream.io/chat/).

### Installation

stream-chat-ruby supports:

- Ruby (2.6, 2.5, 2.4, 2.3)

#### Install

```bash
gem install stream-chat-ruby
```

### Documentation

[Official API docs](https://getstream.io/chat/docs/)

### How to build a chat app with Ruby tutorial

TODO: add a sample Ruby chat program

### Supported features

- Chat channels
- Messages
- Chat channel types
- User management
- Moderation API
- Push configuration
- User devices
- User search
- Channel search

### Quickstart

```ruby
chat = StreamChat::Client.new(api_key='STREAM_KEY', api_secret='STREAM_SECRET')

# add a user
chat.update_user({'id' => 'chuck', 'name' => 'Chuck'})

# create a channel about kung-fu
channel = chat.channel('messaging', 'kung-fu')
channel.create('chuck')

# add a first message to the channel
channel.send_message({'text' => 'AMA about kung-fu'})

```

### Contributing

First, make sure you can run the test suite. Tests are run via rspec

```bash
STREAM_KEY=my_api_key STREAM_SECRET=my_api_secret bundle exec rake spec
```

### Releasing a new version

In order to release new version you need to be a maintainer of the library.

- Update CHANGELOG
- Update the version in `lib/stream-chat/version.rb`
- Commit and push to GitHub
- Build the gem with `bundle exec rake build`
- Publish the gem with `bundle exec rake release`
