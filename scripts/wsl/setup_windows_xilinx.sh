#!/bin/sh

if [ "${_DAPHNE_WSL_WINDOWS_XILINX_SH-}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi
_DAPHNE_WSL_WINDOWS_XILINX_SH=1

daphne_to_windows_path() {
  input_path="$1"
  if command -v wslpath >/dev/null 2>&1; then
    if converted_path=$(wslpath -w "$input_path" 2>/dev/null); then
      printf '%s' "$converted_path"
      return 0
    fi
  fi
  case "$input_path" in
    /mnt/[a-zA-Z]/*)
      drive_letter=$(printf '%s' "$input_path" | cut -d/ -f3 | tr '[:lower:]' '[:upper:]')
      rest=$(printf '%s' "$input_path" | cut -d/ -f4- | sed 's#/#\\#g')
      if [ -n "$rest" ]; then
        printf '%s:\\%s' "$drive_letter" "$rest"
      else
        printf '%s:\\' "$drive_letter"
      fi
      ;;
    *)
      printf '%s' "$input_path"
      ;;
  esac
}

daphne_write_windows_wrapper() {
  target="$1"
  tool_path="$2"
  cat >"$target" <<EOF
#!/bin/sh
set -eu

tool_path_wsl='$tool_path'
tool_path_win=\$(wslpath -w "\$tool_path_wsl")
while [ "\$#" -gt 0 ]; do
  arg="\$1"
  shift
  converted_arg="\$arg"
  if [ -e "\$arg" ] || [ -d "\$arg" ]; then
    if resolved_arg=\$(realpath "\$arg" 2>/dev/null); then
      if converted_candidate=\$(wslpath -w "\$resolved_arg" 2>/dev/null); then
        converted_arg="\$converted_candidate"
      fi
    fi
  else
    case "\$arg" in
      /*)
        if converted_candidate=\$(wslpath -w "\$arg" 2>/dev/null); then
          converted_arg="\$converted_candidate"
        fi
        ;;
    esac
  fi
  set -- "\$@" "\$converted_arg"
done

exec cmd.exe /c "\$tool_path_win" "\$@"
EOF
  chmod +x "$target"
}

: "${DAPHNE_WINDOWS_XILINX_ROOT:=/mnt/c/Xilinx}"
: "${DAPHNE_VIVADO_VERSION:=2024.1}"
: "${DAPHNE_VITIS_VERSION:=$DAPHNE_VIVADO_VERSION}"
: "${DAPHNE_WSL_XILINX_WRAPPER_DIR:=$HOME/.cache/daphne-wsl-xilinx/bin}"
: "${DAPHNE_REQUIRE_XSCT:=0}"

DAPHNE_WSL_VIVADO_BAT="$DAPHNE_WINDOWS_XILINX_ROOT/Vivado/$DAPHNE_VIVADO_VERSION/bin/vivado.bat"
DAPHNE_WSL_XSCT_BAT="$DAPHNE_WINDOWS_XILINX_ROOT/Vitis/$DAPHNE_VITIS_VERSION/bin/xsct.bat"

if [ ! -f "$DAPHNE_WSL_VIVADO_BAT" ]; then
  echo "ERROR: Vivado batch launcher not found at $DAPHNE_WSL_VIVADO_BAT" >&2
  return 2 2>/dev/null || exit 2
fi

mkdir -p "$DAPHNE_WSL_XILINX_WRAPPER_DIR"

daphne_write_windows_wrapper "$DAPHNE_WSL_XILINX_WRAPPER_DIR/vivado" "$DAPHNE_WSL_VIVADO_BAT"

if [ -f "$DAPHNE_WSL_XSCT_BAT" ]; then
  daphne_write_windows_wrapper "$DAPHNE_WSL_XILINX_WRAPPER_DIR/xsct" "$DAPHNE_WSL_XSCT_BAT"
elif [ "$DAPHNE_REQUIRE_XSCT" = "1" ]; then
  echo "ERROR: XSCT batch launcher not found at $DAPHNE_WSL_XSCT_BAT" >&2
  return 2 2>/dev/null || exit 2
fi

case ":$PATH:" in
  *":$DAPHNE_WSL_XILINX_WRAPPER_DIR:"*) ;;
  *) PATH="$DAPHNE_WSL_XILINX_WRAPPER_DIR:$PATH" ;;
esac

export PATH
export DAPHNE_WSL_XILINX_WRAPPER_DIR
export DAPHNE_WSL_VIVADO_BAT
export DAPHNE_WSL_XSCT_BAT

if [ -f "$DAPHNE_WSL_XSCT_BAT" ]; then
  export XILINX_VITIS="$(daphne_to_windows_path "$DAPHNE_WINDOWS_XILINX_ROOT/Vitis/$DAPHNE_VITIS_VERSION")"
fi
