# Bash completion for kctl-env
# Source this file from your shell rc:
#   source /path/to/kctl-env/etc/kctl-env-completion.bash

_kctl_env__list_installed_versions() {
  local root
  root="${KCTL_ENV_ROOT:-$HOME/.kctl-env}"

  # Prefer fast local directory listing; no network calls.
  if [[ -d "$root/versions" ]]; then
    # Include all version entries starting with "v" (e.g., pre-releases like v1.30.0-rc.0).
    # Do not emit "latest" here; it is already offered as a keyword.
    command ls -1 "$root/versions" 2>/dev/null | command grep -E '^v' || true
  fi
}

_kctl_env() {
  local cur cmd
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmd="${COMP_WORDS[1]}"

  local commands="install use list list-remote help"

  # Completing subcommand
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi

  # Completing args for install/use
  if [[ "$cmd" == "install" || "$cmd" == "use" ]]; then
    local versions keywords
    keywords="latest stable"
    if [[ "$cmd" == "use" ]]; then
      keywords="$keywords auto"
    fi
    versions="$(_kctl_env__list_installed_versions)"
    COMPREPLY=( $(compgen -W "$keywords $versions" -- "$cur") )
    return 0
  fi

  COMPREPLY=()
  return 0
}

complete -F _kctl_env kctl-env
