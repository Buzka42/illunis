# Weather display contract

Implemented 2026-09-12. Open-Meteo is the installed source; OFF disables display
and refresh. The selected Settings home supplies coordinates. The weather sheet
states that coordinates are sent to the selected service and provides explicit
refresh. Enabling a source also refreshes. GPS selection is not implemented.

The request uses two forecast days and Unix timestamps. API epoch values are
parsed as UTC instants and converted to the device clock for hourly labels and
civil-day timeline placement. Unzoned legacy string fixtures are treated as UTC.
Missing/nonfinite current temperatures fail closed; missing hourly temperatures
are skipped rather than displayed as zero.

The display uses the service's existing three-hour freshness contract. Cache is
in memory only. A failed refresh retains the last good observation until stale;
source/home changes discard old data. Request generations reject responses that
arrive after source changes, location changes, cache replacement or disposal.
Unknown source IDs do not silently select another provider. The sky and forecast
both reject observations for another selected home.

Precipitation marks require positive finite intensity and probability. Rain is a
slanted stroke, snow is three crossed axes, and hail is a square. Radius and
opacity follow `clamp(mm / 4) * clamp(probability)`; no valid inputs means no mark.
Symbols occupy the forecast lane within the existing 48 dp timeline. Confirmed
calorie marks remain separate from projected weather.

WMO interpretation: rain codes 51–67 (listed supported values), 80–82 and 95;
snow 71, 73, 75, 77, 85, 86; hail 96 and 99. See the primary
[Open-Meteo API documentation](https://open-meteo.com/en/docs) for timestamp and
weather-code definitions. The forecast sheet identifies Open-Meteo and shows
hourly temperatures, probability and precipitation intensity.

Automated tests use mocked transport. No background refresh scheduler,
disk cache, GPS permission or physical-device network verification was added.
