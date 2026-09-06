#!/usr/bin/env python3
"""Stress-test SJOIN interval using #Tentation (chaat) only."""
import re, subprocess, time, ssl, socket, sys
from datetime import datetime

CONF = "/home/zartek/ReplicaServ/ReplicaServ.conf"
LOG = "/home/unrealircd/unrealircd/logs/ircd.log"
SERVICE = "irc_replicaserv.service"
CHAN = "#Tentation"
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
        raise SystemExit("conf patch failed")
    open(CONF, "w").write(text2)


def parse_ts(line):
    m = re.match(r"\[(\w+) (\w+)\s+(\d+) (\d+):(\d+):(\d+) (\d+)\]", line)
    if not m:
        return None
    _, mon, day, hh, mm, ss, year = m.groups()
    return datetime(int(year), MONTHS[mon], int(day), int(hh), int(mm), int(ss)).timestamp()


def drops_since(epoch):
    tail = run(f"sudo tail -n 1500 {LOG}")
    n = 0
    for line in tail.splitlines():
        if "LINK_DISCONNECTED" in line and "ReplicaServ" in line:
            ts = parse_ts(line)
            if ts and ts >= epoch - 1:
                n += 1
    return n


def who_chan():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(socket.create_connection(("127.0.0.1", 6697), timeout=10), server_hostname="localhost")
    nick = f"b{int(time.time()) % 100000}"

    def send(l):
        s.send((l + "\r\n").encode())

    send(f"NICK {nick}")
    send(f"USER {nick} 0 * :b")
    buf = b""
    n = 0
    d = time.time() + 12
    while time.time() < d:
        s.settimeout(2)
        try:
            c = s.recv(65536)
        except Exception:
            continue
        if not c:
            break
        buf += c
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            line = line.decode("utf-8", "replace").rstrip("\r")
            if line.startswith("PING"):
                send("PONG " + line.split(" ", 1)[1])
            if " 001 " in line:
                send(f"JOIN {CHAN}")
                send(f"WHO {CHAN}")
            if re.match(rf"^:\S+ 352 \S+ {re.escape(CHAN)} ", line, re.I):
                n += 1
            if re.search(rf" 315 \S+ {re.escape(CHAN)} ", line, re.I):
                d = 0
    send("QUIT")
    s.close()
    return n


def cpu():
    try:
        return float(run("ps -eo pcpu,cmd | grep '[r]un-replicaserv'").split()[0])
    except Exception:
        return -1.0


def wait_366(timeout=60):
    d = time.time() + timeout
    while time.time() < d:
        j = run(f"journalctl -u {SERVICE} --since '90 sec ago' -q --no-pager")
        if "366 chaat #tentation" in j.lower() or "366 chaat #Tentation" in j:
            return True
        # journal lowercases? check both
        if re.search(r"366 chaat #tentation", j, re.I):
            return True
        time.sleep(1)
    return False


def test_one(ms, watch=75):
    print(f"\n=== {ms}ms watch={watch}s ===", flush=True)
    set_interval(ms)
    run(f"sudo systemctl restart {SERVICE}")
    # wait 001 chaat
    for _ in range(80):
        if run(f"systemctl is-active {SERVICE}").strip() == "active":
            j = run(f"journalctl -u {SERVICE} --since '40 sec ago' -q --no-pager")
            if "001 chaat" in j:
                break
        time.sleep(0.4)
    else:
        print("RESULT=NO_001", flush=True)
        return "NO_001"
    print("waiting 366 Tentation...", flush=True)
    if not wait_366(70):
        print("RESULT=NO_366", flush=True)
        return "NO_366"
    time.sleep(1.5)
    t0 = time.time()
    w0 = who_chan()
    print(f"who0={w0}", flush=True)
    cpus = []
    while time.time() - t0 < watch:
        time.sleep(5)
        if run(f"systemctl is-active {SERVICE}").strip() != "active":
            print("RESULT=SERVICE_DOWN", flush=True)
            return "SERVICE_DOWN"
        if drops_since(t0) > 0:
            print("RESULT=UPLINK_DROP", flush=True)
            return "UPLINK_DROP"
        c = cpu()
        cpus.append(c)
        if len(cpus) % 2 == 0:
            w = who_chan()
            print(f"  t={int(time.time()-t0)}s who={w} cpu={c:.1f}", flush=True)
    w1 = who_chan()
    avg = sum(cpus) / len(cpus) if cpus else -1
    delta = w1 - w0
    print(f"who1={w1} delta={delta} cpu_avg={avg:.1f}", flush=True)
    if delta < 80:
        print("RESULT=LOW_GROWTH", flush=True)
        return "LOW_GROWTH"
    print("RESULT=OK", flush=True)
    return "OK"


def main():
    intervals = [int(x) for x in sys.argv[1:]] or [40, 35, 30, 25, 20]
    watch = 75
    results = []
    best = None
    for ms in intervals:
        r = test_one(ms, watch)
        results.append((ms, r))
        if r == "OK":
            best = ms
        else:
            # stop escalating downward after failure (except LOW_GROWTH retry once?)
            if r in ("UPLINK_DROP", "SERVICE_DOWN"):
                break
            # NO_366 / LOW_GROWTH: still try next slower? we're going down so break
            if r == "LOW_GROWTH" and best is None:
                continue
            if r != "OK":
                break
        time.sleep(8)  # brief settle between restarts
    print("\n===== SUMMARY =====", flush=True)
    for ms, r in results:
        print(f"  {ms}ms -> {r}", flush=True)
    print(f"BEST_STABLE_MS={best}", flush=True)
    return 0 if best else 1


if __name__ == "__main__":
    raise SystemExit(main())
