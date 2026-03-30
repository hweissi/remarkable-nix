#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


MAGIC_7Z = b"\x37\x7a\xbc\xaf\x27\x1c"


def carve_payloads(installer: Path, outdir: Path) -> int:
    data = installer.read_bytes()
    idxs: list[int] = []
    start = 0
    while True:
        i = data.find(MAGIC_7Z, start)
        if i == -1:
            break
        idxs.append(i)
        start = i + 1

    if not idxs:
        raise SystemExit("no embedded 7z payloads found")

    outdir.mkdir(parents=True, exist_ok=True)
    for n, i in enumerate(idxs):
        (outdir / f"payload-{n}.7z").write_bytes(data[i:])
    return len(idxs)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: extract_payloads.py <installer.exe> <outdir>", file=sys.stderr)
        return 2
    installer = Path(argv[1])
    outdir = Path(argv[2])
    count = carve_payloads(installer, outdir)
    print(f"wrote {count} payload(s) to {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
