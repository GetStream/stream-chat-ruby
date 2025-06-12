STREAM_KEY ?= NOT_EXIST
STREAM_SECRET ?= NOT_EXIST
RUBY_VERSION ?= 3.0
STREAM_CHAT_URL ?= https://chat.stream-io-api.com

# These targets are not files
.PHONY: help check test lint lint-fix test_with_docker lint_with_docker lint-fix_with_docker

help: ## Display this help message
	@echo "Please use \`make <target>\` where <target> is one of"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; \
	{printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'

lint: ## Run linters
	bundle exec rubocop

lint-fix: ## Fix linting issues
	bundle exec rubocop -a

test: ## Run tests
	STREAM_KEY=$(STREAM_KEY) STREAM_SECRET=$(STREAM_SECRET) bundle exec rspec

check: lint test ## Run linters + tests

console: ## Start a console with the gem loaded
	bundle exec rake console

lint_with_docker: ## Run linters in Docker (set RUBY_VERSION to change Ruby version)
	docker run -t -i -w /code -v $(PWD):/code ruby:$(RUBY_VERSION) sh -c "gem install bundler && bundle install && bundle exec rubocop"

lint-fix_with_docker: ## Fix linting issues in Docker (set RUBY_VERSION to change Ruby version)
	docker run -t -i -w /code -v $(PWD):/code ruby:$(RUBY_VERSION) sh -c "gem install bundler && bundle install && bundle exec rubocop -a"

test_with_docker: ## Run tests in Docker (set RUBY_VERSION to change Ruby version)
	docker run -t -i -w /code -v $(PWD):/code --add-host=host.docker.internal:host-gateway -e STREAM_KEY=$(STREAM_KEY) -e STREAM_SECRET=$(STREAM_SECRET) -e "STREAM_CHAT_URL=http://host.docker.internal:3030" ruby:$(RUBY_VERSION) sh -c "gem install bundler && bundle install && bundle exec rspec"

check_with_docker: lint_with_docker test_with_docker ## Run linters + tests in Docker (set RUBY_VERSION to change Ruby version)

sorbet: ## Run Sorbet type checker
	bundle exec srb tc

sorbet_with_docker: ## Run Sorbet type checker in Docker (set RUBY_VERSION to change Ruby version)
	docker run -t -i -w /code -v $(PWD):/code ruby:$(RUBY_VERSION) sh -c "gem install bundler && bundle install && bundle exec srb tc"

coverage: ## Generate test coverage report
	COVERAGE=true bundle exec rspec
	@echo "Coverage report available at ./coverage/index.html"

reviewdog: ## Run reviewdog for CI
	bundle exec rubocop --format json | reviewdog -f=rubocop -name=rubocop -reporter=github-pr-review 