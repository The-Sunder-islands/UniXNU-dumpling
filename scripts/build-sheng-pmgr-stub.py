#!/usr/bin/env python3
"""Build the bring-up sheng PMGR stub archive.

The full NativeUfs root path requires the bsd_init integration symbol to be
present. This stub supplies only that symbol; the real PMGR driver remains the
final integration.  It also carries the link-only B3 globals shared with the
real PMGR archive (BringupLinkStubs.c).
"""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / 'build/sheng-platform-power'
out.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()


def compile_c(source, obj):
    subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios17.0', '-isysroot', sdk,
                    '-Wall', '-Wextra', '-Werror', '-c', str(source), '-o', str(obj)], check=True)


stub_source = ROOT / 'scripts/ShengPlatformPowerStub.c'
stub_obj = out / 'ShengPlatformPowerStub.o'
compile_c(stub_source, stub_obj)
link_source = ROOT / 'scripts/BringupLinkStubs.c'
link_obj = out / 'BringupLinkStubs.o'
compile_c(link_source, link_obj)

archive = out / 'libShengPlatformPower.a'
archive.unlink(missing_ok=True)
subprocess.run(['xcrun', 'ar', 'rcs', str(archive), str(stub_obj), str(link_obj)], check=True)
report = dict(result='SHENG_PMGR_STUB_BUILD_PASS',
              archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
              stub_source_sha256=hashlib.sha256(stub_source.read_bytes()).hexdigest(),
              link_source_sha256=hashlib.sha256(link_source.read_bytes()).hexdigest(),
              final_pmgr_required=True)
(out / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
