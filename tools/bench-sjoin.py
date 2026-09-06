#!/usr/bin/env python3
"""Bench ReplicaServ SJOIN interval: lowest ms without uplink drop."""
import re
import subprocess
import time
import ssl
import socket
from datetime import datetime

INTERVALS = [50, 40, 30, 25, 20]
WATCH_SEC = 55
CONF = "/home/zartek/ReplicaServ/ReplicaServ.conf"
LOG = "/home/unrealircd/unrealircd/logs/ircd.log"
SERVICE = "irc_replicaserv.service"
MONTHS = {m: i for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(), 1)}


def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)


def set_interval(ms):
    text = open(CONF).read()
    text2, n = re.subn(
        r"set config\(replica_sjoin_interval_ms\)\s+\d+",
        f"set config(replica_sjoin_interval_ms)\t{ms}",
        text,
        count=1,
    )
    if n != 1:
        raise SystemExit(f"conf patch failed n={n}")
    open(CONF, "w").write(text2)
    print(f"conf -> {ms}ms", flush=True)


def parse_unreal_ts(line):
    m = re.match(r"\[(\w+) (\w+)\s+(\d+) (\d+):(\d+):(\d+) (\d+)\]", line)
    if not m:
        return None
    _, mon, day, hh, mm, ss, year = m.groups()
    try:
        return datetime(int(year), MONTHS[mon], int(day), int(hh), int(mm), int(ss)).timestamp()
    except Exception:
        return None


def new_replica_disconnects_since(epoch):
    try:
        tail = run(f"sudo tail -n 1000 {LOG}")
    except Exception as e:
        print("log read err", e, flush=True)
        return -1
    n = 0
    for line in tail.splitlines():
        if "LINK_DISCONNECTED" not in line or "ReplicaServ" not in line:
            continue
        ts = parse_unreal_ts(line)
        if ts is not None and ts >= epoch - 1:
            n += 1
    return n


def wait_linked(timeout=40):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if run(f"systemctl is-active {SERVICE}").strip() != "active":
                time.sleep(0.5)
                continue
            j = run(f"journalctl -u {SERVICE} --since '45 sec ago' -q --no-pager")
            if "001 libera" in j:
                time.sleep(1.0)
                return True
        except Exception:
            pass
        time.sleep(0.5)
    return False


def restart():
    print("restart...", flush=True)
    run(f"sudo systemctl restart {SERVICE}")
    ok = wait_linked()
    print(f"linked={ok}", flush=True)
    return ok


def who_linux():
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection(("127.0.0.1", 6697), timeout=10)
        s = ctx.wrap_socket(raw, server_hostname="localhost")
        nick = f"bn{int(time.time()) % 100000}"

        def send(l):
            s.send((l + "\r\n").encode())

        send(f"NICK {nick}")
        send(f"USER {nick} 0 * :b")
        buf = b""
        n = 0
        deadline = time.time() + 10
        while time.time() < deadline:
            s.settimeout(2)
            try:
                chunk = s.recv(65536)
            except Exception:
                continue
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.decode("utf-8", "replace").rstrip("\r")
                if line.startswith("PING"):
                    send("PONG " + line.split(" ", 1)[1])
                if " 001 " in line:
                    send("JOIN #linux")
                    send("WHO #linux")
                if re.match(r"^:\S+ 352 \S+ #linux ", line):
                    n += 1
                if re.search(r" 315 \S+ #linux ", line):
                    deadline = 0
        send("QUIT :x")
        s.close()
        return n
    except Exception as e:
        print("who err", e, flush=True)
        return -1


def cpu_replica():
    try:
        out = run("ps -eo pcpu,cmd | grep '[r]un-replicaserv'")
        return float(out.split()[0])
    except Exception:
        return -1.0


def linked_ok():
    try:
        if run(f"systemctl is-active {SERVICE}").strip() != "active":
            return False
        run("pgrep -f run-replicaserv.tcl >/dev/null")
        return True
    except Exception:
        return False


def main():
    results = []
    print(f"Bench intervals={INTERVALS} watch={WATCH_SEC}s", flush=True)
    for ms in INTERVALS:
        print(f"\n=== TEST {ms}ms ===", flush=True)
        set_interval(ms)
        if not restart():
            results.append((ms, "restart_fail", -1, -1, -1.0))
            break
        time.sleep(2)
        watch_start = time.time()
        who0 = who_linux()
        print(f"who0={who0}", flush=True)
        cpu_samples = []
        dropped = False
        reason = ""
        while time.time() - watch_start < WATCH_SEC:
            time.sleep(5)
            if not linked_ok():
                dropped = True
                reason = "service_down"
                break
            nd = new_replica_disconnects_since(watch_start)
            if nd > 0:
                dropped = True
                reason = f"uplink_drop x{nd}"
                break
            cpu_samples.append(cpu_replica())
        who1 = who_linux()
        cpu_avg = sum(cpu_samples) / len(cpu_samples) if cpu_samples else -1.0
        status = "DROP" if dropped else "OK"
        delta = (who1 - who0) if who0 >= 0 and who1 >= 0 else -1
        print(f"{status} {reason} who {who0}->{who1} (+{delta}) cpu~{cpu_avg:.1f}%", flush=True)
        results.append((ms, status, who0, who1, cpu_avg))
        if dropped:
            break

    print("\n===== SUMMARY =====", flush=True)
    best = None
    for ms, status, w0, w1, cpu in results:
        d = (w1 - w0) if w0 >= 0 and w1 >= 0 else "n/a"
        print(f"  {ms:3d}ms  {status:12s}  who_delta={d}  cpu~{cpu:.1f}%", flush=True)
        if status == "OK":
            best = ms
    print(f"BEST_STABLE_MS={best}", flush=True)
    return best


if __name__ == "__main__":
    main()
