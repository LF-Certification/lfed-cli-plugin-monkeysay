# lfed-cli-plugin-monkeysay

`lfed monkeysay` prints a message in a speech balloon over an ASCII monkey.
It is the reference plugin for the [`lfed`](https://github.com/LF-Certification/lfed-cli) CLI.
Copy this repository to start a new plugin.

## Install

```sh
lfed plugin install monkeysay
```

## Usage

```sh
lfed monkeysay hello world
echo hello | lfed monkeysay
lfed monkeysay --width 20 "a longer message that wraps"
lfed monkeysay -o json --jq .text hello
```

## Develop

```sh
make build
lfed plugin install ./bin/lfed-monkeysay
make lint test tidy-check
```

## Release

1. Run `scripts/create-release.sh`. Merge the changelog commit into `main`.
2. Run `scripts/create-release.sh tag` on the merged commit.
3. Push the tag. `.github/workflows/release.yml` publishes and signs the plugin.

The catalog entry `lfed-cli/catalog/plugins/monkeysay.yaml` pins the workflow path and the `vX.Y.Z` tag format.
You MUST NOT rename the workflow file or change the tag format.

## License

Apache-2.0. See [LICENSE](LICENSE).
