#!/usr/bin/env python3
"""Compile a BG3 localization XML (contentList) into the binary .loca format."""
import struct
import sys
import xml.etree.ElementTree as ET


def compile_loca(xml_path, loca_path):
    root = ET.parse(xml_path).getroot()
    entries = []
    for node in root.iter("content"):
        key = node.get("contentuid").encode("utf-8")
        if len(key) >= 64:
            raise ValueError("contentuid too long: %r" % key)
        version = int(node.get("version") or 1)
        text = (node.text or "").encode("utf-8") + b"\0"
        entries.append((key, version, text))
    texts_offset = 12 + 70 * len(entries)
    out = bytearray(b"LOCA" + struct.pack("<II", len(entries), texts_offset))
    for key, version, text in entries:
        out += key.ljust(64, b"\0") + struct.pack("<HI", version, len(text))
    for _, _, text in entries:
        out += text
    with open(loca_path, "wb") as handle:
        handle.write(out)
    return len(entries)


if __name__ == "__main__":
    print("compiled", compile_loca(sys.argv[1], sys.argv[2]), "strings")
