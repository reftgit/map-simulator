# Galaxy Tab A7 power, 2026-11-05 (Phase 6e)

`dumpsys battery` readings over adb during the session (the tablet on the Mac's USB port; the meta files of `intermediate/` have the per-launch values):

| When | Level | Current | Max charging current | Source | Temperature |
|---|---|---|---|---|---|
| before the first probe build was installed | 31 % | −971 mA | 300 mA | AC | 34.0 °C |
| the intermediate launches (16:32–16:38) | 18 → 15 % | −733 to −1,059 mA | — | AC | 36.5–37.5 °C |
| after the user's answer "charged, unlocked" (adb over Wi-Fi, USB still listed) | 0 % (3.51 V) | −808 to −836 mA | 250 mA | AC | 36.0 °C |

The user had chosen a wall charger with wireless adb; adb was switched to TCP over Wi-Fi (`adb tcpip`) while the tablet was on USB. The tablet stayed on a supply reporting 250 mA, and after the 0 % reading the user answered that there is no charger, so the tablet's repeat (map ready, D25's relative criterion, the routes) was not run. The tablet switched off shortly after (it disappeared from adb and USB), and the user chose not to check the final code on it either.
