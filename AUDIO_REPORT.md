# Audio build report

All files are stereo 16-bit PCM WAV. `Peak dBFS` is measured after export.

| Filename | Duration | Sample rate | Peak dBFS | Source | License |
|---|---:|---:|---:|---|---|
| collision/collision_heavy_01.wav | 3.300 s | 48000 Hz | -2.49 | Freesound 237375 + Freesound 592388 | CC0 |
| collision/collision_heavy_02.wav | 2.900 s | 48000 Hz | -1.98 | Freesound 592388 + Freesound 587443 | CC0 |
| collision/collision_light_01.wav | 1.250 s | 48000 Hz | -8.00 | Freesound 726486 | CC0 |
| collision/collision_light_02.wav | 1.250 s | 48000 Hz | -7.04 | Freesound 321482 | CC0 |
| collision/collision_medium_01.wav | 2.200 s | 48000 Hz | -5.51 | Freesound 587443 | CC0 |
| collision/collision_medium_02.wav | 2.300 s | 48000 Hz | -5.04 | Freesound 587443 | CC0 |
| collision/collision_medium_03.wav | 2.800 s | 48000 Hz | -4.50 | Freesound 40158 | CC0 |
| engine/engine_acceleration.wav | 6.200 s | 48000 Hz | -3.48 | Freesound 669618 | CC0 |
| engine/engine_high_loop.wav | 5.550 s | 48000 Hz | -5.02 | Freesound 669618 | CC0 |
| engine/engine_idle_loop.wav | 5.550 s | 48000 Hz | -8.04 | Freesound 669618 | CC0 |
| engine/engine_low_loop.wav | 5.550 s | 48000 Hz | -7.05 | Freesound 669618 | CC0 |
| engine/engine_mid_loop.wav | 5.550 s | 48000 Hz | -6.02 | Freesound 669618 | CC0 |
| surface/gravel_hit_01.wav | 0.950 s | 48000 Hz | -7.01 | Freesound 529225 | CC0 |
| surface/gravel_hit_02.wav | 1.050 s | 48000 Hz | -6.45 | Freesound 529225 | CC0 |
| surface/gravel_hit_03.wav | 1.150 s | 48000 Hz | -5.96 | Freesound 251662 | CC0 |
| surface/offtrack_grass_loop.wav | 5.550 s | 48000 Hz | -8.48 | Freesound 529225 + Freesound 364712 | CC0 |
| surface/offtrack_gravel_loop.wav | 5.700 s | 48000 Hz | -8.01 | Freesound 529225 | CC0 |
| tires/brake_hard.wav | 1.700 s | 48000 Hz | -5.01 | Freesound 271337 | CC0 |
| tires/brake_light.wav | 1.350 s | 48000 Hz | -8.03 | Freesound 752837 | CC0 |
| tires/brake_lockup.wav | 2.100 s | 48000 Hz | -3.50 | Freesound 271337 + Freesound 752837 | CC0 |
| tires/tire_drift_loop.wav | 2.540 s | 48000 Hz | -5.03 | Freesound 271337 | CC0 |
| ui/start_beep.wav | 0.180 s | 48000 Hz | -7.00 | Original electronic synthesis | CC0 |
| ui/start_countdown_3.wav | 1.820 s | 48000 Hz | -7.00 | Original electronic synthesis | CC0 |

## Validation

- Sample rate: 48 kHz for every file.
- Encoding: 16-bit PCM for every file.
- Clipped samples: 0 in every file.
- Loop seam check: absolute end-to-start sample delta must be at most 0.12 full scale.

| Loop | End/start delta | Result |
|---|---:|---|
| engine/engine_high_loop.wav | 0.023529 | Pass |
| engine/engine_idle_loop.wav | 0.016876 | Pass |
| engine/engine_low_loop.wav | 0.009338 | Pass |
| engine/engine_mid_loop.wav | 0.027802 | Pass |
| surface/offtrack_grass_loop.wav | 0.005981 | Pass |
| surface/offtrack_gravel_loop.wav | 0.004700 | Pass |
| tires/tire_drift_loop.wav | 0.003662 | Pass |
