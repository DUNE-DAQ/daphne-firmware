#!/usr/bin/env python3
"""Select timing-only calibration channels on the grouped32 firmware."""
import argparse
import subprocess
import time

MASK, APPLIED, CAPABILITY = 0xA0010F00, 0xA0010F04, 0xA0010F08


def read(address):
    return int(subprocess.check_output(["devmem", hex(address), "32"], text=True).strip(), 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--channels", type=int, nargs="+", help="complete calibration selection, firmware channel IDs 0..31")
    group.add_argument("--restore", action="store_true", help="return all channels to the board trigger mode")
    args = parser.parse_args()
    if args.channels and any(channel < 0 or channel > 31 for channel in args.channels):
        parser.error("channel IDs must be between 0 and 31")
    if read(CAPABILITY) not in (0x43414C31, 0x43414C32):
        raise SystemExit("Firmware does not support per-channel timing calibration")
    if read(0x88000034) != 2:
        raise SystemExit("Select board xcorr mode (2) before using channel calibration")
    mask = sum(1 << channel for channel in set(args.channels or []))
    subprocess.run(["devmem", hex(MASK), "32", hex(mask)], check=True)
    deadline = time.monotonic() + 2
    while read(APPLIED) != mask:
        if time.monotonic() >= deadline:
            raise SystemExit("Calibration mask did not settle; desired mask remains programmed")
        time.sleep(0.01)
    print(f"Calibration mask applied: 0x{mask:08x}")


if __name__ == "__main__":
    main()
