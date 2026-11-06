.DEFAULT_GOAL := help
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

BINARY := lfed-monkeysay
GOBIN  ?= $(shell go env GOPATH)/bin

# VERSION MUST be semver: lfed parses the manifest version.
VERSION ?= 0.0.0-dev+$(shell git rev-parse --short HEAD 2>/dev/null || echo local)
LDFLAGS := -X main.Version=$(VERSION)
GOBUILD := CGO_ENABLED=0 go build -trimpath -ldflags '-s -w $(LDFLAGS)'

# Lint tool pins match the lfed-cli repository.
STATICCHECK := honnef.co/go/tools/cmd/staticcheck@v0.8.2
GOSEC       := github.com/securego/gosec/v2/cmd/gosec@v2.30.0
GOVULNCHECK := golang.org/x/vuln/cmd/govulncheck@v1.9.0

##@ General

.PHONY: help
help:  ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: build
build:  ## Build bin/$(BINARY).
	$(GOBUILD) -o bin/$(BINARY) ./cmd/$(BINARY)

.PHONY: test
test:  ## Run unit tests with the race detector.
	go test -race ./...

.PHONY: lint
lint:  ## Run gofmt, go vet, staticcheck, gosec and govulncheck.
	test -z "$$(gofmt -l cmd internal)" || { gofmt -l cmd internal; exit 1; }
	go vet ./...
	go run $(STATICCHECK) ./...
	go run $(GOSEC) -quiet -exclude-generated -exclude=G104,G204,G304,G702 ./...
	go run $(GOVULNCHECK) ./...

.PHONY: tidy-check
tidy-check:  ## Fail when go.mod or go.sum is not tidy.
	go mod tidy -diff

.PHONY: install-local
install-local:  ## Install $(BINARY) into $$GOBIN.
	$(GOBUILD) -o $(GOBIN)/$(BINARY) ./cmd/$(BINARY)

.PHONY: release-snapshot
release-snapshot:  ## Build the release archives into dist/ without a tag or a publish step.
	goreleaser release --snapshot --clean --skip=publish

.PHONY: clean
clean:  ## Remove build artifacts.
	rm -rf bin dist
