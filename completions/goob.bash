_goob_completion() {
  local cur prev config_dir default_profile profile_name
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  _goob_config_dir() {
    if [[ -n "${GOOB_CONFIG_DIR:-}" && -f "$GOOB_CONFIG_DIR/profile.conf" ]]; then
      printf '%s' "$GOOB_CONFIG_DIR"
      return
    fi
    if [[ -f "$PWD/config/zellij/profile.conf" ]]; then
      printf '%s' "$PWD/config/zellij"
      return
    fi
    default_profile="$HOME/.local/share/zellij-workspaces/default-profile"
    if [[ -f "$default_profile" ]]; then
      profile_name="$(sed -n '1p' "$default_profile")"
      printf '%s/.local/share/zellij-workspaces/profiles/%s' "$HOME" "$profile_name"
    fi
  }

  _goob_workspaces() {
    local tabs_file dir
    dir="$(_goob_config_dir)"
    [[ -d "$dir" ]] || return
    for tabs_file in "$dir"/*.tabs; do
      [[ -f "$tabs_file" ]] || continue
      basename "$tabs_file" .tabs
    done
  }

  _goob_tabs() {
    local workspace="$1" dir tabs_file
    dir="$(_goob_config_dir)"
    tabs_file="$dir/$workspace.tabs"
    [[ -f "$tabs_file" ]] || return
    awk -F '\t' '{ print $1 }' "$tabs_file"
  }

  case "${COMP_WORDS[1]:-}" in
    commit)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "request list check next poke" -- "$cur") )
      fi
      ;;
    tab)
      case "${COMP_WORDS[2]:-}" in
        "")
          COMPREPLY=( $(compgen -W "list add move rename remove refresh" -- "$cur") )
          ;;
        list|refresh)
          [[ "$COMP_CWORD" -eq 3 ]] && COMPREPLY=( $(compgen -W "$(_goob_workspaces)" -- "$cur") )
          ;;
        add|move|remove)
          if [[ "$COMP_CWORD" -eq 3 ]]; then
            COMPREPLY=( $(compgen -W "$(_goob_workspaces)" -- "$cur") )
          elif [[ "$COMP_CWORD" -eq 4 ]]; then
            COMPREPLY=( $(compgen -W "$(_goob_tabs "${COMP_WORDS[3]}")" -- "$cur") )
          fi
          ;;
        rename)
          if [[ "$COMP_CWORD" -eq 3 ]]; then
            COMPREPLY=( $(compgen -W "$(_goob_workspaces)" -- "$cur") )
          elif [[ "$COMP_CWORD" -eq 4 ]]; then
            COMPREPLY=( $(compgen -W "$(_goob_tabs "${COMP_WORDS[3]}")" -- "$cur") )
          fi
          ;;
      esac
      ;;
    refresh|remove|rename)
      [[ "$COMP_CWORD" -eq 2 ]] && COMPREPLY=( $(compgen -W "$(_goob_workspaces)" -- "$cur") )
      ;;
    *)
      if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "help install setup doctor list create refresh rename remove tab commit ps kill $(_goob_workspaces)" -- "$cur") )
      fi
      ;;
  esac
}

complete -F _goob_completion goob
