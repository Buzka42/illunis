"""Refresh the offline Warsaw geometry fixture from NASA/JPL Horizons.

Run from the repository root: python tool/ephemeris/fetch_horizons.py
Requests are sequential; no runtime app dependency or network access is added.
Observer: east longitude 21.01 deg, north latitude 52.23 deg, sea level.
Airless apparent coordinates isolate geometry from variable refraction.
Sun rise/set is the interpolated -0.833 deg centre crossing on a one-minute
grid. Moon positions and illumination are sampled every three hours.
"""

import csv
import datetime as dt
import io
import json
import subprocess
from pathlib import Path
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'app/test/sky/fixtures/warsaw_horizons_2026.json'
DATES = [('2026-03-20', 1), ('2026-06-21', 2), ('2026-09-09', 2),
         ('2026-09-23', 2), ('2026-12-21', 1)]


def query(body, date, offset):
    start = dt.datetime.fromisoformat(date) - dt.timedelta(hours=offset)
    end = start + dt.timedelta(days=1)
    params = dict(format='json', COMMAND=str(body), EPHEM_TYPE='OBSERVER',
                  CENTER='coord@399', COORD_TYPE='GEODETIC',
                  SITE_COORD='21.01,52.23,0',
                  START_TIME=start.isoformat(' '), STOP_TIME=end.isoformat(' '),
                  STEP_SIZE='1 m' if body == 10 else '3 h',
                  QUANTITIES='4,10', ANG_FORMAT='DEG', APPARENT='AIRLESS',
                  CSV_FORMAT='YES', EXTRA_PREC='YES', OBJ_DATA='NO')
    encoded = {k: v if k == 'format' else f"'{v}'" for k, v in params.items()}
    url = 'https://ssd.jpl.nasa.gov/api/horizons.api?' + urllib.parse.urlencode(encoded)
    # Windows curl uses the OS trust store (including managed proxy roots).
    # Certificate verification stays enabled.
    payload = json.loads(subprocess.check_output(
        ['curl.exe' if __import__('os').name == 'nt' else 'curl',
         '--fail', '--silent', '--show-error', '--max-time', '60', url],
        text=True, encoding='utf-8'))
    result = payload.get('result', '')
    if '$$SOE' not in result:
        raise RuntimeError(payload)
    rows = []
    for row in csv.reader(io.StringIO(result.split('$$SOE')[1].split('$$EOE')[0])):
        if not row:
            continue
        rows.append(dict(utc=row[0].strip(), azimuthDeg=float(row[3]),
                         altitudeDeg=float(row[4]), illuminatedPercent=float(row[5])))
    return rows


def crossings(rows):
    events = {}
    for minute, (a, b) in enumerate(zip(rows, rows[1:])):
        va, vb = a['altitudeDeg'] + .833, b['altitudeDeg'] + .833
        if va * vb < 0:
            events['sunrise' if va < vb else 'sunset'] = minute + -va / (vb - va)
    return events


def main():
    fixture = dict(source='NASA/JPL Horizons DE441 observer ephemerides',
                   documentation='https://ssd.jpl.nasa.gov/horizons/manual.html',
                   observer=dict(latitudeDeg=52.23, longitudeDeg=21.01, elevationKm=0),
                   apparent='AIRLESS', riseSetCentreAltitudeDeg=-.833,
                   fetchedAtUtc=dt.datetime.now(dt.timezone.utc).isoformat(), days=[])
    for date, offset in DATES:
        print(f'Fetching {date}: Sun', flush=True)
        sun = query(10, date, offset)
        print(f'Fetching {date}: Moon', flush=True)
        moon = query(301, date, offset)
        fixture['days'].append(dict(date=date, utcOffsetHours=offset,
                                    sun=sun[::180], moon=moon,
                                    eventsLocalMinutes=crossings(sun)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(fixture, indent=2) + '\n', encoding='utf-8')
    print(OUT)


if __name__ == '__main__':
    main()
