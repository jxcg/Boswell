#!/usr/bin/env bash
set -euo pipefail

# Offline contract tests: setup sees only sandboxed HOME, TMPDIR, and PATH.
# All network, package manager, identity and privileged filesystem tools are fakes.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
suite=$(mktemp -d)
trap 'rm -rf "$suite"' EXIT
real_bash=$(command -v bash)
real_mkdir=$(command -v mkdir)
real_ln=$(command -v ln)
real_mktemp=$(command -v mktemp)
mkdir -p "$suite/fixtures" "$suite/repo/.agents" "$suite/repo/BoswellCore"
cp "$repo_root/.agents/setup" "$suite/repo/.agents/setup"

cat > "$suite/fixtures/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'swift %s\n' "$*" >> "$TEST_LOG"
case "$1" in
  --version) printf 'Swift version %s (test fixture)\n' "${TEST_SWIFT_VERSION:-6.2}" ;;
  build|test)
    [ "$2" = --package-path ] && [ "$3" = "$TEST_REPO/BoswellCore" ] || exit 90
    if [ "$1" = build ]; then [ "$4" = --build-tests ] || exit 91; fi
    [ "${TEST_FAIL_COMMAND:-}" != "$1" ] ;;
  *) exit 92 ;;
esac
STUB
cat > "$suite/fixtures/swiftly" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'swiftly %s\n' "$*" >> "$TEST_LOG"
home=${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}
bin=${SWIFTLY_BIN_DIR:-$HOME/.local/share/swiftly/bin}
case "$1" in
  init)
    [ "$*" = 'init --assume-yes --skip-install --quiet-shell-followup' ] || exit 93
    # Real swiftly may ignore HOME in favour of the account's home directory.
    # Setup must explicitly pass consistent locations, including in containers.
    [ "${SWIFTLY_HOME_DIR:-}" = "$home" ] && [ "${SWIFTLY_BIN_DIR:-}" = "$bin" ] && \
      [ "${SWIFTLY_TOOLCHAINS_DIR:-}" = "$home/toolchains" ] || exit 109
    mkdir -p "$home" "$bin"
    cp "$TEST_FIXTURES/swiftly" "$bin/swiftly"
    printf 'export PATH="%s:$PATH"\n' "$bin" > "$home/env.sh" ;;
  install)
    [ "$2" = --assume-yes ] && [ "$3" = --use ] && [ "$4" = --post-install-file ] || exit 94
    # Swiftly --use must never run in the checkout and create .swift-version.
    case "$PWD" in "$TEST_SANDBOX"/tmp/*) ;; *) exit 107 ;; esac
    [ "${TEST_INSTALL_FAIL:-0}" = 0 ] || exit 95
    mkdir -p "$home/toolchain/usr/bin" "$bin"
    cp "$TEST_FIXTURES/swift" "$home/toolchain/usr/bin/swift"
    cp "$TEST_FIXTURES/swift" "$home/toolchain/usr/bin/swiftc"
    if [ "${TEST_POST_INSTALL:-0}" = 1 ]; then
      printf 'printf "dependency-installed\\n" >> "$TEST_LOG"\n' > "$5"
    fi ;;
  link)
    [ "$*" = 'link --assume-yes' ] && [ -x "$home/toolchain/usr/bin/swift" ] || exit 108
    cp "$home/toolchain/usr/bin/swift" "$bin/swift" ;;
  use) [ "$*" = 'use --print-location' ] || exit 96; printf '%s\n' "$home/toolchain" ;;
  *) exit 97 ;;
esac
STUB
cat > "$suite/fixtures/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >> "$TEST_LOG"
[ "${TEST_NETWORK:-ok}" = ok ] || exit 6
# Responses can use HTTP content encoding; request transport decompression.
case " $* " in *' --compressed '*) ;; *) exit 112 ;; esac
url=
output=
while [ "$#" -gt 0 ]; do
  case "$1" in https://*) url=$1 ;; -o) shift; output=$1 ;; esac
  shift
done
case "$url" in
  https://download.swift.org/swiftly/linux/swiftly-1.1.2-x86_64.tar.gz|https://download.swift.org/swiftly/linux/swiftly-1.1.2-x86_64.tar.gz.sig|https://www.swift.org/keys/automatic-signing-key-4.asc) ;;
  *) exit 98 ;;
esac
printf 'download fixture\n' > "$output"
STUB
cat > "$suite/fixtures/gpg" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'gpg %s\n' "$*" >> "$TEST_LOG"
case " $* " in
  *' --show-keys '*) printf 'fpr:::::::::%s:\n' "${TEST_FINGERPRINT:-E813C892820A6FA13755B268F167DF1ACF9CE069}" ;;
  *' --verify '*)
    [ "${TEST_SIGNATURE:-ok}" = ok ] || exit 1
    printf '[GNUPG:] VALIDSIG E813C892820A6FA13755B268F167DF1ACF9CE069 2026-06-04 fixture\n' ;;
  *' --import '*) ;;
  *) exit 99 ;;
esac
STUB
cat > "$suite/fixtures/tar" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'tar %s\n' "$*" >> "$TEST_LOG"
[ "$1" = -xzf ] && [ "$3" = -C ] || exit 100
cp "$TEST_FIXTURES/swiftly" "$4/swiftly"
STUB
cat > "$suite/fixtures/uname" <<'STUB'
#!/usr/bin/env bash
case "$1" in -s) printf '%s\n' "${TEST_OS:-Linux}" ;; -m) echo x86_64 ;; *) exit 101 ;; esac
STUB
cat > "$suite/fixtures/mktemp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
# A template is required: BSD mktemp can otherwise ignore sandbox TMPDIR.
[ "$#" -eq 2 ] && [ "$1" = -d ] || exit 111
case "$2" in "$TEST_SANDBOX"/tmp/*) "$TEST_REAL_MKTEMP" "$@" ;; *) exit 111 ;; esac
STUB
cat > "$suite/fixtures/id" <<'STUB'
#!/usr/bin/env bash
[ "$1" = -u ] || exit 102
printf '%s\n' "${TEST_UID:-1000}"
STUB
cat > "$suite/fixtures/apt-cache" <<'STUB'
#!/usr/bin/env bash
[ "${TEST_APT_SWIFT:-0}" = 1 ]
STUB
cat > "$suite/fixtures/apt-get" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'apt-get %s\n' "$*" >> "$TEST_LOG"
case " $* " in
  *' swiftlang '*) cp "$TEST_FIXTURES/swift" "$TEST_BIN/swift" ;;
  *' gnupg '*) cp "$TEST_FIXTURES/gpg" "$TEST_BIN/gpg" ;;
esac
STUB
cat > "$suite/fixtures/sudo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$TEST_LOG"
[ "$1" = -n ] && [ "${TEST_SUDO_AVAILABLE:-0}" = 1 ] || exit 1
shift
"$@"
STUB
cat > "$suite/fixtures/mkdir" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    /usr/local/bin) printf 'mkdir-root %s\n' "$*" >> "$TEST_LOG"; exit 0 ;;
    /*) case "$arg" in "$TEST_SANDBOX"/*) ;; *) exit 103 ;; esac ;;
  esac
done
"$TEST_REAL_MKDIR" "$@"
STUB
cat > "$suite/fixtures/ln" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'ln %s\n' "$*" >> "$TEST_LOG"
[ "$1" = -sf ] || exit 104
case "$2" in "$TEST_SANDBOX"/*) ;; *) exit 105 ;; esac
case "$3" in /usr/local/bin/swift*) ;; *) exit 106 ;; esac
# Intentionally do not perform privileged writes.
STUB
chmod +x "$suite/fixtures/"*

new_case() {
  case_name=$1
  sandbox=$suite/$case_name
  mkdir -p "$sandbox/home" "$sandbox/bin" "$sandbox/tmp"
  for utility in bash awk cat cp dirname env grep gzip rm; do
    "$real_ln" -s "$(command -v "$utility")" "$sandbox/bin/$utility"
  done
  for utility in swiftly curl gpg tar uname id apt-get apt-cache mkdir ln mktemp; do
    cp "$suite/fixtures/$utility" "$sandbox/bin/$utility"
  done
  # No installed swiftly by default: tar extracts its fixture during installation.
  rm "$sandbox/bin/swiftly"
  : > "$sandbox/log"
  extra=()
}
execute() {
  local expected=$1 actual=0
  shift
  env -i HOME="$sandbox/home" PATH="$sandbox/bin" TMPDIR="$sandbox/tmp" SHELL=/bin/bash \
    TEST_LOG="$sandbox/log" TEST_FIXTURES="$suite/fixtures" TEST_SANDBOX="$sandbox" \
    TEST_BIN="$sandbox/bin" TEST_REPO="$suite/repo" TEST_REAL_MKDIR="$real_mkdir" TEST_REAL_MKTEMP="$real_mktemp" \
    ${extra[@]+"${extra[@]}"} "$real_bash" "$suite/repo/.agents/setup" "$@" > "$sandbox/output" 2>&1 || actual=$?
  if [ "$actual" -ne "$expected" ]; then
    cat "$sandbox/output" >&2
    printf 'FAIL %s: expected status %s, got %s\n' "$case_name" "$expected" "$actual" >&2
    exit 1
  fi
}
has() { grep -Fq -- "$1" "$sandbox/${2:-log}" || { echo "FAIL $case_name: missing $1" >&2; exit 1; }; }
lacks() { if grep -Fq -- "$1" "$sandbox/${2:-log}"; then echo "FAIL $case_name: unexpected $1" >&2; exit 1; fi; }
pass() { printf 'PASS %s\n' "$case_name"; }

new_case available
cp "$suite/fixtures/swift" "$sandbox/bin/swift"
# An unrelated saved environment must not override the suitable PATH compiler,
# including by being persisted into future login shells.
mkdir -p "$sandbox/home/.local/share/swiftly"
printf 'exit 110\n' > "$sandbox/home/.local/share/swiftly/env.sh"
extra=(TEST_SWIFT_VERSION=5.9 BOSWELL_SWIFT_VERSION=99.1)
execute 0 --run-tests
has 'swift build --package-path'; has --build-tests; has 'swift test --package-path'; lacks curl; lacks swiftly
[ ! -e "$sandbox/home/.profile" ]
pass

new_case flags
cp "$suite/fixtures/swift" "$sandbox/bin/swift"
execute 0 --no-build --run-tests
lacks 'swift build'; has 'swift test'
: > "$sandbox/log"
execute 0 --no-build
lacks 'swift build'; lacks 'swift test'
: > "$sandbox/log"
execute 64 --bogus
execute 0 --help
has 'Usage:' output
lacks swift; lacks curl
pass

new_case old_offline
cp "$suite/fixtures/swift" "$sandbox/bin/swift"
extra=(TEST_SWIFT_VERSION=5.8 TEST_NETWORK=offline)
execute 2
has download.swift.org output; has www.swift.org output; lacks 'swift build'
pass

new_case macos_missing
extra=(TEST_OS=Darwin)
execute 2
has 'Xcode 27' output; lacks curl
pass

new_case saved_swiftly
mkdir -p "$sandbox/home/.local/share/swiftly/bin"
cp "$suite/fixtures/swift" "$sandbox/home/.local/share/swiftly/bin/swift"
# Expand PATH when the generated environment is sourced, not when it is written.
# shellcheck disable=SC2016
printf 'export PATH="%s:$PATH"\n' "$sandbox/home/.local/share/swiftly/bin" > "$sandbox/home/.local/share/swiftly/env.sh"
execute 0
has 'swift build'; lacks curl
pass

new_case saved_unlinked_swiftly
mkdir -p "$sandbox/home/.local/share/swiftly/bin" "$sandbox/home/.local/share/swiftly/toolchain/usr/bin"
cp "$suite/fixtures/swiftly" "$sandbox/home/.local/share/swiftly/bin/swiftly"
cp "$suite/fixtures/swift" "$sandbox/home/.local/share/swiftly/toolchain/usr/bin/swift"
# shellcheck disable=SC2016
printf 'export PATH="%s:$PATH"\n' "$sandbox/home/.local/share/swiftly/bin" > "$sandbox/home/.local/share/swiftly/env.sh"
execute 0
has 'swiftly link --assume-yes'; has 'swift build'; lacks curl; lacks 'swiftly install'
pass

new_case install_and_warm
execute 0 --run-tests
has 'swiftly install --assume-yes --use --post-install-file'; has 'swiftly link --assume-yes'; has ' 6.2'; has 'gpg '; has 'swift test'
[ ! -e "$suite/repo/.swift-version" ]
: > "$sandbox/log"
execute 0 --run-tests
lacks curl; lacks 'swiftly install'; has 'swift build'
[ "$(grep -Fc '# Boswell Swift environment' "$sandbox/home/.profile")" -eq 1 ]
# A clean non-interactive login shell reads only the sandbox profile: skip the
# real machine's /etc/profile to keep this offline test's PATH fully isolated.
# shellcheck disable=SC2016
env -i HOME="$sandbox/home" PATH="$sandbox/bin" TEST_LOG="$sandbox/log" TEST_REPO="$suite/repo" \
  "$real_bash" --noprofile --norc -lc '. "$HOME/.profile"; command -v swift' > "$sandbox/new-shell"
has '/.local/share/swiftly/bin/swift' new-shell
pass

new_case override
extra=(BOSWELL_SWIFT_VERSION=6.1.3)
execute 0 --no-build
has ' 6.1.3'; lacks 'swift build'
pass

new_case root_install
extra=(TEST_UID=0 TEST_POST_INSTALL=1)
execute 0
has dependency-installed; has '/usr/local/bin/swift'; has '/usr/local/bin/swiftc'
lacks 'apt-get update'
: > "$sandbox/log"
execute 0
lacks curl; lacks dependency-installed; has '/usr/local/bin/swift'
pass

new_case missing_gpg_root
rm "$sandbox/bin/gpg"
extra=(TEST_UID=0)
execute 0 --no-build
has 'apt-get update'; has 'apt-get install -y gnupg'
pass

new_case missing_gpg_nonroot
rm "$sandbox/bin/gpg"
execute 2
has 'administrator' output; lacks curl
pass

new_case sudo_dependencies_and_prerequisites
cp "$suite/fixtures/sudo" "$sandbox/bin/sudo"
rm "$sandbox/bin/gpg"
extra=(TEST_SUDO_AVAILABLE=1 TEST_POST_INSTALL=1)
execute 0
has 'sudo -n true'; has 'sudo -n apt-get update'
has 'sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg'
has 'sudo -n env DEBIAN_FRONTEND=noninteractive bash'; has dependency-installed; has 'swift build'
pass

new_case sudo_requires_password
cp "$suite/fixtures/sudo" "$sandbox/bin/sudo"
extra=(TEST_POST_INSTALL=1)
execute 2
has 'sudo -n true'; has administrator output; lacks dependency-installed; lacks 'swift build'
pass

new_case apt_fallback
extra=(TEST_UID=0 TEST_NETWORK=offline TEST_APT_SWIFT=1)
execute 0
has 'apt-get install -y swiftlang'; has 'swift build'
pass

new_case nonroot_dependencies
extra=(TEST_POST_INSTALL=1)
execute 2
has 'administrator' output; lacks 'swift build'
: > "$sandbox/log"
execute 2
lacks curl; lacks dependency-installed
extra=(TEST_UID=0)
execute 0
has dependency-installed; has 'swift build'; lacks curl
pass

new_case bad_fingerprint
extra=(TEST_FINGERPRINT=0000000000000000000000000000000000000000)
execute 2
has 'fingerprint mismatch' output; lacks 'swiftly init'
pass

new_case bad_signature
extra=(TEST_SIGNATURE=bad)
execute 2
has 'signature verification failed' output; lacks 'swiftly init'
pass

new_case install_failure
extra=(TEST_INSTALL_FAIL=1)
execute 2
has 'Swift installation failed' output; lacks 'swift build'
pass

for command in build test; do
  new_case "${command}_failure"
  cp "$suite/fixtures/swift" "$sandbox/bin/swift"
  extra=("TEST_FAIL_COMMAND=$command")
  execute 1 --run-tests
  if [ "$command" = build ]; then lacks 'swift test'; fi
  pass
done
printf 'All offline setup tests passed.\n'
