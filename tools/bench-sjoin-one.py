#!/usr/bin/env python3
"""Single-interval SJOIN stress: wait for 366 #linux then measure growth + uplink."""
import re, subprocess, time, ssl, socket, sys
from datetime import datetime

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
        raise SystemExit("conf patch failed")
    open(CONF, "w").write(text2)


def parse_ts(line):
    m = re.match(r"\[(\w+) (\w+)\s+(\d+) (\d+):(\d+):(\d+) (\d+)\]", line)
    if not m:
        return None
    _, mon, day, hh, mm, ss, year = m.groups()
    return datetime(int(year), MONTHS[mon], int(day), int(hh), int(mm), int(ss)).timestamp()


def drops_since(epoch):
    tail = run(f"sudo tail -n 1200 {LOG}")
    n = 0
    for line in tail.splitlines():
        if "LINK_DISCONNECTED" in line and "ReplicaServ" in line:
            ts = parse_ts(line)
            if ts and ts >= epoch - 1:
                n += 1
    return n


def who_linux():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(socket.create_connection(("127.0.0.1", 6697), timeout=10), server_hostname="localhost")
    nick = f"t{int(time.time())%100000}"
    def send(l): s.send((l+"\r\n").encode())
    send(f"NICK {nick}"); send(f"USER {nick} 0 * :t")
    buf=b""; n=0; d=time.time()+12
    while time.time()<d:
        s.settimeout(2)
        try: c=s.recv(65536)
        except Exception: continue
        if not c: break
        buf+=c
        while b"\n" in buf:
            line,buf=buf.split(b"\n",1); line=line.decode("utf-8","replace").rstrip("\r")
            if line.startswith("PING"): send("PONG "+line.split(" ",1)[1])
            if " 001 " in line: send("JOIN #linux"); send("WHO #linux")
            if re.match(r"^:\S+ 352 \S+ #linux ", line): n+=1
            if re.search(r" 315 \S+ #linux ", line): d=0
    send("QUIT"); s.close(); return n


def wait_366(timeout=90):
    d = time.time()+timeout
    while time.time()<d:
        j = run(f"journalctl -u {SERVICE} --since '2 min ago' -q --no-pager")
        if "366 libera #linux" in j:
            return True
        time.sleep(2)
    return False


def cpu():
    try:
        return float(run("ps -eo pcpu,cmd | grep '[r]un-replicaserv'").split()[0])
    except Exception:
        return -1.0


def main():
    ms = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    watch = int(sys.argv[2]) if len(sys.argv) > 2 else 90
    print(f"TEST ms={ms} watch={watch}", flush=True)
    set_interval(ms)
    run(f"sudo systemctl restart {SERVICE}")
    # wait active + 001
    for _ in range(60):
        if run(f"systemctl is-active {SERVICE}").strip()=="active":
            j=run(f"journalctl -u {SERVICE} --since '30 sec ago' -q --no-pager")
            if "001 libera" in j:
                break
        time.sleep(0.5)
    else:
        print("RESULT=NO_001", flush=True); return 2
    print("waiting 366 #linux...", flush=True)
    if not wait_366(120):
        print("RESULT=NO_366", flush=True); return 3
    time.sleep(2)
    t0 = time.time()
    w0 = who_linux()
    print(f"who0={w0}", flush=True)
    cpus=[]
    while time.time()-t0 < watch:
        time.sleep(5)
        if run(f"systemctl is-active {SERVICE}").strip()!="active":
            print("RESULT=SERVICE_DOWN", flush=True); return 4
        if drops_since(t0) > 0:
            print("RESULT=UPLINK_DROP", flush=True); return 5
        cpus.append(cpu())
        if len(cpus) % 3 == 0:
            print(f"  t={int(time.time()-t0)}s who~{who_linux()} cpu={cpus[-1]:.1f}", flush=True)
    w1 = who_linux()
    avg = sum(cpus)/len(cpus) if cpus else -1
    print(f"who1={w1} delta={w1-w0} cpu_avg={avg:.1f}", flush=True)
    if w1 - w0 < 50:
        print("RESULT=LOW_GROWTH", flush=True); return 6
    print("RESULT=OK", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
