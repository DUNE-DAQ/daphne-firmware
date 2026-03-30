#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "ERROR: usage: $0 <tool-path> [args...]" >&2
  exit 2
fi

tool_path_wsl="$1"
shift

if ! command -v wslpath >/dev/null 2>&1; then
  echo "ERROR: wslpath is required to launch Windows Xilinx tools from WSL." >&2
  exit 2
fi

if ! command -v cmd.exe >/dev/null 2>&1; then
  echo "ERROR: cmd.exe is required to launch Windows Xilinx tools from WSL." >&2
  exit 2
fi

if ! tool_path_win=$(wslpath -w "$tool_path_wsl" 2>/dev/null); then
  echo "ERROR: failed to convert tool path to Windows form: $tool_path_wsl" >&2
  exit 2
fi

cmd_quote() {
  printf '%s' "$1" | sed 's/"/""/g'
}

cmd_render_arg() {
  case "$1" in
    *[!A-Za-z0-9_./:\\\\=-]*)
      printf '"%s"' "$(cmd_quote "$1")"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

convert_windows_arg() {
  arg="$1"
  if [ -e "$arg" ] || [ -d "$arg" ]; then
    if resolved_arg=$(realpath "$arg" 2>/dev/null); then
      if converted_candidate=$(wslpath -w "$resolved_arg" 2>/dev/null); then
        printf '%s' "$converted_candidate"
        return 0
      fi
    fi
  fi
  case "$arg" in
    /*)
      if converted_candidate=$(wslpath -w "$arg" 2>/dev/null); then
        printf '%s' "$converted_candidate"
        return 0
      fi
      ;;
  esac
  printf '%s' "$arg"
}

cmd_line=

if [ -n "${XILINX_VITIS-}" ]; then
  vitis_path="$XILINX_VITIS"
  case "$vitis_path" in
    /*)
      if converted_vitis=$(wslpath -w "$vitis_path" 2>/dev/null); then
        vitis_path="$converted_vitis"
      fi
      ;;
  esac
  cmd_line="set \"XILINX_VITIS=$(cmd_quote "$vitis_path")\" & "
fi

cmd_line="${cmd_line}call $(cmd_render_arg "$tool_path_win")"

for arg in "$@"; do
  converted_arg=$(convert_windows_arg "$arg")
  cmd_line="$cmd_line $(cmd_render_arg "$converted_arg")"
done

cmd_line="$cmd_line & set \"daphne_exit=!ERRORLEVEL!\" & exit /b !daphne_exit!"

case "${DAPHNE_WSL_WINDOWS_CMD_CWD-}" in
  "")
    case "$PWD" in
      /mnt/[a-zA-Z]/*) ;;
      *) cd /mnt/c ;;
    esac
    ;;
  *)
    cd "$DAPHNE_WSL_WINDOWS_CMD_CWD"
    ;;
esac

exec cmd.exe /v:on /d /c "$cmd_line"
