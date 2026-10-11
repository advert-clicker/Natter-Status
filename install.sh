#!/usr/bin/env bash
# Natter installer.  Run it with:
#   curl -fsSL https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main/install.sh | bash
#
# Installs Natter into ~/Natter. It does not need your password, except on a Linux computer that has no Python yet
# (then it asks once, with a normal-looking prompt that shows bullets as you type).
# Works with the bash that comes with macOS (3.2), so no fancy bash features below.

set -u

REPO_RAW="${NATTER_REPO_RAW:-https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main}"
DEST="${NATTER_DIR:-$HOME/Natter}"
LOG="$(mktemp -t natter-install.XXXXXX 2>/dev/null || echo /tmp/natter-install.log)"
WORK="$(mktemp -d -t natter-work.XXXXXX 2>/dev/null || echo /tmp/natter-work)"
mkdir -p "$WORK"

# ---------------------------------------------------------------------------------------------------- looks

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  GREEN=$'\033[38;5;77m'; RED=$'\033[38;5;203m'; YEL=$'\033[38;5;221m'; BLUE=$'\033[38;5;75m'; PINK=$'\033[38;5;177m'
  FANCY=1
else
  B=""; D=""; R=""; GREEN=""; RED=""; YEL=""; BLUE=""; PINK=""; FANCY=0
fi

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*|*utf-8*) BULLET="•"; TICK="✔"; CROSS="✘"; ARROW="›"; FRAMES="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏";;
  *)                             BULLET="*"; TICK="OK"; CROSS="X"; ARROW=">"; FRAMES="| / - \\";;
esac

HAVE_TTY=0
if [ -r /dev/tty ] && [ -w /dev/tty ] && (: </dev/tty) 2>/dev/null; then HAVE_TTY=1; fi

hide_cursor() { [ "$FANCY" = 1 ] && printf '\033[?25l'; return 0; }
show_cursor() { [ "$FANCY" = 1 ] && printf '\033[?25h'; return 0; }
TTY_SAVED=""
restore_tty() { [ -n "$TTY_SAVED" ] && stty "$TTY_SAVED" </dev/tty 2>/dev/null; TTY_SAVED=""; return 0; }
cleanup() { restore_tty; show_cursor; rm -rf "$WORK" 2>/dev/null; }
trap cleanup EXIT
trap 'restore_tty; show_cursor; printf "\n\n  %sNo problem - nothing was changed. You can run this again any time.%s\n\n" "$YEL" "$R"; exit 130' INT TERM

say()  { printf '  %s\n' "$*"; }
blank(){ printf '\n'; }
good() { printf '  %s%s%s %s\n' "$GREEN" "$TICK" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$YEL" "$R" "$*"; }

banner() {
  blank
  printf '  %s╭──────────────────────────────────────────────╮%s\n' "$PINK" "$R"
  printf '  %s│%s                                              %s│%s\n' "$PINK" "$R" "$PINK" "$R"
  printf '  %s│%s     %sN A T T E R%s                              %s│%s\n' "$PINK" "$R" "$B" "$R" "$PINK" "$R"
  printf '  %s│%s     Private chat for you and your friends    %s│%s\n' "$PINK" "$R" "$PINK" "$R"
  printf '  %s│%s                                              %s│%s\n' "$PINK" "$R" "$PINK" "$R"
  printf '  %s╰──────────────────────────────────────────────╯%s\n' "$PINK" "$R"
  blank
}

step() { # step <n> <total> <title>
  blank
  printf '  %sStep %s of %s%s  %s%s%s\n' "$BLUE" "$1" "$2" "$R" "$B" "$3" "$R"
  printf '  %s──────────────────────────────────────────────%s\n' "$D" "$R"
}

bar() { # bar <percent>   (a little progress bar)
  local pct=$1 w=30 filled i out=""
  filled=$(( pct * w / 100 ))
  i=0; while [ $i -lt $w ]; do if [ $i -lt $filled ]; then out="${out}█"; else out="${out}░"; fi; i=$((i+1)); done
  [ "$FANCY" = 1 ] && printf '%s' "$out" || printf '[%s%%]' "$pct"
}

# Run a command while showing a spinner. Output goes to the log. Returns the command's exit status.
work() { # work "message" cmd args...
  local msg=$1; shift
  if [ "$FANCY" != 1 ]; then
    say "$msg ..."
    "$@" >>"$LOG" 2>&1
    return $?
  fi
  "$@" >>"$LOG" 2>&1 &
  local pid=$! i=0 f
  hide_cursor
  while kill -0 "$pid" 2>/dev/null; do
    set -- $FRAMES
    f=$(( i % $# + 1 )); eval "f=\${$f}"
    printf '\r  %s%s%s %s' "$BLUE" "$f" "$R" "$msg"
    i=$((i+1)); sleep 0.1
  done
  wait "$pid"; local rc=$?
  printf '\r\033[K'
  show_cursor
  if [ $rc -eq 0 ]; then good "$msg"; else printf '  %s%s%s %s\n' "$RED" "$CROSS" "$R" "$msg"; fi
  return $rc
}

pause_enter() {
  if [ "$HAVE_TTY" = 1 ]; then printf '  %s' "$1"; IFS= read -r _ </dev/tty; else :; fi
}

ask_yes() { # ask_yes "question"  -> 0 for yes (default yes); with no keyboard attached, never launches anything
  [ "$HAVE_TTY" = 1 ] || return 1
  local a
  printf '  %s %s[Y/n]%s ' "$1" "$D" "$R"
  IFS= read -r a </dev/tty
  case "$a" in n|N|no|No|NO) return 1;; *) return 0;; esac
}

die() { # die "what happened"
  show_cursor
  blank
  printf '  %s%s Sorry - something went wrong.%s\n' "$RED" "$CROSS" "$R"
  say "$1"
  blank
  say "Nothing on your computer was harmed."
  say "If you ask someone for help, show them this file:"
  say "${B}$LOG${R}"
  blank
  exit 1
}

# ------------------------------------------------------------------------------------- password, with bullets

# Reads a password from the keyboard, showing a bullet for every key (and removing one when you press Backspace).
# Result in $PW. Nothing is stored anywhere or sent anywhere.
ask_password() { # ask_password "prompt"
  PW=""
  local c
  TTY_SAVED=$(stty -g </dev/tty 2>/dev/null)
  stty -echo -icanon </dev/tty 2>/dev/null          # stop the screen echoing BEFORE we ask, so nothing can leak
  printf '  %s%s%s ' "$B" "$1" "$R" > /dev/tty
  while :; do
    c=$(dd bs=1 count=1 </dev/tty 2>/dev/null; echo x); c=${c%x}
    case "$c" in
      ""|$'\n'|$'\r') break;;
      $'\177'|$'\b') if [ -n "$PW" ]; then PW=${PW%?}; printf '\b \b' > /dev/tty; fi;;
      $'\025') while [ -n "$PW" ]; do PW=${PW%?}; printf '\b \b' > /dev/tty; done;; # Ctrl-U clears
      $'\033') dd bs=1 count=2 </dev/tty >/dev/null 2>&1;;                          # ignore arrow keys
      *) PW="$PW$c"; printf '%s' "$BULLET" > /dev/tty;;
    esac
  done
  restore_tty || stty echo icanon </dev/tty 2>/dev/null
  printf '\n' > /dev/tty
}

SUDO_OK=0
# Gets permission to install system software. Returns 0 when we can use sudo.
get_sudo() {
  [ "$(id -u)" = 0 ] && { SUDO_OK=1; return 0; }
  command -v sudo >/dev/null 2>&1 || return 1
  if sudo -n true 2>/dev/null; then SUDO_OK=1; return 0; fi     # no password needed on this computer
  [ "$HAVE_TTY" = 1 ] || return 1
  blank
  say "To add one small helper program, your computer needs your password."
  say "${D}It is the one you use to log in. It stays on this computer and is not sent anywhere.${R}"
  blank
  local tries=0
  while [ $tries -lt 2 ]; do                                    # two tries only: a third wrong one can lock you out
    ask_password "Your password:"
    if [ -n "$PW" ] && printf '%s\n' "$PW" | sudo -S -p '' -v 2>/dev/null; then SUDO_OK=1; return 0; fi
    tries=$((tries+1))
    [ $tries -lt 2 ] && warn "That didn't work. Please try once more."
  done
  PW=""
  return 1
}

run_sudo() { # run a command as the administrator
  if [ "$(id -u)" = 0 ]; then "$@"; return $?; fi
  if [ -n "${PW:-}" ]; then printf '%s\n' "$PW" | sudo -S -p '' "$@"; else sudo -n "$@"; fi
}

# ------------------------------------------------------------------------------------------------- the steps

# --- finding Python (without ever tripping Apple's "install developer tools" window) -------------------------------

PYBIN=""
python_ok() { [ -x "$1" ] && "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; }

# On a Mac without Apple's developer tools, /usr/bin/python3 is only a placeholder: the moment anything RUNS it, a
# window pops up asking to install them. So we never run it unless the tools are really there.
mac_placeholder_is_real() {
  local d
  d=$(xcode-select -p 2>/dev/null) || return 1
  [ -x "$d/usr/bin/python3" ] || [ -x /Library/Developer/CommandLineTools/usr/bin/python3 ]
}

# Sets $PYBIN to a working Python 3.8+ if the computer has one: Natter's own private copy first, then the usual places.
find_python() {
  PYBIN=""
  python_ok "$DEST/runtime/bin/python3" && { PYBIN="$DEST/runtime/bin/python3"; return 0; }
  [ -n "${NATTER_IGNORE_SYSTEM_PYTHON:-}" ] && return 1      # (for testing the "no Python" path)
  local c
  for c in "$(command -v python3 2>/dev/null)" /opt/homebrew/bin/python3 /usr/local/bin/python3 \
           /Library/Frameworks/Python.framework/Versions/Current/bin/python3 /usr/bin/python3; do
    [ -n "$c" ] || continue
    if [ "$(uname -s)" = Darwin ] && [ "$c" = /usr/bin/python3 ] && ! mac_placeholder_is_real; then continue; fi
    python_ok "$c" && { PYBIN="$c"; return 0; }
  done
  return 1
}
have_python() { find_python; }

# Natter's own copy of Python for Macs that have none. Pinned to one exact release and checked against its published
# checksum. Downloaded with curl and unpacked with tar, so macOS does not treat it as "from the internet": no Apple
# warning, no developer certificate needed.
PBS_TAG="20261009"
PBS_VER="3.12.15"
PBS_SHA_ARM64="233f8e15255b3e1d1fd47ea5dd5230dfed803f371138e896e54d98c60ae19f6f"
PBS_SHA_X64="fb3187d95334813b88940db0f1ca57b84cedfd552739c3a5771c3ea0e49988c9"

install_private_python() {   # result: $WORK/runtime
  local arch sha file
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64; sha=$PBS_SHA_ARM64;;
    x86_64)        arch=x86_64;  sha=$PBS_SHA_X64;;
    *) echo "unsupported processor: $(uname -m)"; return 1;;
  esac
  file="cpython-$PBS_VER+$PBS_TAG-$arch-apple-darwin-install_only_stripped.tar.gz"
  curl -fsSL --retry 2 --max-time 300 "https://github.com/astral-sh/python-build-standalone/releases/download/$PBS_TAG/$file" -o "$WORK/pbs.tar.gz" || return 1
  [ "$(shasum -a 256 "$WORK/pbs.tar.gz" | cut -d' ' -f1)" = "$sha" ] || { echo "python download did not match its checksum"; return 1; }
  rm -rf "$WORK/pbs" "$WORK/runtime"; mkdir -p "$WORK/pbs"
  tar xzf "$WORK/pbs.tar.gz" -C "$WORK/pbs" || return 1
  [ -x "$WORK/pbs/python/bin/python3" ] || return 1
  mv "$WORK/pbs/python" "$WORK/runtime"; rm -rf "$WORK/pbs" "$WORK/pbs.tar.gz"
  xattr -dr com.apple.quarantine "$WORK/runtime" 2>/dev/null
  python_ok "$WORK/runtime/bin/python3"
}

install_python_linux() {
  local pm="" cmd=""
  for p in apt-get dnf pacman zypper apk; do command -v "$p" >/dev/null 2>&1 && { pm=$p; break; }; done
  case "$pm" in
    apt-get) cmd="apt-get install -y python3";;
    dnf)     cmd="dnf install -y python3";;
    pacman)  cmd="pacman -S --noconfirm --needed python";;
    zypper)  cmd="zypper --non-interactive install python3";;
    apk)     cmd="apk add python3";;
    *) return 1;;
  esac
  get_sudo || return 2
  [ "$pm" = apt-get ] && run_sudo apt-get update >>"$LOG" 2>&1
  # shellcheck disable=SC2086
  work "Adding the helper program (this can take a minute)" run_sudo $cmd
}

install_python_mac() {
  blank
  say "Your Mac needs a free helper from Apple before Natter can run."
  say "A ${B}window is about to pop up${R}. Click ${B}Install${R}, then ${B}Agree${R}, and wait."
  say "${D}This is normal and safe. It can take a few minutes.${R}"
  blank
  xcode-select --install >>"$LOG" 2>&1 || true
  local waited=0
  hide_cursor
  while ! have_python; do
    printf '\r  %s…%s Waiting for the Apple helper to finish (%ss) ' "$BLUE" "$R" "$waited"
    sleep 3; waited=$((waited+3))
    [ $waited -gt 1800 ] && { printf '\n'; show_cursor; return 1; }
  done
  printf '\r\033[K'; show_cursor
  good "The Apple helper is ready"
}

download_natter_once() {
  curl -fsSL --retry 2 --max-time 30 "$REPO_RAW/version.txt?t=$(date +%s)" -o "$WORK/version.txt" || return 1
  VERSION=$(sed -n 1p "$WORK/version.txt" | tr -d '[:space:]')
  SHA=$(sed -n 2p "$WORK/version.txt" | tr -d '[:space:]')
  ZIPNAME=$(sed -n 3p "$WORK/version.txt" | tr -d '[:space:]'); ZIPNAME=${ZIPNAME:-natter-share.zip}
  case "$VERSION" in ''|*[!0-9]*) return 1;; esac
  case "$SHA" in *[!0-9a-f]*|'') return 1;; esac
  case "$ZIPNAME" in *[!A-Za-z0-9._-]*) return 1;; esac
  curl -fsSL --retry 2 --max-time 120 "$REPO_RAW/$ZIPNAME?t=$(date +%s)" -o "$WORK/natter.zip" || return 1
  local got
  if command -v shasum >/dev/null 2>&1; then got=$(shasum -a 256 "$WORK/natter.zip" | cut -d' ' -f1)
  else got=$(sha256sum "$WORK/natter.zip" | cut -d' ' -f1); fi
  [ "$got" = "$SHA" ] || { echo "checksum mismatch: wanted $SHA got $got"; return 2; }
}

# GitHub can take a few minutes to show a brand-new release everywhere, so a mismatch is retried before giving up.
download_natter() {
  local attempt=1 rc
  while [ $attempt -le 6 ]; do
    download_natter_once; rc=$?
    [ $rc -eq 0 ] && return 0
    [ $rc -ne 2 ] && return $rc
    attempt=$((attempt+1)); sleep 20
  done
  return 1
}

unpack_natter() {
  "$PYBIN" - "$WORK/natter.zip" "$WORK/out" <<'PY' || return 1
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    p = n.split("/")
    if n.startswith("/") or ".." in p or "\\" in n:
        raise SystemExit("unsafe file name in download: " + n)
z.extractall(sys.argv[2])
PY
  [ -f "$WORK/out/natter/src/index.html" ] && [ -f "$WORK/out/natter/start.sh" ] || { echo "download looked incomplete"; return 1; }
  chmod +x "$WORK/out/natter/start.sh" "$WORK/out/natter/update.py"
  rm -rf "$DEST.old"
  [ -e "$DEST" ] && mv "$DEST" "$DEST.old"
  mv "$WORK/out/natter" "$DEST" || { [ -e "$DEST.old" ] && mv "$DEST.old" "$DEST"; return 1; }
  # Natter's private Python lives in the Natter folder: a fresh one if we just made it, else keep the one already there.
  if [ -d "$WORK/runtime" ]; then rm -rf "$DEST/runtime"; mv "$WORK/runtime" "$DEST/runtime"
  elif [ -d "$DEST.old/runtime" ]; then mv "$DEST.old/runtime" "$DEST/runtime"; fi
  rm -rf "$DEST.old"
}

make_shortcuts() {
  OS=$(uname -s)
  if [ "$OS" = Darwin ]; then
    local f="$HOME/Desktop/Natter.command"
    mkdir -p "$HOME/Desktop"
    printf '#!/bin/bash\ncd "%s" && exec ./start.sh\n' "$DEST" > "$f" && chmod +x "$f"
  else
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
    printf '#!/bin/sh\ncd "%s" && exec ./start.sh\n' "$DEST" > "$HOME/.local/bin/natter" && chmod +x "$HOME/.local/bin/natter"
    local entry="[Desktop Entry]
Type=Application
Name=Natter
Comment=Private chat for you and your friends
Exec=sh -c 'cd \"$DEST\" && exec ./start.sh'
Terminal=true
Categories=Network;Chat;"
    printf '%s\n' "$entry" > "$HOME/.local/share/applications/natter.desktop"
    if [ -d "$HOME/Desktop" ]; then
      cp "$HOME/.local/share/applications/natter.desktop" "$HOME/Desktop/Natter.desktop" && chmod +x "$HOME/Desktop/Natter.desktop"
      command -v gio >/dev/null 2>&1 && gio set "$HOME/Desktop/Natter.desktop" metadata::trusted true >/dev/null 2>&1
    fi
  fi
  return 0
}

# --------------------------------------------------------------------------------------------- hidden self-test

if [ "${1:-}" = "--find-python" ]; then      # developer test: report what find_python would use
  find_python && echo "FOUND: $PYBIN" || echo "FOUND: none"
  exit 0
fi

if [ "${1:-}" = "--check-password" ]; then   # used by the developer to test the password box
  get_sudo && echo "RESULT: password accepted" || echo "RESULT: no access"
  exit 0
fi

# ------------------------------------------------------------------------------------------------------- go!

[ "$FANCY" = 1 ] && printf '\033[2J\033[H'
banner
say "This will put ${B}Natter${R} on your computer. It takes about a minute."
blank
say "${GREEN}$TICK${R} You don't need to type anything technical."
say "${GREEN}$TICK${R} It only adds one folder, called ${B}Natter${R}, to your home folder."
say "${GREEN}$TICK${R} You can delete that folder any time to remove it."
blank
pause_enter "Press ${B}Enter${R} to begin... "

OS=$(uname -s)
case "$OS" in Darwin|Linux) ;; *) die "This installer is for Mac and Linux. On Windows, ask for the Windows version.";; esac
command -v curl >/dev/null 2>&1 || die "Your computer is missing a tool called 'curl', which is needed to download Natter."

step 1 4 "Checking your computer"
good "Your computer is a $( [ "$OS" = Darwin ] && echo Mac || echo Linux ) - perfect"
if have_python; then
  good "Everything Natter needs is already here"
else
  warn "Natter needs a small helper program (Python), and it isn't here yet."
  if [ "$OS" = Darwin ]; then
    blank
    say "No problem. I'll add a private copy that only Natter uses."
    say "${D}About 25 MB. No password, and nothing from Apple is needed.${R}"
    blank
    if work "Adding Natter's own helper program" install_private_python; then
      PYBIN="$WORK/runtime/bin/python3"
      good "The helper program is ready"
    else
      warn "That didn't work, so I'll ask Apple's helper to do it instead."
      install_python_mac || die "The helper program didn't finish installing. Please restart this installer after it completes."
      have_python || die "The helper program isn't working yet. Please restart this installer."
    fi
  else
    install_python_linux; rc=$?
    PW=""
    case $rc in
      0) have_python && good "The helper program is ready" || die "The helper program didn't install properly." ;;
      2) die "I couldn't get permission to add the helper program. Please ask someone to run:   sudo apt install python3   (or the same for your system), then run this installer again." ;;
      *) die "I don't know how to add the helper program on this computer. Please install Python 3 and run this installer again." ;;
    esac
  fi
fi

step 2 4 "Downloading Natter"
work "Getting the latest version" download_natter || die "I couldn't download Natter. Please check that you're online, then run this installer again."
VERSION=$(sed -n 1p "$WORK/version.txt" | tr -d '[:space:]')   # (steps run in the background, so read results back here)
good "Version $VERSION downloaded and checked $(bar 100)"

step 3 4 "Installing"
NICE=$(printf '%s' "$DEST" | sed "s|^$HOME|~|")
work "Putting Natter in $NICE" unpack_natter || die "I couldn't put Natter into your home folder."

step 4 4 "Making it easy to open"
work "Adding a shortcut" make_shortcuts || warn "I couldn't add a shortcut, but Natter still works (see below)."
if [ "$OS" = Darwin ]; then SHORTCUT="the ${B}Natter${R} icon on your Desktop"
else SHORTCUT="${B}Natter${R} in your applications menu (or on your Desktop)"; fi

blank
SPACES="                         "
printf '  %s╭──────────────────────────────────────────────╮%s\n' "$GREEN" "$R"
printf '  %s│%s   %s%s  Natter is ready!%s%s%s│%s\n' "$GREEN" "$R" "$GREEN" "$TICK" "$R" "${SPACES:${#TICK}}" "$GREEN" "$R"
printf '  %s╰──────────────────────────────────────────────╯%s\n' "$GREEN" "$R"
blank
say "Any time you want to chat, open $SHORTCUT."
say "${D}The first time, just pick a name - your account is made for you.${R}"
say "${D}Natter updates itself every time it starts.${R}"
blank
if ask_yes "Open Natter now?"; then
  blank
  say "Starting... ${D}(keep this window open while you chat)${R}"
  cd "$DEST" && exec ./start.sh
fi
blank
say "All done. Enjoy! ${PINK}♥${R}"
blank
