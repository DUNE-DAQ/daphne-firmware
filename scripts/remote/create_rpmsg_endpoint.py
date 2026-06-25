#!/usr/bin/env python3
import argparse
import fcntl
import glob
import os
import struct
import time

RPMSG_CREATE_EPT_IOCTL = 0x4028B501
RPMSG_ADDR_ANY = 0xFFFFFFFF


def rpmsg_devices():
    return set(glob.glob("/dev/rpmsg[0-9]*"))


def main():
    parser = argparse.ArgumentParser(description="Create an rpmsg char endpoint from /dev/rpmsg_ctrlX.")
    parser.add_argument("--ctrl", default="/dev/rpmsg_ctrl0")
    parser.add_argument("--name", default="daphne-rpu-wire")
    parser.add_argument("--src", default=RPMSG_ADDR_ANY, type=lambda value: int(value, 0))
    parser.add_argument("--dst", default=1024, type=lambda value: int(value, 0))
    parser.add_argument("--symlink", default="/dev/rpmsg_daphne_afe")
    args = parser.parse_args()

    encoded = args.name.encode("ascii")
    if len(encoded) >= 32:
        raise SystemExit("endpoint name must be shorter than 32 bytes")

    before = rpmsg_devices()
    info = encoded + b"\0" * (32 - len(encoded)) + struct.pack("II", args.src, args.dst)

    with open(args.ctrl, "rb+", buffering=0) as ctrl:
        fcntl.ioctl(ctrl.fileno(), RPMSG_CREATE_EPT_IOCTL, info)

    time.sleep(0.2)
    after = rpmsg_devices()
    created = sorted(after - before)
    if not created:
        created = sorted(after)
    if not created:
        raise SystemExit("rpmsg endpoint ioctl succeeded but no /dev/rpmsgN exists")

    endpoint = created[-1]
    if args.symlink:
        try:
            os.unlink(args.symlink)
        except FileNotFoundError:
            pass
        os.symlink(endpoint, args.symlink)

    print(endpoint)
    if args.symlink:
        print(args.symlink)


if __name__ == "__main__":
    main()
