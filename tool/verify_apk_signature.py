#!/usr/bin/env python3
"""Verifies that an APK's v2 signature block is present and reports its signer.

Why this exists instead of `apksigner verify`: on a runner with a recent JDK,
apksigner emits native-access warnings and, in one case, no output at all, which
made a perfectly signed APK look unsigned. Reading the APK Signing Block directly
needs nothing but the standard library plus openssl for the certificate text, so
the check behaves the same on every machine.

Usage:

    python3 tool/verify_apk_signature.py build/elara-1.0.3-arm64-v8a.apk [more.apk]

Exits non-zero if a signature block is missing or a certificate cannot be read.
"""

import struct
import subprocess
import sys
import tempfile

APK_SIG_BLOCK_MAGIC = b"APK Sig Block 42"
V2_BLOCK_ID = 0x7109871A
V3_BLOCK_ID = 0x1B93AD61


def _length_prefixed(buf, offset):
    (size,) = struct.unpack_from("<I", buf, offset)
    return buf[offset + 4 : offset + 4 + size], offset + 4 + size


def first_certificate(apk_bytes):
    """Returns the DER bytes of the first signing certificate, or raises."""
    eocd = apk_bytes.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise ValueError("no end-of-central-directory record; not a zip")

    (cd_offset,) = struct.unpack_from("<I", apk_bytes, eocd + 16)
    if apk_bytes[cd_offset - 16 : cd_offset] != APK_SIG_BLOCK_MAGIC:
        raise ValueError("no APK signing block; the APK is unsigned")

    (block_size,) = struct.unpack_from("<Q", apk_bytes, cd_offset - 24)
    block_start = cd_offset - block_size - 8

    position = block_start + 8
    block = None
    while position < cd_offset - 24:
        (pair_size,) = struct.unpack_from("<Q", apk_bytes, position)
        (pair_id,) = struct.unpack_from("<I", apk_bytes, position + 8)
        if pair_id == V2_BLOCK_ID:
            block = apk_bytes[position + 12 : position + 8 + pair_size]
        position += 8 + pair_size

    if block is None:
        raise ValueError("signing block found but it has no v2 signature")

    signers, _ = _length_prefixed(block, 0)
    signer, _ = _length_prefixed(signers, 0)
    signed_data, _ = _length_prefixed(signer, 0)
    _digests, offset = _length_prefixed(signed_data, 0)
    certificates, _ = _length_prefixed(signed_data, offset)
    certificate, _ = _length_prefixed(certificates, 0)
    return certificate


def subject_of(der):
    with tempfile.NamedTemporaryFile(suffix=".der") as handle:
        handle.write(der)
        handle.flush()
        result = subprocess.run(
            ["openssl", "x509", "-inform", "DER", "-in", handle.name, "-noout",
             "-subject", "-dates"],
            capture_output=True,
            text=True,
            check=True,
        )
    return " ".join(
        line.strip().removeprefix("subject=") for line in result.stdout.splitlines()
    )


def main(paths):
    if not paths:
        print("usage: verify_apk_signature.py <apk> [apk ...]", file=sys.stderr)
        return 2

    failures = 0
    for path in paths:
        with open(path, "rb") as handle:
            data = handle.read()
        try:
            subject = subject_of(first_certificate(data))
        except (ValueError, subprocess.CalledProcessError) as error:
            print(f"FAIL {path}: {error}")
            failures += 1
            continue

        if "CN=Elara" not in subject:
            print(f"FAIL {path}: signed by the wrong key: {subject}")
            failures += 1
            continue

        print(f"OK   {path}\n     {subject}")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
