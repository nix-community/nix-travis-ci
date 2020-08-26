# Source this script (so it can modify environment variables), i.e.:
# source <(curl -Ls https://github.com/abathur/nix-travis-ci/raw/master/install.sh)
set -eo pipefail

INSTALL_NIX_TYPE="${INSTALL_NIX_TYPE-daemon}"

get_macos_flags(){
  IFS='.' read major minor patch < <(sw_vers -productVersion)
  if [[ $major -gt 10 || ($major -eq 10 && $minor -gt 14) ]]; then
    printf "%s " "--darwin-use-unencrypted-nix-store-volume"
  fi
}

get_flags(){
  printf "%s " "--${INSTALL_NIX_TYPE}" "--nix-extra-conf-file /tmp/nix.conf"
  case "$INSTALL_NIX_TYPE" in
    daemon) # default daemon support for now, but leaving room...
      printf "%s " "--daemon-user-count 4"
      ;;
  esac
  [[ $TRAVIS_OS_NAME = 'osx' ]] && get_macos_flags
}

try_install(){
  if ! echo not a tty :P | sh /tmp/nix-install $(get_flags); then
    # install failed, let's try to clean up
    # it'd be great if Nix wrote a contextual uninstall script to a reliable location?
    sudo mv /etc/bashrc.backup-before-nix /etc/bashrc
    sudo mv /etc/zshrc.backup-before-nix /etc/zshrc
    sudo rm -rf /etc/nix /nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels /Users/travis/.nix-profile /Users/travis/.nix-defexpr /Users/travis/.nix-channels
    return 1
  fi
}

success(){
  echo -e "\e[33mNix support is maintained at https://github.com/nix-community/nix-travis-ci\e[0m"
  nix-env --version
  nix-instantiate --eval -E 'with import <nixpkgs> {}; lib.version or lib.nixpkgsVersion'
}

{
  echo 'build-max-jobs = auto'
  echo "trusted-users = $USER"
} | sudo tee /tmp/nix.conf > /dev/null

if [[ $INSTALL_SKIP_ADDING_NIXPKGS_CHANNEL = "true" || $INSTALL_NIX_PATH != "" ]]; then
  extra_cmd=--no-channel-add
else
  extra_cmd=
  INSTALL_NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"
fi


set -x
wget --retry-connrefused --waitretry=1 -O /tmp/nix-install "${INSTALL_NIX_URL:-https://nixos.org/nix/install}"
try_install || try_install || try_install || try_install || try_install


source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
nix doctor; echo $?

if [[ $TRAVIS_OS_NAME = 'osx' ]]; then
  # macOS needs certificates hints
  cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
  export NIX_SSL_CERT_FILE="$cert_file"
  sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"

  # restart
  sudo launchctl kickstart -k system/org.nixos.nix-daemon
  # sudo launchctl start org.nixos.nix-daemon
  # sudo launchctl list org.nixos.nix-daemon || echo launchctl list status: $?
  # until sudo launchctl list org.nixos.nix-daemon; do
  #   sleep 1
  # done
  # sudo launchctl list org.nixos.nix-daemon || echo launchctl list status: $?
elif [[ $TRAVIS_OS_NAME = 'linux' ]]; then
  # restart
  sudo systemctl restart nix-daemon
fi

# Cachix support (this may feel out-of-scope, but we want to avoid
# breaking cachix--so it needs to get tested--so it needs to be in scope?)
#
# But, see what @domenkozar thinks. I guess this could be trimmed out and
# only used as part of the *test* script. Note, however, that a failure in
# `nix-env -iA nixpkgs.cachix` is being used as a heuristic to detect a case
# where some sort of Nix + macOS 10.14+ bug is causing EOF errors, which can
# in a rare-ish case cause the install to succeed but keep a channel from
# getting properly updated :(
if [ -n "${CACHIX_CACHE}" ]; then
  # this isn't actually cachix specific, but *at least for now* there's some
  # bug that can cause nix to fail to add a channel that we don't hit until we
  # try to use nix. So, if we fail, try to make a channel until the universe ends
  until nix-env -iA nixpkgs.cachix; do
    sudo -i nix-channel --update nixpkgs
  done
  cachix use $CACHIX_CACHE
  nix path-info --all > /tmp/store-path-pre-build
fi

if [[ $INSTALL_NIX_PATH != "" ]]; then
  export NIX_PATH="${NIX_PATH}:${INSTALL_NIX_PATH}"
fi

success
