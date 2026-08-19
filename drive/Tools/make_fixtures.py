#!/usr/bin/env python3
"""Generates the four synthetic GPX fixtures from known geometry.

The fixtures exist so the analysis pipeline can be iterated on at a desk
instead of in a car. Every road here is built from exact straights and
constant-radius arcs, so the curvature the analysis should find is known
analytically before anything is measured.

Run: python3 Tools/make_fixtures.py
Writes: Sources/Fixtures/GPX/*.gpx
"""
import math, os, datetime

R_EARTH = 6371008.8          # metres, WGS84 mean radius; matches Geo.swift
SAMPLE_HZ = 5.0              # fixtures are sparser than the 10 Hz recorder,
                             # which is fine: analysis resamples by distance
LAT0, LON0 = 46.5000000, 11.0000000   # somewhere in the Dolomites, for flavour

def to_latlon(x, y):
    """Local tangent plane (metres, x east, y north) -> degrees."""
    lat = LAT0 + math.degrees(y / R_EARTH)
    lon = LON0 + math.degrees(x / (R_EARTH * math.cos(math.radians(LAT0))))
    return lat, lon

class Road:
    """A path built from straights and arcs, walked at a chosen speed."""

    def __init__(self, heading_deg=0.0, climb_per_km=0.0):
        self.segments = []           # (kind, ...)
        self.heading = math.radians(heading_deg)
        self.climb = climb_per_km

    def straight(self, length, speed):
        self.segments.append(("straight", length, speed))
        return self

    def arc(self, radius, angle_deg, direction, speed=None):
        """direction: +1 right, -1 left. Speed defaults to the fastest that
        keeps lateral acceleration at 4.0 m/s^2, capped at 33 m/s."""
        if speed is None:
            speed = min(33.0, math.sqrt(4.0 * radius))
        self.segments.append(("arc", radius, math.radians(angle_deg), direction, speed))
        return self

    def stop(self, duration):
        self.segments.append(("stop", duration))
        return self

    def points(self):
        """Yields (t, x, y, z) at SAMPLE_HZ."""
        dt = 1.0 / SAMPLE_HZ
        x = y = 0.0
        t = 0.0
        distance = 0.0
        heading = self.heading                 # radians, 0 = north, clockwise
        out = [(0.0, 0.0, 0.0, 0.0)]
        for seg in self.segments:
            if seg[0] == "stop":
                duration = seg[1]
                n = int(round(duration / dt))
                for _ in range(n):
                    t += dt
                    out.append((t, x, y, distance * self.climb / 1000.0))
                continue
            if seg[0] == "straight":
                _, length, speed = seg
                travelled = 0.0
                while travelled < length - 1e-9:
                    step = min(speed * dt, length - travelled)
                    x += step * math.sin(heading)
                    y += step * math.cos(heading)
                    travelled += step
                    distance += step
                    t += dt
                    out.append((t, x, y, distance * self.climb / 1000.0))
            else:
                _, radius, angle, direction, speed = seg
                length = radius * angle
                travelled = 0.0
                while travelled < length - 1e-9:
                    step = min(speed * dt, length - travelled)
                    dtheta = direction * step / radius
                    # advance along the arc: move then turn, small steps
                    x += step * math.sin(heading + dtheta / 2)
                    y += step * math.cos(heading + dtheta / 2)
                    heading += dtheta
                    travelled += step
                    distance += step
                    t += dt
                    out.append((t, x, y, distance * self.climb / 1000.0))
        return out

def write_gpx(path, name, road, start=datetime.datetime(2024, 6, 12, 18, 40, 0)):
    points = road.points()
    rows = []
    for (t, x, y, z) in points:
        lat, lon = to_latlon(x, y)
        stamp = (start + datetime.timedelta(seconds=t)).strftime("%Y-%m-%dT%H:%M:%S.") \
            + "%03dZ" % (int(round((t % 1) * 1000)))
        rows.append(
            '   <trkpt lat="%.7f" lon="%.7f"><ele>%.1f</ele><time>%s</time></trkpt>'
            % (lat, lon, z, stamp)
        )
    doc = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<gpx version="1.1" creator="make_fixtures.py" xmlns="http://www.topografix.com/GPX/1/1">\n'
        ' <trk>\n  <name>%s</name>\n  <trkseg>\n%s\n  </trkseg>\n </trk>\n</gpx>\n'
        % (name, "\n".join(rows))
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(doc)
    print("%-28s %5d points  %6.0f m" % (os.path.basename(path), len(points), path_length(points)))

def path_length(points):
    total = 0.0
    for a, b in zip(points, points[1:]):
        total += math.hypot(b[1] - a[1], b[2] - a[2])
    return total

# --- the four roads -------------------------------------------------------

def hairpin_pass():
    """A mountain pass: eight hairpins linked by short straights, climbing.
    The first hairpin is isolated by 300 m of straight so a test can assert
    that one hairpin resolves as exactly one corner."""
    r = Road(heading_deg=0, climb_per_km=60.0)
    r.straight(300, 8.0)
    r.arc(12, 180, -1)             # the isolated hairpin, left
    r.straight(300, 8.0)
    for i in range(7):
        direction = 1 if i % 2 == 0 else -1
        r.arc(14 + i, 170 - 4 * i, direction)
        r.straight(120 + 20 * i, 11.0)
    return r

def sweepers():
    """A fast flowing road: long constant-radius sweepers, alternating, with
    short straights between them. This is what 'flow' is supposed to reward."""
    r = Road(heading_deg=45)
    r.straight(200, 27.0)
    # One of these (the 500 m) is deliberately too open to count as a
    # corner, so the fixture proves the threshold as well as the counting.
    radii = [180, 240, 150, 500, 200, 260, 170, 220]
    for i, radius in enumerate(radii):
        r.arc(radius, 55 + 5 * (i % 3), 1 if i % 2 == 0 else -1)
        r.straight(80, 27.0)
    r.straight(400, 27.0)
    return r

def motorway():
    """Ten kilometres of motorway: dead straight apart from two 2 km-radius
    bends, which are not corners by any definition worth having."""
    r = Road(heading_deg=350)
    r.straight(3000, 33.0)
    r.arc(2000, 20, 1, speed=33.0)
    r.straight(3000, 33.0)
    r.arc(2500, 15, -1, speed=33.0)
    r.straight(3000, 33.0)
    return r

def urban():
    """Stop-start town driving: right angles at junctions, a stop at each."""
    r = Road(heading_deg=90)
    for i in range(8):
        r.straight(220 + 30 * (i % 3), 12.0)
        r.stop(18)
        r.arc(14, 90, 1 if i % 2 == 0 else -1, speed=6.0)
    r.straight(200, 12.0)
    return r

if __name__ == "__main__":
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(here, "Sources", "Fixtures", "GPX")
    write_gpx(os.path.join(out, "hairpin-pass.gpx"), "Hairpin pass", hairpin_pass(),
              datetime.datetime(2024, 6, 12, 19, 15, 0))          # sun at -1.6 deg: dusk
    write_gpx(os.path.join(out, "sweepers.gpx"), "Sweepers", sweepers(),
              datetime.datetime(2024, 6, 12, 4, 45, 0))           # sun at +11.6 rising: morning
    write_gpx(os.path.join(out, "motorway.gpx"), "Motorway", motorway(),
              datetime.datetime(2024, 6, 12, 13, 0, 0))           # sun at +58 deg: day
    write_gpx(os.path.join(out, "urban.gpx"), "Urban", urban(),
              datetime.datetime(2024, 12, 3, 22, 30, 0))          # sun at -65 deg: night
