# Zsh completion for kctl-env
# Source this file from your shell rc:
#   source /path/to/kctl-env/etc/kctl-env-completion.zsh

_kctl_env__root() {
  if [[ -n "${KCTL_ENV_ROOT:-}" ]]; then
    echo "$KCTL_ENV_ROOT"
  else
    echo "$HOME/.kctl-env"
  fi
}

_kctl_env__installed_versions() {
  local root
  root="$(_kctl_env__root)"

  if [[ -d "$root/versions" ]]; then
    # Ensure aliases and errexit do not interfere with completion behavior
    setopt localoptions no_aliases no_errexit
    # List installed versions without sorting for portability (matches bash completion behavior)
    # GNU sort -V is not available on BSD/macOS, and zsh lacks semantic version sorting
    command ls -1 "$root/versions" 2>/dev/null | command grep -E '^(v[0-9]+\.[0-9]+\.[0-9]+|latest)$' || true
  fi
}

_kctl_env() {
  local -a commands
  commands=(
    'install:Install a kubectl version'
    'use:Set global kubectl version'
    'list-remote:List remote kubectl versions'
    'help:Show help'
  )

  _arguments -C \
    '1:command:->cmds' \
    '*::arg:->args'

  case "$state" in
    cmds)
      _describe -t commands 'kctl-env commands' commands
      ;;
    args)
      case "$words[2]" in
        install)
          _values 'version' latest stable $(_kctl_env__installed_versions)
          ;;
        use)
          _values 'version' latest stable auto $(_kctl_env__installed_versions)
          ;;
      esac
      ;;
  esac
}

compdef _kctl_env kctl-env
