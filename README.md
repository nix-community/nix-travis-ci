# nix-travis-ci
Bootstrap Nix support on Travis CI (a humble near-drop-in replacement for `language: nix`)

# Quickstart

These two lines add Nix support to your `.travis.yml` (they replace `language: nix` if it's already in your config):

```yaml
version: ~> 1.0
import: abathur/nix-travis-ci:nix.yml@main
```

Note: the `import` key is a Travis CI beta feature called [Build Config Imports](https://docs.travis-ci.com/user/build-config-imports/) enabled by specifying `version: ~> 1.0`,  and `@main` indicates the `main` branch.

# Why not just use `language: nix`?

The community has trouble maintaining high-quality support for `language: nix` on Travis CI, so this project is intended to replace it.

# How is this better than what it replaces?

There are a lot of small reasons, but they boil down to: it's easier to work on, so it'll take less time and effort to maintain or even improve.

# Customizing

My _general_ intent is for this repo and https://github.com/cachix/install-nix-action to have the similar if not identical options (even if usage has to differ a little). You can see an example of how to customize each of the following in [this project's own .travis.yml](.travis.yml).

- Nix (by overriding NIX_URL; the list of old versions is at https://releases.nixos.org/?prefix=nix)
- Nixpkgs channel (disable with SKIP_ADDING_NIXPKGS_CHANNEL or override with NIX_PATH)
- nix.conf (append a file specified by EXTRA_NIX_CONFIG)

In addition to these common options, you can also specify a version of this repository by changing `main` in `import: abathur/nix-travis-ci:nix.yml@main` to any ref/tag/branch, such as `import: abathur/nix-travis-ci:nix.yml@v1` 
