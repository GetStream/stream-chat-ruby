# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

## [2.22.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.21.0...v2.22.0) (2022-04-01)


### Features

* add new device field ([#90](https://github.com/GetStream/stream-chat-ruby/issues/90)) ([aa6723c](https://github.com/GetStream/stream-chat-ruby/commit/aa6723cd54e58aab0f1b8c55bc4e54211ab39f3c))
* add new moderation apis ([#88](https://github.com/GetStream/stream-chat-ruby/issues/88)) ([573c586](https://github.com/GetStream/stream-chat-ruby/commit/573c58650392eaa5a6d38b4423e170e30b3e98df))
* add push provider apis ([#89](https://github.com/GetStream/stream-chat-ruby/issues/89)) ([d592fba](https://github.com/GetStream/stream-chat-ruby/commit/d592fba4c0041102fa18d0fee11961f881414337))
* **update_user:** deprecate update in favor of upsert ([#91](https://github.com/GetStream/stream-chat-ruby/issues/91)) ([74d3163](https://github.com/GetStream/stream-chat-ruby/commit/74d316339b277b0f9cf0f94f40f11aae30fd7644))

## [2.21.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.20.0...v2.21.0) (2022-03-03)


### Features

* add options to delete message ([#80](https://github.com/GetStream/stream-chat-ruby/issues/80)) ([6a343e9](https://github.com/GetStream/stream-chat-ruby/commit/6a343e9fa9409150c27afc4246765f07bb12e571))
* add sorbet type checker ([#83](https://github.com/GetStream/stream-chat-ruby/issues/83)) ([f2fcee5](https://github.com/GetStream/stream-chat-ruby/commit/f2fcee58ecc0c3b4016721e997c42c44753bba9a))


### Bug Fixes

* update app settings ([#86](https://github.com/GetStream/stream-chat-ruby/issues/86)) ([3f88185](https://github.com/GetStream/stream-chat-ruby/commit/3f88185117c5710e0b3e66f7f402f2c8969dec2f))

## [2.20.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.19.0...v2.20.0) (2022-02-04)


### Features

* add helper for invitation acceptance and rejection ([#78](https://github.com/GetStream/stream-chat-ruby/issues/78)) ([c950694](https://github.com/GetStream/stream-chat-ruby/commit/c950694a0ac2b0906d7bedb4ebc9a1af00eea606))

## [2.19.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.18.0...v2.19.0) (2022-02-02)


### Features

* ability to provide custom http client ([#75](https://github.com/GetStream/stream-chat-ruby/issues/75)) ([bfff20d](https://github.com/GetStream/stream-chat-ruby/commit/bfff20d06232c49a1a8d0eee255a718bfffbb351))
* add connection pooling and idle timeout ([#74](https://github.com/GetStream/stream-chat-ruby/issues/74)) ([7891005](https://github.com/GetStream/stream-chat-ruby/commit/78910053b3a15b1efa3183a71299068e63b128e3))
* env var handling enhancement ([#76](https://github.com/GetStream/stream-chat-ruby/issues/76)) ([0cdc38a](https://github.com/GetStream/stream-chat-ruby/commit/0cdc38abd671bfaa8cefa7f403b9e2ac8b642272))
> 🚨 Note: if you used `STREAM_CHAT_URL` env var, you'll need to provide it manually in the `**options` as `base_url`. See the initializer of `Client` class for more information.

## [2.18.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.17.2...v2.18.0) (2022-01-26)


### Features

* expose rate limits ([#72](https://github.com/GetStream/stream-chat-ruby/issues/72)) ([3f1ad5c](https://github.com/GetStream/stream-chat-ruby/commit/3f1ad5c8f43263424e934055d0ac283cdcce9376))
* full feature parity ([#71](https://github.com/GetStream/stream-chat-ruby/issues/71)) ([a25a1b6](https://github.com/GetStream/stream-chat-ruby/commit/a25a1b66f9eadd77d09b99d5c3cfba27bba52f17))

### [2.17.2](https://github.com/GetStream/stream-chat-ruby/compare/v2.17.1...v2.17.2) (2022-01-17)

### Features
* added some new metadata to the gemspec ([#69](https://github.com/GetStream/stream-chat-ruby/issues/69)) ([3e747bc](https://github.com/GetStream/stream-chat-ruby/commit/3e747bcd6aa338b08e136febfb0cf06f29d366b5))

### [2.17.1](https://github.com/GetStream/stream-chat-ruby/compare/v2.17.0...v2.17.1) (2022-01-17)


### Bug Fixes

* load faraday-mutipart error ([#67](https://github.com/GetStream/stream-chat-ruby/issues/67)) ([55ec107](https://github.com/GetStream/stream-chat-ruby/commit/55ec107fb4d6af887aa562c1e04d90a669c630cb))

## [2.17.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.16.0...v2.17.0) (2022-01-14)


### Features

* add options to add members ([#63](https://github.com/GetStream/stream-chat-ruby/issues/63)) ([89c9fa9](https://github.com/GetStream/stream-chat-ruby/commit/89c9fa98e19565c4b5353077523a1d407e1f10c9))

## [2.16.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.15.0...v2.16.0) (2021-12-01)

- Add permissions v2 APIs by @ffenix113 in #62

## [2.15.0](https://github.com/GetStream/stream-chat-ruby/compare/v2.14.0...v2.15.0) (2021-11-25)

- Add configuration support for channel truncate
  - truncated_at: to truncate channel up to given time
  - message: a system message to be added via truncation
  - skip_push: don't send a push notification for system message
  - hard_delete: true if truncation should delete messages instead of hiding

## November 24th, 2021 - 2.14.0

- Add new flags for export channels
  - clear_deleted_message_text (default: false)
  - include_truncated_messages (default: false)

## November 17th, 2021 - 2.13.0

- Add support for shadow banning user
  - shadow_ban
  - remove_shadow_ban
- Add support for pinning messages
  - pin_message
  - unpin_message
- Add support for partial updating messages
  - update_message_partial
- Add support for updating channel ownership for Deleted Users

## November 1st, 2021 - 2.12.0

- Add support for async endpoints
  - get_task
  - delete_channels
  - delete_users

## October 22nd, 2021 - 2.11.3

- Don't log the entire response when creating exception
- Access error details through StreamAPIException class attr_readers

## October 5th, 2021 - 2.11.2

- Add Codeowners file
- Fix StreamChannelException raises
- Fix rubocop linting error
- Fix channel export test
- Update Github action

## August 23rd, 2021 - 2.11.1

- Use edge as base url

## June 25th, 2021 - 2.11.0

- Add support for improved search

## June 4th, 2021 - 2.10.0

- Add custom command CRUD support

## May 31st, 2021 - 2.9.0

- Add support for app and user level token revoke

## May 21st, 2021 - 2.8.0

- Add query message flags support

## March 17th, 2021 - 2.7.0

- Add Ruby 3.x support
- Update CI to run all tests for all versions

## March 9th, 2021 - 2.6.0

- Add get_rate_limits endpoint

## February 3rd, 2021 - 2.5.0

- Add channel partial update
- Increase convenience in query members
- Improve internal symbol conversions

## January 20th, 2021 - 2.4.0

- Add query_members to channel
- Use post endpoint for query channels instead of get
- Extract common code for sorting into a helper for query calls

## January 5th, 2021 - 2.3.0

- Add check SQS helper

## January 4th, 2021 - 2.2.0

- Add support for export channels
- Improve readme for blocklist and export channels
- Improve running tests for multiple versions of ruby
- Fix issues from the latest version of rubocop
- Move to GitHub Actions

## October 5th, 2020 - 2.1.0

- Add support for blocklist

## October 2nd, 2020 - 2.0.0

- Drop EOL Ruby versions: 2.3 && 2.4
- Setup Rubocop and mark string literals as frozen

## August 3rd, 2020 - 1.1.3

- Fixed Argument Error on delete_user

## April 23th, 2020 - 1.1.2

- Fixed ArgumentError when no users was passed

## March 30th, 2020 - 1.1.1

- Fixed few minor issues

## Oct 27th, 2019 - 1.1.0

- Mark gems use for testing as development dependencies
- Added `send_file`, `send_image`, `delete_file`, `delete_image`
- Added `invite_members`

## Oct 19th, 2019 - 1.0.0

- Added `channel.hide` and `channel.show`
- Added `client.flag_message` and `client.unflag_message`
- Added `client.flag_user` and `client.unflag_user`
- Added `client.get_message`
- Added `client.search`
- Added `client.update_users_partial`
- Added `client.update_user_partial`
- Added `client.reactivate_user`
