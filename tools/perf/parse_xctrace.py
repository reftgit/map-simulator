#!/usr/bin/env python3
"""Reads an Instruments "Activity Monitor" trace recorded from an iPhone.

    python3 -I tools/perf/parse_xctrace.py thermal <trace>        # last state, e.g. "Nominal"
    python3 -I tools/perf/parse_xctrace.py summary <trace> [proc]  # JSON: thermal intervals, peak footprint

Uses `xcrun xctrace export`; the tables are activity-monitor-process-live
(memory-physical-footprint per process, ~1 s samples) and
device-thermal-state-intervals.
"""
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

UNITS = {"bytes": 1, "kib": 1024, "mib": 1024 ** 2, "gib": 1024 ** 3}
ORDER = ["Nominal", "Fair", "Serious", "Critical"]


def export(trace, schema):
    xpath = f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'
    out = subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--xpath", xpath],
                         capture_output=True, check=True).stdout
    return ET.fromstring(out) if out.strip() else None


def rows(root):
    """Yields dicts of column mnemonic -> formatted value, resolving id/ref."""
    if root is None:
        return
    cols = [c.findtext("mnemonic") for c in root.find(".//schema").findall("col")]
    ids = {}
    for row in root.iter("row"):
        values = []
        for cell in list(row):
            for el in cell.iter():
                if "id" in el.attrib:
                    ids[el.attrib["id"]] = el.attrib.get("fmt", el.text)
            values.append(ids.get(cell.attrib["ref"]) if "ref" in cell.attrib else cell.attrib.get("fmt", cell.text))
        yield dict(zip(cols, values))


def to_bytes(text):
    match = re.match(r"([\d.,]+)\s*(\w+)", text or "")
    if not match:
        return 0
    digits = match.group(1)
    # xctrace formats with the Mac's locale (here Turkish: "1,02 GiB", "1.010 MiB").
    if "," in digits:
        digits = digits.replace(".", "").replace(",", ".")
    elif re.fullmatch(r"\d{1,3}(\.\d{3})+", digits):
        digits = digits.replace(".", "")
    return int(float(digits) * UNITS.get(match.group(2).lower(), 1))


def thermal_intervals(trace):
    result = []
    for row in rows(export(trace, "device-thermal-state-intervals")):
        state = next((s for s in ORDER if any(s in str(v) for v in row.values())), None)
        if state:
            result.append({"start": row.get("start"), "duration": row.get("duration"), "state": state})
    return result


def summary(trace, process="map_simulator"):
    thermal = thermal_intervals(trace)
    footprints = []
    for row in rows(export(trace, "activity-monitor-process-live")):
        if process in str(row.get("process", "")):
            footprints.append(to_bytes(row.get("memory-physical-footprint")))
    states = [t["state"] for t in thermal]
    return {
        "thermal_intervals": thermal,
        "thermal_start": states[0] if states else None,
        "thermal_end": states[-1] if states else None,
        "thermal_max": max(states, key=ORDER.index) if states else None,
        "footprint_peak_mib": round(max(footprints) / 1024 ** 2) if footprints else None,
        "footprint_samples": len(footprints),
    }


if __name__ == "__main__":
    mode, trace = sys.argv[1], sys.argv[2]
    if mode == "thermal":
        intervals = thermal_intervals(trace)
        print(intervals[-1]["state"] if intervals else "unknown")
    else:
        print(json.dumps(summary(trace, *(sys.argv[3:4] or ["map_simulator"])), indent=1))
