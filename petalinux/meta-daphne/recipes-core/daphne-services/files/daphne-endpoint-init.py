#!/usr/bin/env python3

import mmap
import os
import struct
import sys
import time
from pathlib import Path

PAGE_SIZE = mmap.PAGESIZE
ENDPOINT_BASE = 0x84000000
REG_CLOCK_CONTROL = 0x0
REG_CLOCK_STATUS = 0x4
REG_ENDPOINT_CONTROL = 0x8
REG_ENDPOINT_STATUS = 0xC

BIT_SOFT_RESET = 0
BIT_MMCM_RESET = 1
BIT_CLOCK_SOURCE = 2
BIT_MMCM0_LOCKED = 0
BIT_MMCM1_LOCKED = 1
BIT_ENDPOINT_RESET = 16
BIT_TIMESTAMP_OK = 4
MASK_ENDPOINT_ADDR = 0xFFFF
MASK_FSM_STATUS = 0xF


def load_env(path):
    values = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def parse_states(value):
    if not value:
        return {0x8}
    states = set()
    for item in value.split(","):
        item = item.strip()
        if item:
            states.add(int(item, 0))
    return states or {0x8}


def read_u32(mem, offset):
    return struct.unpack_from("<I", mem, offset)[0]


def write_u32(mem, offset, value):
    struct.pack_into("<I", mem, offset, value & 0xFFFFFFFF)


def set_bit(mem, reg, bit, enabled):
    value = read_u32(mem, reg)
    if enabled:
        value |= 1 << bit
    else:
        value &= ~(1 << bit)
    write_u32(mem, reg, value)


def pulse_bit(mem, reg, bit):
    set_bit(mem, reg, bit, True)
    time.sleep(0.01)
    set_bit(mem, reg, bit, False)


def set_endpoint_address(mem, address):
    value = read_u32(mem, REG_ENDPOINT_CONTROL)
    value &= ~MASK_ENDPOINT_ADDR
    value |= address & MASK_ENDPOINT_ADDR
    write_u32(mem, REG_ENDPOINT_CONTROL, value)


def wait_until(deadline, predicate, message):
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise SystemExit(message)


def main():
    env = {}
    env.update(load_env(Path("/etc/default/firmware")))
    env.update(load_env(Path("/etc/daphne-board.env")))
    env.update(os.environ)

    profile = env.get("TIMING_PROFILE", "")
    if not profile:
        print("TIMING_PROFILE not set; skipping endpoint init.")
        return 0
    if profile != "endpoint-sync-v14":
        raise SystemExit(f"Unknown TIMING_PROFILE={profile}")

    endpoint_addr = int(env.get("ENDPOINT_ADDR_HEX", "0x20"), 0)
    endpoint_wait_ms = int(env.get("ENDPOINT_WAIT_MS", "1000"), 0)
    success_states = parse_states(env.get("ENDPOINT_SUCCESS_STATES", "0x8"))
    clock_source = int(env.get("ENDPOINT_CLOCK_SOURCE", "1"), 0)
    timeout = max(endpoint_wait_ms, 1000) / 1000.0

    fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
    try:
        mem = mmap.mmap(fd, PAGE_SIZE, offset=ENDPOINT_BASE)
        try:
            set_bit(mem, REG_CLOCK_CONTROL, BIT_CLOCK_SOURCE, bool(clock_source))
            pulse_bit(mem, REG_CLOCK_CONTROL, BIT_MMCM_RESET)

            mmcm_deadline = time.monotonic() + timeout
            wait_until(
                mmcm_deadline,
                lambda: (
                    ((read_u32(mem, REG_CLOCK_STATUS) >> BIT_MMCM0_LOCKED) & 0x1) == 1
                    and ((read_u32(mem, REG_CLOCK_STATUS) >> BIT_MMCM1_LOCKED) & 0x1) == 1
                ),
                "Endpoint MMCMs did not lock in time.",
            )

            set_endpoint_address(mem, endpoint_addr)
            pulse_bit(mem, REG_ENDPOINT_CONTROL, BIT_ENDPOINT_RESET)

            endpoint_deadline = time.monotonic() + timeout
            def endpoint_ready():
                status = read_u32(mem, REG_ENDPOINT_STATUS)
                timestamp_ok = (status >> BIT_TIMESTAMP_OK) & 0x1
                fsm_status = status & MASK_FSM_STATUS
                if fsm_status not in success_states:
                    return False
                if fsm_status == 0x8:
                    return timestamp_ok == 1
                return True

            wait_until(
                endpoint_deadline,
                endpoint_ready,
                "Endpoint status did not reach an expected ready state.",
            )

            status = read_u32(mem, REG_ENDPOINT_STATUS)
            print(
                "Endpoint ready:"
                f" address=0x{endpoint_addr:04x}"
                f" timestamp_ok={(status >> BIT_TIMESTAMP_OK) & 0x1}"
                f" fsm_status=0x{status & MASK_FSM_STATUS:x}"
            )
        finally:
            mem.close()
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
