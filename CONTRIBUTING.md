# :recycle: Contributing

We welcome code changes that improve this library or fix a problem, please make sure to follow all best practices and add tests if applicable before submitting a Pull Request on Github. We are very happy to merge your code in the official repository. Make sure to sign our [Contributor License Agreement (CLA)](https://docs.google.com/forms/d/e/1FAIpQLScFKsKkAJI7mhCr7K9rEIOpqIDThrWxuvxnwUq2XkHyG154vQ/viewform) first. See our license file for more details.

## Getting started

### Install dependencies

```shell
$ bundle install --path vendor/bundle
```

### Run tests

```shell
$ STREAM_KEY=my_api_key STREAM_SECRET=my_api_secret bundle exec rspec spec
```

### Run specific test

Add :focus tag on target test:

```rb
it 'can mark messages as read', :focus do
    # test something
end
```

And then run as following:

```shell
$ STREAM_KEY=myapi_key STREAM_SECRET=my_secret STREAM_CHAT_URL=http://127.0.0.1:3030 bundle exec rspec spec --tag focus
```

### Linters and type check

We use [Rubocop](https://github.com/rubocop/rubocop) for linting and [Sorbet](https://sorbet.org/) for type checking.

To run them:
```shell
$ bundle exec rake rubocop
$ bundle exec srb tc
```

These linters can be easily integrated into IDEs such as RubyMine or VS Code.

For VS Code, just install the basic Ruby extension which handles Rubocop ([`rebornix.ruby`](https://marketplace.visualstudio.com/items?itemName=rebornix.Ruby)) and the official Sorbet one ([`sorbet.sorbet-vscode-extension`](https://marketplace.visualstudio.com/items?itemName=sorbet.sorbet-vscode-extension)).

Recommended settings:
```json
{
    "editor.formatOnSave": true,
    "ruby.useBundler": true,
    "ruby.lint": {
        "rubocop": {
            "useBundler": true, // enable rubocop via bundler
        }
    },
    "ruby.format": "rubocop",
    "ruby.useLanguageServer": true,
    "sorbet.enabled": true
}
```

For Docker-based development, you can use:

```shell
$ make lint_with_docker      # Run linters in Docker
$ make lint-fix_with_docker  # Fix linting issues in Docker
$ make test_with_docker      # Run tests in Docker
$ make check_with_docker     # Run both linters and tests in Docker
$ make sorbet_with_docker    # Run Sorbet type checker in Docker
```

You can customize the Ruby version used in Docker by setting the RUBY_VERSION variable:

```shell
$ RUBY_VERSION=3.1 make test_with_docker
```

By default, the API client connects to the production Stream Chat API. You can override this by setting the STREAM_CHAT_URL environment variable:

```shell
$ STREAM_CHAT_URL=http://localhost:3030 make test
```

When running tests in Docker, the `test_with_docker` command automatically sets up networking to allow the Docker container to access services running on your host machine via `host.docker.internal`. This is particularly useful for connecting to a local Stream Chat server:

```shell
$ STREAM_CHAT_URL=http://host.docker.internal:3030 make test_with_docker
```

### Commit message convention

This repository follows a commit message convention in order to automatically generate the [CHANGELOG](./CHANGELOG.md). Make sure you follow the rules of [conventional commits](https://www.conventionalcommits.org/) when opening a pull request.

### Releasing a new version (for Stream developers)

In order to release new version you need to be a maintainer of the library.

- Kick off a job called `initiate_release` ([link](https://github.com/GetStream/stream-chat-ruby/actions/workflows/initiate_release.yml)).

The job creates a pull request with the changelog. Check if it looks good.

- Merge the pull request.

Once the PR is merged, it automatically kicks off another job which will upload the Gem to RubyGems.org and creates a GitHub release.