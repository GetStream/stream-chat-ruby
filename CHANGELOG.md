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
