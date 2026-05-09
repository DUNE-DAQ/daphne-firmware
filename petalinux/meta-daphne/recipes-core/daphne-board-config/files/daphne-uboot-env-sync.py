#!/usr/bin/env python3

import argparse
import shlex
import shutil
import subprocess
from pathlib import Path


def parse_env_text(text: str):
    entries = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise SystemExit(f"invalid env line without '=': {raw_line}")
        name, value = line.split("=", 1)
        name = name.strip()
        if not name:
            raise SystemExit(f"invalid env line with empty name: {raw_line}")
        entries.append((name, value))
    return entries


def parse_env(path: Path):
    return parse_env_text(path.read_text(encoding="utf-8"))


def load_current_env(fw_env_config: Path):
    fw_printenv = shutil.which("fw_printenv")
    if not fw_printenv:
        raise SystemExit("fw_printenv is not installed or not on PATH")

    result = subprocess.run(
        [fw_printenv, "-c", str(fw_env_config)],
        check=True,
        capture_output=True,
        text=True,
    )
    return dict(parse_env_text(result.stdout))


def select_entries(entries, current_env, changed_only: bool):
    if not changed_only:
        return entries
    return [
        (name, value)
        for name, value in entries
        if current_env.get(name) != value
    ]


def print_commands(entries, fw_env_config: Path):
    config_arg = shlex.quote(str(fw_env_config))
    for name, value in entries:
        print(f"fw_setenv -c {config_arg} {shlex.quote(name)} {shlex.quote(value)}")


def print_diff(entries, current_env):
    for name, value in entries:
        current_value = current_env.get(name, "<unset>")
        print(f"{name}: {current_value} -> {value}")


def apply_entries(entries, fw_env_config: Path):
    fw_setenv = shutil.which("fw_setenv")
    if not fw_setenv:
        raise SystemExit("fw_setenv is not installed or not on PATH")

    for name, value in entries:
        subprocess.run(
            [fw_setenv, "-c", str(fw_env_config), name, value],
            check=True,
        )


def main():
    parser = argparse.ArgumentParser(
        description="Plan or apply the repo-owned DAPHNE U-Boot environment."
    )
    parser.add_argument(
        "--env-file",
        default="/etc/daphne-uboot.env",
        type=Path,
        help="Path to the rendered DAPHNE U-Boot env fragment.",
    )
    parser.add_argument(
        "--fw-env-config",
        default="/etc/fw_env.config",
        type=Path,
        help="Path to fw_env.config for the active board layout.",
    )
    parser.add_argument(
        "--changed-only",
        action="store_true",
        help="Limit output to variables whose current value differs.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when the current environment differs.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply the env fragment through fw_setenv instead of printing commands.",
    )
    args = parser.parse_args()

    desired_entries = parse_env(args.env_file)
    current_env = None
    if args.changed_only or args.check or args.apply:
        current_env = load_current_env(args.fw_env_config)
        desired_entries = select_entries(desired_entries, current_env, True)

    if args.check:
        if desired_entries:
            print_diff(desired_entries, current_env)
            raise SystemExit(1)
        return

    if args.apply:
        apply_entries(desired_entries, args.fw_env_config)
        return

    print_commands(desired_entries, args.fw_env_config)


if __name__ == "__main__":
    main()
