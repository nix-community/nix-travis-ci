# Source this script (so it can modify environment variables), i.e.:
# source <(curl -Ls https://github.com/abathur/nix-travis-ci/raw/master/install.sh)
set -eo pipefail

travis_fold end install
travis_fold start nix.install
printf "\e[34;1mInstalling Nix so you can be a cool kid :]\e[0m\n" # labels the log fold line


# Not sure how I feel about this, but for now I'll use INPUT_ just because
# install-nix-action does (the INPUT_ prefix comes from how GH actions treats
# "with <blah>" options), and I harbor some suspicion we could deduplicate part
# if not all of our CI scripting...
#
# But, let's avoid leaking this detail to Travis CI users by using names
# without this prefix.
INPUT_NIX_TYPE="${NIX_TYPE-daemon}"
INPUT_EXTRA_NIX_CONFIG="${EXTRA_NIX_CONFIG}"
INPUT_NIX_URL="${NIX_URL:-https://nixos.org/nix/install}"
INPUT_NIX_PATH="${NIX_PATH}"
INPUT_SKIP_ADDING_NIXPKGS_CHANNEL="${SKIP_ADDING_NIXPKGS_CHANNEL}"

get_macos_flags(){
  local major minor patch
  IFS='.' read major minor patch < <(sw_vers -productVersion)
  # macos versions:
  # - 11.0+
  # - 10.15+
  if [[ $major -gt 10 || ($major -eq 10 && $minor -gt 14) ]]; then
    printf "%s " "--darwin-use-unencrypted-nix-store-volume"
  fi
}

get_flags(){
  printf "%s " "--${INPUT_NIX_TYPE}" "--nix-extra-conf-file /tmp/nix.conf"
  case "$INPUT_NIX_TYPE" in
    # default daemon support to match install-nix-action for now
    # but leaving room in case single-user support is needed...
    daemon)
      printf "%s " "--daemon-user-count 4"
      ;;
  esac
  [[ $TRAVIS_OS_NAME = 'osx' ]] && get_macos_flags
  if [[ $INPUT_SKIP_ADDING_NIXPKGS_CHANNEL = "true" || $INPUT_NIX_PATH != "" ]]; then
    printf "%s " "--no-channel-add"
  else
    INPUT_NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"
  fi
}

try_install(){
  if ! echo not a tty :o | sh /tmp/nix-install $(get_flags); then
    # install failed, let's clean up so we can re-try
    # it'd be great if Nix wrote a contextual uninstall script to a reliable location?
    sudo mv /etc/bashrc.backup-before-nix /etc/bashrc
    sudo mv /etc/zshrc.backup-before-nix /etc/zshrc
    sudo rm -rf /etc/nix /nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels /Users/travis/.nix-profile /Users/travis/.nix-defexpr /Users/travis/.nix-channels
    return 1
  fi
}

{
  echo 'build-max-jobs = auto'
  echo "trusted-users = $USER"
  # Append extra nix configuration if provided
  # CAUTION: I'm treating this as a file, but install-nix-action is using a multline
  #          env. Doing this because Travis CI breaks up multiline envs...
  if [[ -s "$INPUT_EXTRA_NIX_CONFIG" ]]; then
    cat "$INPUT_EXTRA_NIX_CONFIG"
  fi
} | sudo tee /tmp/nix.conf > /dev/null

# set -x
wget --retry-connrefused --waitretry=1 -O /tmp/nix-install "${INPUT_NIX_URL}"

# There is, in particular, an issue with the installer sometimes failing on mojave+
# 5x is a bit superstitious; I haven't been bored enough to confirm where the chance
# actually rolls off...
try_install || try_install || try_install || try_install || try_install

# TODO: install-nix-action doesn't do this; I think that is why it echos add-path
# at the end. In our case, we're intentionally sourcing the script so that we can modify the environment. As far as I can tell, the ::add-path:: idiom in GH actions is a hack
# around not being able to change the environment? But this difference has some
# impact on whether the code can be shared at some point.
source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

if [[ $TRAVIS_OS_NAME = 'osx' ]]; then
  # TODO: note that below is probably only helpful pre-catalina;
  #       the installer adds `nobrowse` to the fstab for the Nix volume
  #       which should have the same effect. Might be an interesting test
  #       once Travis CI no longer defaults macOS to 10.13
  # Disable spotlight indexing of /nix to speed up performance
  sudo mdutil -i off /nix
fi

if [ -n "${CACHIX_CACHE}" ]; then
  # this isn't actually cachix specific, but *at least for now* there's some
  # bug that can cause nix to fail to add a channel that we don't hit until we
  # try to use nix. (AFAIK it's the same bug requiring repeated install attempts)
  # So, if we fail, try to make a channel until the universe ends
  until nix-env -iA nixpkgs.cachix; do
    sudo -i nix-channel --update nixpkgs
  done
  cachix use $CACHIX_CACHE
  nix path-info --all > /tmp/store-path-pre-build
fi

if [[ $INPUT_NIX_PATH != "" ]]; then
  export NIX_PATH="${NIX_PATH}:${INPUT_NIX_PATH}"
fi

extract_nix_version(){
  echo $3
}
get_nix_version(){
  extract_nix_version $(nix --version)
}
get_nixpkgs_version_info(){
  if [[ $INPUT_SKIP_ADDING_NIXPKGS_CHANNEL != "true" ]]; then
    if ! nix-instantiate --eval -E 'with import <nixpkgs> {}; lib.version or lib.nixpkgsVersion'; then
      echo "not in NIX_PATH"
    fi
  fi
}
get_nix_version_info(){
  printf "%s" "$(get_nix_version) (nixpkgs: $(get_nixpkgs_version_info))"
}

travis_fold end nix.install
travis_fold start nix.info
printf "\e[34;1mNix $(get_nix_version_info) via github.com/nix-community/nix-travis-ci\e[0m\n"
travis_fold end nix.info
