#!/usr/bin/env python3
"""
Usage: myscript.py [options..]
Myscript description

Myscript options:
  -d, --disk       check disk stats
  -c, --cpu        check cpu stats
  -p, --ports      check listen ports
  -r, --ram        check ram stats
  -o, --overview   top 10 process with most CPU usage
"""

import sys
import subprocess
import argparse
import shutil
import re
from typing import Set, List, Dict, Any

# ---- Python version check ----
if sys.version_info < (3, 8):
    print("Python 3.8+ required")
    raise SystemExit(1)


# ---- dependency prompt install (no requirements.txt needed) ----
def ensure_package_interactive(pkg: str) -> None:
    try:
        __import__(pkg)
        return
    except ImportError:
        ans = input(f"Required package '{pkg}' is not installed. Install now? [y/N]: ").strip().lower()
        if ans in {"y", "yes", "evet"}:
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", pkg])
            except subprocess.CalledProcessError:
                print("Installation failed.")
                raise SystemExit(1)
        else:
            print(f"'{pkg}' is required. Exiting.")
            raise SystemExit(1)


ensure_package_interactive("psutil")
import psutil  # noqa: E402


def _bytes_to_gb(n: int) -> float:
    return n / (1024 ** 3)


# ---- Stats implementations ----
def disk_stats() -> None:
    print("\nDisk stats:\n")
    parts = psutil.disk_partitions(all=False)
    if not parts:
        print("(no partitions)")
        return

    for p in parts:
        try:
            usage = psutil.disk_usage(p.mountpoint)
        except (PermissionError, FileNotFoundError, OSError):
            continue

        total = _bytes_to_gb(usage.total)
        used = _bytes_to_gb(usage.used)
        free = _bytes_to_gb(usage.free)

        print(f"Volume: {p.mountpoint} ({p.device})")
        print(f"  Total: {total:.2f} GB")
        print(f"  Used : {used:.2f} GB")
        print(f"  Free : {free:.2f} GB")
        print(f"  Used%: {usage.percent}%\n")


def cpu_stats() -> None:
    print("\nCPU stats:\n")
    cores = psutil.cpu_count(logical=True) or 0
    usage = psutil.cpu_percent(interval=1)
    freq = psutil.cpu_freq()

    print(f"Cores : {cores}")
    print(f"Usage : {usage:.1f}%")
    if freq:
        print(f"Freq  : {freq.current:.2f} MHz")
    else:
        print("Freq  : (not available)")


def ram_stats() -> None:
    print("\nRAM stats:\n")
    mem = psutil.virtual_memory()

    total = _bytes_to_gb(mem.total)
    used = _bytes_to_gb(mem.used)
    free = _bytes_to_gb(mem.available)

    print(f"Total: {total:.2f} GB")
    print(f"Used : {used:.2f} GB")
    print(f"Free : {free:.2f} GB")
    print(f"Used%: {mem.percent}%")


def ports_stats() -> None:
    """
    macOS can deny psutil.net_connections() for non-root users.
    We try psutil first; if denied, fallback to lsof or netstat.
    """
    print("\nListening ports:\n")
    ports: Set[int] = set()

    # 1) Try psutil
    try:
        for conn in psutil.net_connections(kind="inet"):
            if conn.status == psutil.CONN_LISTEN or conn.status == "LISTEN":
                if conn.laddr:
                    ports.add(conn.laddr.port)

    except (psutil.AccessDenied, PermissionError) as e:
        print(f"psutil cannot read all connections due to permissions: {e}")
        print("Falling back to system tools (lsof/netstat)...\n")

        # 2) Fallback: lsof
        if shutil.which("lsof"):
            cmd = ["lsof", "-nP", "-iTCP", "-sTCP:LISTEN"]
            try:
                out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
                for line in out.splitlines():
                    m = re.search(r":(\d+)\s+\(LISTEN\)", line)
                    if m:
                        ports.add(int(m.group(1)))
            except subprocess.CalledProcessError:
                pass

        # 3) Fallback: netstat
        elif shutil.which("netstat"):
            cmd = ["netstat", "-anv", "-p", "tcp"]
            try:
                out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
                for line in out.splitlines():
                    if "LISTEN" in line:
                        m = re.search(r"\.(\d+)\s+.*LISTEN", line)
                        if m:
                            ports.add(int(m.group(1)))
            except subprocess.CalledProcessError:
                pass

        else:
            print("Neither lsof nor netstat is available for fallback.")
            print("Try running with sudo or install lsof.")
            return

    if not ports:
        print("(none)")
        return

    for p in sorted(ports):
        print(f"Port: {p}")


def cpu_overview() -> None:
    """
    Top 10 processes by CPU usage.
    psutil cpu_percent is best used with a sampling interval.
    """
    print("\nTop 10 processes by CPU usage:\n")
    print("Sampling CPU% for ~1s...\n")

    procs: List[psutil.Process] = []
    for p in psutil.process_iter(["pid", "name"]):
        try:
            p.cpu_percent(interval=None)  # prime
            procs.append(p)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # wait a moment for meaningful cpu %
    psutil.cpu_percent(interval=1)

    rows: List[Dict[str, Any]] = []
    for p in procs:
        try:
            rows.append(
                {
                    "pid": p.pid,
                    "name": p.name(),
                    "cpu": p.cpu_percent(interval=None),
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    rows.sort(key=lambda x: x["cpu"], reverse=True)

    if not rows:
        print("(no processes)")
        return

    for r in rows[:10]:
        print(f"PID: {r['pid']:<7} CPU: {r['cpu']:>6.1f}%  Name: {r['name']}")


# ---- CLI ----
def build_parser() -> argparse.ArgumentParser:
    return argparse.ArgumentParser(
        prog="myscript.py",
        description="Myscript description",
        formatter_class=argparse.RawTextHelpFormatter,
    )


def main() -> int:
    parser = build_parser()
    parser.add_argument("-d", "--disk", action="store_true", help="check disk stats")
    parser.add_argument("-c", "--cpu", action="store_true", help="check cpu stats")
    parser.add_argument("-p", "--ports", action="store_true", help="check listen ports")
    parser.add_argument("-r", "--ram", action="store_true", help="check ram stats")
    parser.add_argument("-o", "--overview", action="store_true", help="top 10 process with most CPU usage")

    args = parser.parse_args()

    if not any([args.disk, args.cpu, args.ports, args.ram, args.overview]):
        parser.print_help()
        return 0

    if args.disk:
        disk_stats()
    if args.cpu:
        cpu_stats()
    if args.ram:
        ram_stats()
    if args.ports:
        ports_stats()
    if args.overview:
        cpu_overview()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())