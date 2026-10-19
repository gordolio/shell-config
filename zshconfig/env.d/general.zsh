# PATH setup
__tool_add_path "usr-local-bin" "/usr/local/bin" path prepend
__tool_add_path "usr-local-sbin" "/usr/local/sbin" path prepend
__tool_add_path "homebrew-bin" "/opt/homebrew/bin" path prepend
__tool_add_path "homebrew-sbin" "/opt/homebrew/sbin" path prepend
__tool_add_path "home-bin" "$HOME/bin" path prepend
__tool_add_path "fleetctl-bin" "$HOME/.fleetctl" path prepend

# Pager
export PAGER="$(whence -p less) -X -F"

# Add pyenv to PATH (shims are added below; full init is interactive-only)
__tool_add_path "pyenv-bin" "$HOME/.pyenv/bin" path prepend

__tool_add_path "cargo-bin" "$HOME/.cargo/bin" path append
__tool_add_path "libpq-bin" "/opt/homebrew/opt/libpq/bin" path append
__tool_add_path "node-22-bin" "/opt/homebrew/opt/node@22/bin" path append
__tool_add_path "mysql-client-8-bin" "/opt/homebrew/opt/mysql-client@8.0/bin" path append
__tool_add_path "mysql-5-7-bin" "/opt/homebrew/opt/mysql@5.7/bin" path append
__tool_add_path "mysql-client-5-7-bin" "/opt/homebrew/opt/mysql-client@5.7/bin" path append
__tool_add_path "chromium-depot-tools" "$HOME/src/chromium/depot_tools" path append
__tool_add_path "binutils-bin" "/opt/homebrew/opt/binutils/bin" path append
__tool_add_path "fzf-bin" "/opt/homebrew/opt/fzf/bin" path append
if ! __tool_add_path "mysql-homebrew" "/opt/homebrew/mysql/bin" path append; then
  if ! __tool_add_path "mysql-client-homebrew" "/opt/homebrew/opt/mysql-client/bin" path append; then
    __tool_add_path "mysql-local" "/usr/local/mysql/bin" path append
  fi
fi
__tool_add_path "git-credential-manager" "$HOME/apps/git-credential-manager" path append
__tool_add_path "maven-bin" "$HOME/apps/maven/bin" path append

# Perlbrew: put its newest installed perl on PATH directly, as the fish config did.
# Sourcing perlbrew's etc/bashrc instead costs ~25ms per shell and, with no
# `perlbrew switch` recorded, leaves the system perl first.
if __tool_check_path "perlbrew" "$HOME/perl5/perlbrew" integration dir; then
  export PERLBREW_ROOT="$HOME/perl5/perlbrew"
  export PERLBREW_HOME="$HOME/.perlbrew"
  __tool_add_path "perlbrew-bin" "$PERLBREW_ROOT/bin" path prepend
  () {
    local -a perls=("$PERLBREW_ROOT"/perls/*/bin(N/n))
    (( ${#perls} )) && __tool_add_path "perlbrew-perl" "${perls[-1]}" path prepend
  }
fi

# Perl local::lib
if __tool_check_path "perl5-home" "$HOME/perl5" integration dir; then
  __tool_add_path "perl5-bin" "$HOME/perl5/bin" path prepend
  export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB"
  export PERL_LOCAL_LIB_ROOT="$HOME/perl5:$PERL_LOCAL_LIB_ROOT"
  export PERL_MB_OPT="--install_base \"$HOME/perl5\""
  export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"
fi

# pyenv shims. This is all `pyenv init --path` does; the `pyenv` shell function,
# completions and pyenv-virtualenv's prompt hook are interactive-only
# (personal.d/general.zsh).
if __tool_check_cmd "pyenv" pyenv lang-managers; then
  export PYENV_SHELL=zsh
  __tool_add_path "pyenv-shims" "${PYENV_ROOT:-$HOME/.pyenv}/shims" path prepend
fi

# Android SDK
if [[ -z "$ANDROID_HOME" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
__tool_add_path "android-emulator" "$ANDROID_HOME/emulator" path append
__tool_add_path "android-platform-tools" "$ANDROID_HOME/platform-tools" path append

if [[ -z "$ANDROID_STUDIO_HOME" ]]; then
  export ANDROID_STUDIO_HOME="$HOME/Applications/Android Studio.app"
fi
__tool_add_path "android-studio-bin" "$ANDROID_STUDIO_HOME/Contents/bin" path prepend

# Google Cloud SDK: gsutil's Python (was a fish universal variable). Only export it
# while that Python is still installed.
if [[ -z "$CLOUDSDK_GSUTIL_PYTHON" && -x /opt/homebrew/opt/python@3.11/bin/python3.11 ]]; then
  export CLOUDSDK_GSUTIL_PYTHON=/opt/homebrew/opt/python@3.11/bin/python3.11
fi
if [[ -n "$CLOUDSDK_GSUTIL_PYTHON" ]]; then
  export CLOUDSDK_GSUTIL_PYTHON
fi

# pipx / local binaries (includes claude)
__tool_add_path "pipx-bin" "$HOME/.local/bin" path append

# bun
export BUN_INSTALL="$HOME/.bun"
__tool_add_path "bun-bin" "$BUN_INSTALL/bin" path prepend

# opencode
__tool_add_path "opencode-bin" "$HOME/.opencode/bin" path prepend
