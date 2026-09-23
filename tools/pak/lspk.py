#!/usr/bin/env python3
"""Minimal LSPK v18 (BG3) reader/writer.

Usage:
  lspk.py list <pak>
  lspk.py extract <pak> <outdir>
  lspk.py create <srcdir> <pak> [--priority N]
"""
import hashlib
import os
import struct
import sys
import zlib

import lz4.block
import lz4.frame
import zstandard

MAGIC = b"LSPK"
ENTRY_SIZE = 272  # name[256] + u32 off1 + u16 off2 + u8 part + u8 flags + u32 disk + u32 size

COMP_NONE, COMP_ZLIB, COMP_LZ4, COMP_ZSTD = 0, 1, 2, 3


def read_pak(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != MAGIC:
        raise ValueError("not an LSPK file")
    version, list_off, list_size, flags, priority = struct.unpack_from("<IQIBB", data, 4)
    md5 = data[22:38]
    num_parts, = struct.unpack_from("<H", data, 38)
    if version != 18:
        raise ValueError(f"unsupported LSPK version {version}")
    num_files, comp_size = struct.unpack_from("<II", data, list_off)
    comp = data[list_off + 8:list_off + 8 + comp_size]
    raw = lz4.block.decompress(comp, uncompressed_size=num_files * ENTRY_SIZE)
    entries = []
    for i in range(num_files):
        base = i * ENTRY_SIZE
        name = raw[base:base + 256].split(b"\0", 1)[0].decode("utf-8")
        off1, off2, part, eflags, disk, size = struct.unpack_from("<IHBBII", raw, base + 256)
        entries.append({
            "name": name, "offset": off1 | (off2 << 32), "part": part,
            "flags": eflags, "disk": disk, "size": size,
        })
    header = {"version": version, "flags": flags, "priority": priority,
              "md5": md5, "parts": num_parts}
    return header, entries, data


def entry_bytes(entry, data):
    blob = data[entry["offset"]:entry["offset"] + entry["disk"]]
    method = entry["flags"] & 0x0F
    if method == COMP_NONE:
        return blob
    if method == COMP_ZLIB:
        return zlib.decompress(blob)
    if method == COMP_LZ4:
        if entry["size"] == 0:
            return b""
        try:
            return lz4.block.decompress(blob, uncompressed_size=entry["size"])
        except Exception:
            return lz4.frame.decompress(blob)
    if method == COMP_ZSTD:
        return zstandard.ZstdDecompressor().decompress(blob, max_output_size=entry["size"])
    raise ValueError(f"unknown compression {entry['flags']:#x} for {entry['name']}")


def cmd_list(path):
    header, entries, _ = read_pak(path)
    print(f"# LSPK v{header['version']} flags={header['flags']:#x} priority={header['priority']} parts={header['parts']}")
    for e in entries:
        print(f"{e['name']}\t{e['size']}\t{e['disk']}\tflags={e['flags']:#x}")


def cmd_extract(path, outdir):
    _, entries, data = read_pak(path)
    for e in entries:
        target = os.path.join(outdir, *e["name"].split("/"))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(entry_bytes(e, data))
    print(f"extracted {len(entries)} files to {outdir}")


def cmd_create(srcdir, pak, priority=0):
    files = []
    for root, _, names in os.walk(srcdir):
        for n in names:
            full = os.path.join(root, n)
            rel = os.path.relpath(full, srcdir).replace(os.sep, "/")
            files.append((rel, full))
    files.sort()
    body = bytearray()
    body += b"\0" * 40  # header placeholder
    entries = []
    for rel, full in files:
        if len(rel.encode("utf-8")) >= 256:
            raise ValueError(f"path too long for LSPK: {rel}")
        with open(full, "rb") as f:
            raw = f.read()
        if raw:
            comp = lz4.block.compress(raw, store_size=False)
            flags = COMP_LZ4 | 0x10  # LZ4 fast, as LSLib writes by default
        else:
            comp = b""
            flags = COMP_NONE
        offset = len(body)
        body += comp
        entries.append((rel, offset, len(comp), len(raw) if flags != COMP_NONE else 0, flags))
    table = bytearray()
    for rel, offset, disk, size, flags in entries:
        name = rel.encode("utf-8").ljust(256, b"\0")
        table += name + struct.pack("<IHBBII", offset & 0xFFFFFFFF, offset >> 32, 0, flags, disk, size)
    comp_table = lz4.block.compress(bytes(table), store_size=False)
    list_off = len(body)
    body += struct.pack("<II", len(entries), len(comp_table)) + comp_table
    list_size = len(body) - list_off
    header = MAGIC + struct.pack("<IQIBB", 18, list_off, list_size, 0, priority) + b"\0" * 16 + struct.pack("<H", 1)
    assert len(header) == 40
    body[0:40] = header
    with open(pak, "wb") as f:
        f.write(body)
    print(f"created {pak} with {len(entries)} files, {len(body)} bytes")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list(sys.argv[2])
    elif cmd == "extract":
        cmd_extract(sys.argv[2], sys.argv[3])
    elif cmd == "create":
        prio = int(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[4] == "--priority" else 0
        cmd_create(sys.argv[2], sys.argv[3], prio)
    else:
        raise SystemExit(__doc__)
