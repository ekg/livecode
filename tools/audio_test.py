#!/usr/bin/env python3
"""audio_test.py — an independent test suite for the audio pipeline.

Why this exists: a whole evening of debugging sound *by ear* through a chat
window, repeatedly concluding the wrong thing, because there was no way to ask
"what actually came out?" A spectrogram and a measured fundamental are answers.

How it works:
  * The suite OWNS SuperCollider: it starts `pw-jack sclang`, keeping a FIFO open
    on its stdin, so it can record and play test synths without the pi-tidal
    plugin and without restarting anything.
  * Stimuli are real `/dirt/play` OSC events — the same path Tidal drives — so
    measurements describe the production path, not a shortcut.
  * Every take is analysed (peak, RMS, spectral centroid, fundamentals) and
    rendered as a spectrogram PNG that the agent can look at.

Usage:
  tools/audio_test.py                  # all tests
  tools/audio_test.py --list
  tools/audio_test.py --test notes --test orbit
  tools/audio_test.py --keep-sc        # leave sclang up afterwards
Exit status is non-zero if any test fails.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import socket
import struct
import subprocess
import sys
import time
import wave

import numpy as np

REPO = pathlib.Path(__file__).resolve().parent.parent
REPORTS = REPO / "tests/reports"
FIFO = pathlib.Path("/tmp/audio-test-sclang.fifo")
SUPERDIRT = ("127.0.0.1", 57120)
BOOT_LOG = REPO / "sc/boot.log"   # init.scd logs every stage here; "done" = layer ready


# ------------------------------------------------------------------ OSC
def _pad(b: bytes) -> bytes:
    return b + b"\x00" * ((4 - len(b) % 4) % 4)


def osc(addr: str, args: list) -> bytes:
    types, body = "", b""
    for _, v in args:
        if isinstance(v, int):
            types += "i"; body += struct.pack(">i", v)
        elif isinstance(v, float):
            types += "f"; body += struct.pack(">f", v)
        else:
            types += "s"; body += _pad(str(v).encode())
    return _pad(addr.encode()) + _pad(("," + types).encode()) + body


def play(sound: str, **kw) -> None:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(osc("/dirt/play", [("s", sound)] + list(kw.items())), SUPERDIRT)
    s.close()


# ------------------------------------------------------------------ SC control
class SC:
    def running(self) -> bool:
        return subprocess.run(["pgrep", "-x", "sclang"], capture_output=True).returncode == 0

    def start(self, log: pathlib.Path | None = None) -> None:
        # Always start from a FRESH stack: an sclang left over from an earlier run
        # was booted with whatever sc/init.scd said then, and testing against a
        # half-loaded layer produces silent takes and wrong conclusions.
        if self.running():
            for n in ("sclang", "scsynth"):
                subprocess.run(["pkill", "-u", os.environ.get("USER", "erik"), "-x", n],
                               capture_output=True)
            time.sleep(3)
        if True:
            if FIFO.exists():
                FIFO.unlink()
            os.mkfifo(FIFO)
            # the shell opens the read end (blocking until a writer appears, which
            # happens in the child, not here), then we hold the write end open
            out = open(log, "w") if log else subprocess.DEVNULL
            subprocess.Popen(f"pw-jack sclang < {FIFO}",
                             shell=True, stdout=out, stderr=subprocess.STDOUT)
            self.fifo = open(FIFO, "w")
        else:
            self.fifo = open(FIFO, "w")
        before = BOOT_LOG.stat().st_mtime if BOOT_LOG.exists() else 0
        for _ in range(70):
            fresh = BOOT_LOG.exists() and BOOT_LOG.stat().st_mtime > before
            done = False
            if fresh:
                try:
                    done = "done" in "\n".join(BOOT_LOG.read_text().splitlines()[-4:])
                except Exception:
                    done = False
            up = "57120" in subprocess.run(["ss", "-lnup"], capture_output=True, text=True).stdout
            if fresh and up and done:
                time.sleep(2)
                return
            time.sleep(3)
        raise RuntimeError("boot timed out: sc/boot.log never reached a fresh 'done' "
                           "(check sc/boot.log for a failing stage)")

    def __init__(self, keep: bool = False, cmdlog: pathlib.Path | None = None):
        self.keep = keep
        self.fifo = None
        self.cmdlog = cmdlog

    def send(self, code: str) -> None:
        self.fifo.write(code + "\n")
        self.fifo.flush()
        if self.cmdlog:
            with open(self.cmdlog, "a") as f:
                f.write(f"[{time.strftime('%H:%M:%S')}] {code}\n")
        time.sleep(0.25)

    def stop(self) -> None:
        if self.keep:
            return
        if self.fifo:
            try:
                self.fifo.close()
            except Exception:
                pass
        for name in ("sclang", "scsynth"):
            subprocess.run(["pkill", "-u", os.environ.get("USER", "erik"), "-x", name],
                           capture_output=True)


# ------------------------------------------------------------------ analysis
def load_wav(path: pathlib.Path) -> tuple[np.ndarray, int]:
    """Read any WAV SuperCollider writes — including float32 (format 3), which
    python's `wave` module refuses ("unknown format: 3")."""
    try:
        from scipy.io import wavfile
        sr, data = wavfile.read(str(path))
        x = data.astype(np.float64)
        if data.dtype.kind == "i":
            x /= float(np.iinfo(data.dtype).max)
        if x.ndim > 1:
            x = x.mean(axis=1)
        return x, sr
    except Exception:
        pass
    with wave.open(str(path)) as w:
        sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if sw != 2:
        raise RuntimeError(f"unsupported sample width {sw}")
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def fundamentals(x: np.ndarray, sr: int, lo=40, hi=5000, top=5) -> list[float]:
    """Peaks in the low spectrum, where a musical fundamental lives."""
    if len(x) < 1024:
        return []
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    m = (freqs >= lo) & (freqs <= hi)
    spec, freqs = spec[m], freqs[m]
    cand = [(float(spec[i]), float(freqs[i])) for i in range(1, len(spec) - 1)
            if spec[i] > spec[i - 1] and spec[i] >= spec[i + 1]]
    cand.sort(reverse=True)
    out: list[float] = []
    for _, f in cand:
        # drop anything that is a near-multiple of an already accepted pitch
        if any(abs(f - o * k) < 12 for o in out for k in (2, 3, 4, 5)):
            continue
        if all(abs(f - o) > 15 for o in out):
            out.append(round(f, 1))
        if len(out) >= top:
            break
    return sorted(out)


def features(x: np.ndarray, sr: int) -> dict:
    if len(x) == 0:
        return {"peak": 0.0, "rms": 0.0, "centroid_hz": 0.0}
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) if len(x) >= 1024 else np.array([0.0])
    freqs = np.fft.rfftfreq(len(x), 1 / sr) if len(x) >= 1024 else np.array([0.0])
    return {"peak": round(float(np.max(np.abs(x))), 4),
            "rms": round(float(np.sqrt(np.mean(x ** 2))), 5),
            "centroid_hz": round(float((spec * freqs).sum() / max(spec.sum(), 1e-9)), 1)}


def spectrogram(path: pathlib.Path, png: pathlib.Path, fmax=6000) -> bool:
    try:
        x, sr = load_wav(path)
    except Exception:
        return False
    if len(x) < 2048:
        return False
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(11, 4), dpi=110)
    ax.specgram(x, NFFT=2048, Fs=sr, noverlap=1024, cmap="magma")
    ax.set_ylim(0, fmax); ax.set_xlabel("seconds"); ax.set_ylabel("Hz")
    ax.set_title(path.name)
    fig.tight_layout(); fig.savefig(png); plt.close(fig)
    return True


# ------------------------------------------------------------------ harness
def take(sc: SC, outdir: pathlib.Path, tag: str, events: list[tuple[str, dict]],
         gap=0.75) -> dict:
    """Record while firing `events` (sound, params) in sequence, then analyse."""
    wav = outdir / f"{tag}.wav"
    sc.send(f's.prepareForRecord("{wav}"); SystemClock.sched(0.5, {{ s.record }});')
    time.sleep(1.6)
    for sound, kw in events:
        play(sound, **kw)
        time.sleep(gap)
    time.sleep(0.6)
    sc.send("s.stopRecording;")
    for _ in range(20):                      # wait for the file to settle
        if wav.exists() and wav.stat().st_size > 44:
            time.sleep(0.4)
            break
        time.sleep(0.3)
    info = {"tag": tag, "file": wav.name}
    if wav.exists():
        x, sr = load_wav(wav)
        info |= features(x, sr)
        info["fundamentals"] = fundamentals(x, sr)
        info["spectrogram"] = f"{tag}.png" if spectrogram(wav, outdir / f"{tag}.png") else None
    return info


def quiet(x: dict) -> bool:
    return x.get("peak", 0) < 0.01 or x.get("rms", 0) < 0.0005


# ------------------------------------------------------------------ tests
def test_selftest(sc: SC, out: pathlib.Path):
    """Measurement chain: a synth played straight to bus 0 must be recorded.
    If this fails, the SUITE is broken — do not conclude anything about the music."""
    sc.send('{ SinOsc.ar(440) * 0.3 }.play;')
    time.sleep(0.5)
    r = take(sc, out, "selftest", [("bd", dict(orbit=0, gain=0.9))])
    ok = not quiet(r)
    return ok, r, [f"peak {r.get('peak')} rms {r.get('rms')}",
                   "fails ⇒ the recording/analysis path is broken, not the audio"]


BANKS = ["jrhodes", "sprvibe", "notes", "newnotes", "psr", "casio"]


def test_bank(sc: SC, out: pathlib.Path, bank: str = "jrhodes"):
    """Is a sample bank chromatic (one note per index)? Compare real pitches."""
    r = take(sc, out, f"bank-{bank}",
             [(bank, dict(n=i, orbit=0, amp=0.85)) for i in (0, 12, 24)], gap=0.9)
    fs = r.get("fundamentals", [])
    if len(fs) >= 3:
        # a chromatic bank gives roughly 2x per 12 indices; report the ratio
        ratio12, ratio24 = fs[1] / fs[0], fs[2] / fs[1]
        chromatic = ratio12 > 1.35 and ratio24 > 1.35
        notes = [f"pitches n=0/12/24: {fs[0]} / {fs[1]} / {fs[2]} Hz",
                 f"steps: ×{ratio12:.2f}, ×{ratio24:.2f}  (chromatic ⇒ ≈×1.4–2.0 each)",
                 f"verdict: {'CHROMATIC' if chromatic else 'NOT usable for melody by index'}"]
    else:
        chromatic = False
        notes = [f"only {len(fs)} pitch(es) detected: {fs}"]
    return bool(chromatic), (r | {"bank": bank}), notes


def test_notes(sc: SC, out: pathlib.Path):
    """Can four different notes come out at all? (the question of the evening)"""
    r = take(sc, out, "notes", [("jrhodes", dict(n=i, orbit=0, amp=0.85)) for i in (24, 26, 28, 30)])
    fs = r.get("fundamentals", [])
    ok = not quiet(r) and len(fs) >= 3
    return ok, r, [f"peaks found: {fs}", f"distinct notes: {len(fs)} (want ≥3)"]


def test_orbit(sc: SC, out: pathlib.Path):
    """Same sample on several orbits: catches the 'only orbit 0 is audible' bug."""
    r = take(sc, out, "orbit",
             [("bd", dict(orbit=o, gain=0.9)) for o in (0, 2, 4)]
             + [("jrhodes", dict(n=24, orbit=2, amp=0.9)),
                ("jrhodes", dict(n=24, orbit=4, amp=0.9))], gap=0.7)
    notes = [f"peak {r.get('peak')} rms {r.get('rms')} centroid {r.get('centroid_hz')}",
             "listen/see the spectrogram: three low hits (orbits 0/2/4) then two mid notes"]
    ok = not quiet(r)
    return ok, r, notes


def test_synth(sc: SC, out: pathlib.Path):
    """A synth instrument, direct-injected, on orbit 0 and orbit 2 (the bug)."""
    for orbit in (0, 2):
        sc.send(f'Synth(\\dubchord, [\\out, ~dirt.orbits[{orbit}].synthBus.index, '
                f'\\freq, 330, \\amp, 0.5, \\sustain, 0.6]);')
    time.sleep(1.5)
    r = take(sc, out, "synth", [("superpiano", dict(n="c4", orbit=0, amp=0.8)),
                                ("superpiano", dict(n="c4", orbit=2, amp=0.8))])
    ok = not quiet(r)
    return ok, r, [f"peak {r.get('peak')} rms {r.get('rms')}",
                   "spectrogram shows whether the orbit-0 note appears and the orbit-2 one does not"]


def test_ceiling(sc: SC, out: pathlib.Path):
    """The master ceiling: a deliberately loud stimulus must not exceed mCeil."""
    r = take(sc, out, "ceiling", [("bd", dict(orbit=0, gain=1.0)),
                                  ("bd", dict(orbit=0, gain=1.0))], gap=0.5)
    ceiling = 0.79
    ok = r.get("peak") is not None and r["peak"] <= ceiling + 0.02
    return ok, r, [f"peak {r.get('peak')} vs ceiling {ceiling} (allow +0.02 measurement slack)",
                   "if peak ~1.0 the master chain is NOT in the path"]


def test_meter(sc: SC, out: pathlib.Path):
    """Is the SC-side meter alive? (our only trustworthy view of our own bus)"""
    log = REPO / "sc/master-meter.log"
    if not log.exists():
        return False, {"log": str(log)}, ["no meter log — dub_master.scd did not start it"]
    age = time.time() - log.stat().st_mtime
    tail = log.read_text().strip().splitlines()[-1:]
    ok = age < 8
    return ok, {"age_s": round(age, 1), "last": tail}, [
        f"log age {age:.1f}s (want < 8)",
        f"last line: {tail[0] if tail else '(empty)'}"]


def test_banks(sc: SC, out: pathlib.Path):
    """Sweep candidate banks and report which ones are chromatic by index."""
    rows, good = [], []
    for b in BANKS:
        ok, data, notes = test_bank(sc, out, b)
        fs = data.get("fundamentals", [])
        rows.append((b, fs, ok))
        if ok:
            good.append(b)
        print(f"      {b:10s} {fs}  {'CHROMATIC' if ok else '-'}")
    return (bool(good),
            {"rows": [{"bank": b, "pitches": f, "ok": o} for b, f, o in rows],
             "chromatic": good},
            [f"chromatic banks: {good or 'none'}",
             "use one of these for melodies by index; otherwise melody via note offsets"])


TESTS = {
    "selftest": test_selftest,
    "bank": test_bank,
    "banks": test_banks,
    "notes": test_notes,
    "orbit": test_orbit,
    "synth": test_synth,
    "ceiling": test_ceiling,
    "meter": test_meter,
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--test", action="append", help="run only this test (repeatable)")
    ap.add_argument("--keep-sc", action="store_true")
    a = ap.parse_args()

    if a.list:
        for n, f in TESTS.items():
            print(f"{n:9s} {f.__doc__.splitlines()[0]}")
        return 0

    out = REPORTS / time.strftime("%Y%m%d-%H%M%S")
    out.mkdir(parents=True, exist_ok=True)
    print(f"audio test suite → {out}")

    sc = SC(keep=a.keep_sc, cmdlog=out / "commands.log")
    try:
        sc.start(log=out / "sclang.log")
    except RuntimeError as e:
        print(f"cannot test: {e}")
        return 2
    print("SuperDirt up\n")

    results, failed = [], 0
    for name in (a.test or list(TESTS)):
        fn = TESTS.get(name)
        if not fn:
            print(f"no such test: {name}")
            continue
        print(f"== {name}: {fn.__doc__.splitlines()[0]}")
        try:
            ok, data, notes = fn(sc, out)
        except Exception as e:                       # a broken test must not stop the run
            ok, data, notes = False, {"error": str(e)}, [f"test raised: {e}"]
        results.append({"test": name, "ok": ok, "data": data, "notes": notes})
        for n in notes:
            print(f"   {n}")
        print(f"   -> {'PASS' if ok else 'FAIL'}\n")
        failed += 0 if ok else 1

    (out / "report.json").write_text(json.dumps(results, indent=1))
    print(f"{len(results) - failed}/{len(results)} passed   report: {out / 'report.json'}")
    sc.stop()
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
