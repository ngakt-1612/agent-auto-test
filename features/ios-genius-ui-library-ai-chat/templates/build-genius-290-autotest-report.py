#!/usr/bin/env python3
"""Build the Genius 2.9.0 autotest report (UI + gen image + gen video) as one self-contained HTML.

Sources (all produced by scripts/run-genius-290-device-suite.sh):
  runs/*.verdicts        VERDICT|<TC>|<PASS|FAIL|NA|MISMATCH>|<actual>  (2.9.0 UI suites)
  runs/<name>.log        "✅ TC 04 — ..." / "⚠️ TC 09 — ..." lines      (ported gen suites)
  runs/<name>-shots/     screenshots exported from .xcresult (+ manifest.json)
Figma frames come from the split PDF (one PNG per phone frame) and sit next to the device shot.
The latest run wins per TC. Usage: build-genius-290-autotest-report.py <runs_dir> <figma_frames_dir> <out.html>
"""
import base64, glob, html, json, os, re, subprocess, sys, tempfile

RUNS, FIGMA, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SPEC = json.load(open(os.path.join(RUNS, "..", "spec-cases.json")))  # {suite: {tc: {...}}}
NOTES = json.load(open(os.path.join(RUNS, "..", "verdict-notes.json")))  # manual reviews after looking at shots
FIGMA_MAP = json.load(open(os.path.join(RUNS, "..", "figma-map.json")))   # {suite|tc: "page-06-f03"}
TMP = tempfile.mkdtemp()


def thumb(path, width=300):
    """Downscale to JPEG and inline as base64 so the report is one file."""
    if not path or not os.path.exists(path):
        return ""
    out = os.path.join(TMP, f"{abs(hash(path))}.jpg")
    if not os.path.exists(out):
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "70", "-Z", str(width * 2), path,
                        "--out", out], capture_output=True)
    return "data:image/jpeg;base64," + base64.b64encode(open(out, "rb").read()).decode()


def run_order(path):
    return os.path.getmtime(path)


# ---- collect verdicts -------------------------------------------------------------------------
results = {}  # (suite, tc) -> dict(status, actual, run, shots)
for vf in sorted(glob.glob(os.path.join(RUNS, "*.verdicts")), key=run_order):
    run = os.path.basename(vf)[:-9]
    for line in open(vf, encoding="utf-8"):
        _, tc, status, actual = (line.rstrip("\n").split("|", 3) + [""])[:4]
        prev = results.get(("ui", tc))
        # NA = the case could not run this time; it must not erase an earlier real measurement.
        if status == "NA" and prev and prev["status"] != "NA":
            continue
        results[("ui", tc)] = dict(status=status, actual=actual, run=run)

GEN_LINE = re.compile(r"^\s*(✅|⚠️|❌)\s*TC\s*(\d+)[^—\-]*[—\-]\s*(.*)$")
for log in sorted(glob.glob(os.path.join(RUNS, "*.log")), key=run_order):
    run = os.path.basename(log)[:-4]
    suite = "image" if run.startswith("img-") else "video" if run.startswith("vid-") else None
    if not suite:
        continue
    for line in open(log, encoding="utf-8", errors="ignore"):
        m = GEN_LINE.match(line)
        if not m:
            continue
        mark, tc, text = m.groups()
        status = {"✅": "PASS", "❌": "FAIL", "⚠️": "CHECK"}[mark]
        key = (suite, str(int(tc)))
        prev = results.get(key)
        # A ✅ in the same run beats an earlier ⚠️ (suites retry, then confirm).
        if prev and prev["run"] == run and prev["status"] == "PASS" and status == "CHECK":
            continue
        results[key] = dict(status=status, actual=text.strip(), run=run)

for key, note in NOTES.items():  # human review overrides (e.g. test error, spec mismatch)
    suite, tc = key.split("|")
    results.setdefault((suite, tc), dict(run="", actual=""))
    results[(suite, tc)].update(note)


def shot_for(suite, tc, run):
    manifest = os.path.join(RUNS, f"{run}-shots", "manifest.json")
    if not run or not os.path.exists(manifest):
        return ""
    needle = tc if suite == "ui" else f"TC {int(tc):02d}"
    alt = None if suite == "ui" else f"TC {int(tc)} "
    for t in json.load(open(manifest)):
        for a in t["attachments"]:
            name = a["suggestedHumanReadableName"]
            if needle in name or (alt and alt in name):
                return os.path.join(RUNS, f"{run}-shots", a["exportedFileName"])
    return ""


# ---- render -----------------------------------------------------------------------------------
LABEL = {"PASS": ("PASS", "p"), "FAIL": ("FAIL", "f"), "MISMATCH": ("Lệch spec", "m"), "NA": ("N/A", "n"),
         "CHECK": ("Cần xem", "c"), "TESTERR": ("Lỗi phía test", "c"), None: ("Chưa chạy", "n")}
# Scope = the 2.9.0 testcase set only. Gen-image/gen-video know-how is applied inside these TCs
# (upload → generating → result, background generation), not run as separate legacy suites.
SUITES = [("ui", os.environ.get("G290_SUITE_TITLE", "Update UI + Library — 84 TC spec 2.9.0"))]

sections, kpi = [], {}
for suite, title in SUITES:
    rows, counts = [], {}
    for tc, spec in SPEC[suite].items():
        r = results.get((suite, tc), {})
        st = r.get("status")
        counts[st] = counts.get(st, 0) + 1
        lab, cls = LABEL.get(st, LABEL[None])
        fig = FIGMA_MAP.get(f"{suite}|{tc}")
        fig_img = thumb(os.path.join(FIGMA, fig + ".png")) if fig else ""
        dev_img = thumb(shot_for(suite, tc, r.get("run", "")))
        img = lambda src, cap: f'<figure><img loading="lazy" src="{src}" alt="{cap}"><figcaption>{cap}</figcaption></figure>' if src else '<span class="none">—</span>'
        rows.append(f"""<tr data-st="{cls}"><td class="id">{html.escape(tc if suite == 'ui' else 'TC ' + tc)}</td>
<td class="ttl">{html.escape(spec['title'])}<span class="prio">{html.escape(spec.get('priority',''))}</span></td>
<td class="tc"><details><summary>Precondition · Action</summary><p class="lbl">Precondition</p><p>{html.escape(spec.get('pre',''))}</p>{('<p class="lbl">Test data</p><p>' + html.escape(spec['data']) + '</p>') if spec.get('data') not in ('', 'N/A', None) else ''}<p class="lbl">Action</p><p>{html.escape(spec.get('action',''))}</p></details></td>
<td class="exp">{html.escape(spec['expected'])}</td>
<td class="act">{html.escape(r.get('actual', ''))}{'<p class="note">' + html.escape(r['note']) + '</p>' if r.get('note') else ''}</td>
<td class="img">{img(fig_img, 'Figma ' + (fig or ''))}</td><td class="img">{img(dev_img, 'Máy thật')}</td>
<td class="st"><span class="chip {cls}">{lab}</span></td></tr>""")
    kpi[suite] = counts
    total = len(SPEC[suite]); done = total - counts.get(None, 0)
    chips = " ".join(f'<span class="chip {LABEL.get(k, LABEL[None])[1]}">{LABEL.get(k, LABEL[None])[0]} {v}</span>'
                     for k, v in sorted(counts.items(), key=lambda kv: str(kv[0])))
    sections.append(f"""<section><h2>{title}</h2><p class="sum">{done}/{total} case đã chạy · {chips}</p>
<div class="wrap"><table><thead><tr><th>TC</th><th>Kịch bản</th><th>Testcase</th><th>Expected (spec)</th><th>Kết quả chạy thật</th>
<th>Figma 2.9.0</th><th>Máy thật</th><th>Verdict</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div></section>""")

summary = json.load(open(os.path.join(RUNS, "..", "report-summary.json")))
page = open(os.path.join(os.path.dirname(__file__), "genius-290-report-template.html"), encoding="utf-8").read()
page = page.replace("{{SUMMARY}}", summary["html"]).replace("{{SECTIONS}}", "\n".join(sections))
open(OUT, "w", encoding="utf-8").write(page)
print("report:", OUT, {s: kpi[s] for s in kpi})
