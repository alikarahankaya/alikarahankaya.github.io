#!/usr/bin/env python3
"""Reference implementation of the analysis pipeline, used to pin down the
constants and the expected values that the Swift tests assert. Not shipped,
not part of the app: Analysis.swift is the real thing. This exists so the
numbers in the tests were measured rather than guessed.
"""
import math, re, sys, os, datetime

R_EARTH = 6371008.8

# --- tuning (mirrors Analysis/Tuning.swift) -------------------------------
RESAMPLE_SPACING = 1.0
SMOOTH_HALF_WIDTH = 10        # 21 m window
SMOOTH_ORDER = 3
CURVATURE_ARM = 15            # metres either side
CORNER_ENTER = 1.0 / 300.0    # radius 300 m
CORNER_EXIT = 1.0 / 450.0     # hysteresis
CORNER_MIN_LENGTH = 12.0
CORNER_MERGE_GAP = 20.0
FLOW_MAX_GAP = 150.0
FLOW_STOP_SPEED = 2.0
SEVERITY_RADII = [15, 25, 40, 70, 120, 300]

def parse_gpx(path):
    text = open(path).read()
    pts = []
    for m in re.finditer(r'<trkpt[^>]*lat="([-\d.]+)"[^>]*lon="([-\d.]+)"[^>]*>(.*?)</trkpt>', text, re.S):
        lat, lon = float(m.group(1)), float(m.group(2))
        body = m.group(3)
        ele = re.search(r'<ele>([-\d.]+)</ele>', body)
        tm = re.search(r'<time>([^<]+)</time>', body)
        t = datetime.datetime.strptime(tm.group(1), "%Y-%m-%dT%H:%M:%S.%fZ")
        pts.append((t, lat, lon, float(ele.group(1)) if ele else 0.0))
    t0 = pts[0][0]
    out = []
    for i, (t, lat, lon, ele) in enumerate(pts):
        out.append({"t": (t - t0).total_seconds(), "lat": lat, "lon": lon, "alt": ele,
                    "speed": -1.0, "course": -1.0, "acc": 5.0})
    # derive speed/course the way the GPX importer does
    for i in range(len(out)):
        a = out[max(0, i - 1)]
        b = out[min(len(out) - 1, i + 1)]
        dt = b["t"] - a["t"]
        if dt <= 0:
            out[i]["speed"] = 0.0
            continue
        dx, dy = enu(a["lat"], a["lon"], b["lat"], b["lon"])
        d = math.hypot(dx, dy)
        out[i]["speed"] = d / dt
        if d > 0.5:
            out[i]["course"] = (math.degrees(math.atan2(dx, dy))) % 360.0
    return out

def enu(lat0, lon0, lat, lon):
    x = math.radians(lon - lon0) * R_EARTH * math.cos(math.radians(lat0))
    y = math.radians(lat - lat0) * R_EARTH
    return x, y

def project(samples):
    lat0, lon0 = samples[0]["lat"], samples[0]["lon"]
    return [enu(lat0, lon0, s["lat"], s["lon"]) for s in samples]

def resample(samples, xy):
    """Uniform 1 m spacing along the path; carries t, speed, altitude."""
    out = []
    acc = 0.0
    out.append({"s": 0.0, "x": xy[0][0], "y": xy[0][1], "t": samples[0]["t"],
                "speed": samples[0]["speed"], "alt": samples[0]["alt"]})
    carry = 0.0
    total = 0.0
    for i in range(len(samples) - 1):
        x0, y0 = xy[i]; x1, y1 = xy[i + 1]
        seg = math.hypot(x1 - x0, y1 - y0)
        if seg <= 1e-9:
            continue
        pos = RESAMPLE_SPACING - carry
        while pos <= seg + 1e-9:
            f = pos / seg
            total_s = total + pos
            out.append({"s": total_s,
                        "x": x0 + (x1 - x0) * f, "y": y0 + (y1 - y0) * f,
                        "t": samples[i]["t"] + (samples[i + 1]["t"] - samples[i]["t"]) * f,
                        "speed": samples[i]["speed"] + (samples[i + 1]["speed"] - samples[i]["speed"]) * f,
                        "alt": samples[i]["alt"] + (samples[i + 1]["alt"] - samples[i]["alt"]) * f})
            pos += RESAMPLE_SPACING
        carry = seg - (pos - RESAMPLE_SPACING)
        total += seg
    return out

def sg_coefficients(half, order):
    """Savitzky-Golay smoothing weights for the centre of a window."""
    order = min(order, 2 * half)
    n = order + 1
    # normal equations for least squares polynomial fit, x = -half..half
    A = [[0.0] * n for _ in range(n)]
    for r in range(n):
        for c in range(n):
            A[r][c] = sum((float(i) ** (r + c)) for i in range(-half, half + 1))
    # we want the fitted value at x=0, which is the constant coefficient:
    # c = (A^-1 b) where b_r = sum(i^r * y_i). So weights w_i = sum_r inv[0][r] * i^r
    inv0 = solve_row0(A)
    return [sum(inv0[r] * (float(i) ** r) for r in range(n)) for i in range(-half, half + 1)]

def solve_row0(A):
    """First row of A^-1, by Gaussian elimination on [A | e0]."""
    n = len(A)
    M = [row[:] + [1.0 if i == 0 else 0.0 for i in range(n)] for row in A]
    # solve A^T z = e0; A is symmetric so A z = e0 gives the first column = row
    for col in range(n):
        piv = max(range(col, n), key=lambda r: abs(M[r][col]))
        M[col], M[piv] = M[piv], M[col]
        p = M[col][col]
        M[col] = [v / p for v in M[col]]
        for r in range(n):
            if r != col and M[r][col] != 0.0:
                f = M[r][col]
                M[r] = [v - f * w for v, w in zip(M[r], M[col])]
    return [M[r][n] for r in range(n)]

def smooth(points):
    n = len(points)
    cache = {}
    out = []
    for i in range(n):
        half = min(i, n - 1 - i, SMOOTH_HALF_WIDTH)
        if half < 2:
            out.append((points[i]["x"], points[i]["y"]))
            continue
        if half not in cache:
            cache[half] = sg_coefficients(half, SMOOTH_ORDER)
        w = cache[half]
        x = sum(w[k] * points[i - half + k]["x"] for k in range(2 * half + 1))
        y = sum(w[k] * points[i - half + k]["y"] for k in range(2 * half + 1))
        out.append((x, y))
    return out

def curvature(xy):
    """Signed Menger curvature; positive = right."""
    n = len(xy)
    k = [0.0] * n
    for i in range(n):
        a = i - CURVATURE_ARM
        c = i + CURVATURE_ARM
        if a < 0 or c >= n:
            continue
        (ax, ay), (bx, by), (cx, cy) = xy[a], xy[i], xy[c]
        ab = math.hypot(bx - ax, by - ay)
        bc = math.hypot(cx - bx, cy - by)
        ca = math.hypot(ax - cx, ay - cy)
        if ab < 1e-6 or bc < 1e-6 or ca < 1e-6:
            continue
        cross = (bx - ax) * (cy - by) - (by - ay) * (cx - bx)
        area2 = abs(cross)
        kappa = 2.0 * area2 / (ab * bc * ca)
        k[i] = -kappa if cross > 0 else kappa    # clockwise (right) positive
    return k

def segment(points, k):
    n = len(k)
    runs = []
    i = 0
    while i < n:
        if abs(k[i]) < CORNER_ENTER:
            i += 1
            continue
        sign = 1 if k[i] > 0 else -1
        # Extend backwards to the exit threshold as well as forwards, or the
        # hysteresis makes every corner look like it opens: the leading edge
        # would need the entry threshold while the trailing edge only needs
        # the lower exit one.
        start = i
        while start - 1 >= 0 and abs(k[start - 1]) >= CORNER_EXIT and (1 if k[start - 1] > 0 else -1) == sign:
            start -= 1
        j = i
        while j + 1 < n and abs(k[j + 1]) >= CORNER_EXIT and (1 if k[j + 1] > 0 else -1) == sign:
            j += 1
        runs.append((start, j, sign))
        i = j + 1
    # merge same-direction runs separated by a short gap
    merged = []
    for run in runs:
        if merged and merged[-1][2] == run[2] and \
           points[run[0]]["s"] - points[merged[-1][1]]["s"] < CORNER_MERGE_GAP:
            merged[-1] = (merged[-1][0], run[1], run[2])
        else:
            merged.append(list(run) if False else run)
    corners = []
    for (a, b, sign) in merged:
        length = points[b]["s"] - points[a]["s"]
        if length < CORNER_MIN_LENGTH:
            continue
        peak_i = max(range(a, b + 1), key=lambda z: abs(k[z]))
        peak = abs(k[peak_i])
        radius = 1.0 / peak if peak > 0 else 1e9
        severity = 6
        for idx, r in enumerate(SEVERITY_RADII):
            if radius < r:
                severity = idx + 1
                break
        third = max(1, (b - a + 1) // 3)
        head = sum(abs(k[z]) for z in range(a, a + third)) / third
        tail = sum(abs(k[z]) for z in range(b - third + 1, b + 1)) / third
        shape = "constant"
        if tail > head * 1.15: shape = "tightens"
        elif tail < head * 0.87: shape = "opens"
        if is_double(k, a, b, peak): shape = "double"
        lat_g = sum(abs(k[z]) * points[z]["speed"] ** 2 for z in range(a, b + 1)) / (b - a + 1) / 9.80665
        corners.append({"entry": points[a]["s"], "length": length, "dir": "right" if sign > 0 else "left",
                        "peak": peak, "radius": radius, "severity": severity,
                        "shape": shape,
                        "lat_g": lat_g})
    return corners

def is_double(k, a, b, peak):
    """Two apexes: two local maxima above 80% of the peak with a dip below
    75% of the lower one between them, at least 30% of the length apart."""
    n = b - a + 1
    if n < 40: return False
    highs = [z for z in range(a, b + 1) if abs(k[z]) >= 0.80 * peak]
    if not highs: return False
    groups = []
    start = highs[0]; prev = highs[0]
    for z in highs[1:]:
        if z - prev > 1:
            groups.append((start, prev)); start = z
        prev = z
    groups.append((start, prev))
    if len(groups) < 2: return False
    first, last = groups[0], groups[-1]
    if (last[0] - first[1]) < 0.30 * n: return False
    dip = min(abs(k[z]) for z in range(first[1], last[0] + 1))
    lower = min(max(abs(k[z]) for z in range(first[0], first[1] + 1)),
                max(abs(k[z]) for z in range(last[0], last[1] + 1)))
    return dip < 0.75 * lower

def flow(points, corners):
    if not corners:
        return 0.0
    best = 0.0
    start = 0
    for i in range(len(corners)):
        if i > 0:
            gap = corners[i]["entry"] - (corners[i - 1]["entry"] + corners[i - 1]["length"])
            stopped = any(p["speed"] < FLOW_STOP_SPEED for p in points
                          if corners[i - 1]["entry"] + corners[i - 1]["length"] <= p["s"] <= corners[i]["entry"])
            if gap > FLOW_MAX_GAP or stopped:
                start = i
        span = corners[i]["entry"] + corners[i]["length"] - corners[start]["entry"]
        best = max(best, span)
    return best

def windowed_sinuosity(pts, window=1000.0, step=250.0):
    length = pts[-1]["s"] - pts[0]["s"]
    def chord(a, b):
        return math.hypot(pts[b]["x"] - pts[a]["x"], pts[b]["y"] - pts[a]["y"])
    if length <= window:
        c = chord(0, len(pts) - 1)
        return length / c if c > 1 else 1.0
    total = 0.0; n = 0; start = 0.0
    while start + window <= length:
        a = min(len(pts) - 1, int(round(start)))
        b = min(len(pts) - 1, int(round(start + window)))
        c = chord(a, b)
        total += window / c if c > 1 else 1.0
        n += 1; start += step
    return total / n if n else 1.0

def analyse(path):
    samples = parse_gpx(path)
    xy = project(samples)
    pts = resample(samples, xy)
    sm = smooth(pts)
    k = curvature(sm)
    corners = segment(pts, k)
    length = pts[-1]["s"]
    straight = math.hypot(xy[-1][0] - xy[0][0], xy[-1][1] - xy[0][1])
    gain = loss = 0.0
    win = 50
    alts = [sum(p["alt"] for p in pts[max(0, i - win):i + win + 1]) / len(pts[max(0, i - win):i + win + 1])
            for i in range(len(pts))]
    for a, b in zip(alts, alts[1:]):
        d = b - a
        if d > 0: gain += d
        else: loss -= d
    left = sum(c["length"] for c in corners if c["dir"] == "left")
    right = sum(c["length"] for c in corners if c["dir"] == "right")
    print("== %s" % os.path.basename(path))
    print("   distance      %8.0f m   duration %6.0f s" % (length, pts[-1]["t"]))
    print("   sinuosity     %8.3f  (end-to-end %.3f)" % (windowed_sinuosity(pts), length / straight if straight > 0 else 0))
    print("   corners       %8d      density %5.1f /km" % (len(corners), len(corners) / (length / 1000)))
    print("   flow          %8.0f m" % flow(pts, corners))
    print("   left/right    %6.0f / %-6.0f m" % (left, right))
    print("   elevation     +%5.0f / -%5.0f m" % (gain, loss))
    for c in corners[:12]:
        print("     corner @%6.0f m  %-5s len %5.1f  R %6.1f  sev %d  %-8s  %.2fg"
              % (c["entry"], c["dir"], c["length"], c["radius"], c["severity"], c["shape"], c["lat_g"]))
    if len(corners) > 12:
        print("     ... %d more" % (len(corners) - 12))
    return corners

if __name__ == "__main__":
    base = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Sources", "Fixtures", "GPX")
    for f in sorted(os.listdir(base)):
        analyse(os.path.join(base, f))
