# Racing audio sources

All downloaded automotive source files are public **HQ MP3 previews** of real-world recordings
hosted by Freesound. Each source page identifies the recording and its **Creative Commons 0**
license. CC0 permits copying, modification, distribution, and commercial use without permission
or mandatory attribution. The preview files are kept unchanged in `sources/`; `build_audio.py`
performs all trimming, filtering, crossfades, mixing, level adjustment, and WAV export.

The source-page URLs below are the authoritative license records. Accessed 2026-07-30.

| Local source | Title | Author | Source / URL | License | Final sounds |
|---|---|---|---|---|---|
| `669618_mini_cooper_engine.mp3` | Car Engine Contact Recording—Mini Cooper S 2019.wav | TheLittleCrow | [Freesound 669618](https://freesound.org/people/TheLittleCrow/sounds/669618/) | CC0 | All engine RPM loops and acceleration |
| `271337_car_peels_off.mp3` | Car peels off | therisingorder | [Freesound 271337](https://freesound.org/people/therisingorder/sounds/271337/) | CC0 | Drift loop, hard brake, lockup layer |
| `752837_distant_tire_screech.mp3` | Distant car tire screeching | LukaCafuka | [Freesound 752837](https://freesound.org/people/LukaCafuka/sounds/752837/) | CC0 | Light brake and lockup variation layer |
| `237375_car_crash.mp3` | Car Crash | squareal | [Freesound 237375](https://freesound.org/people/squareal/sounds/237375/) | CC0 | Heavy collision 01 body/metal layer |
| `592388_car_crash_glass.mp3` | Car Crash (with Glass) | magnuswaker | [Freesound 592388](https://freesound.org/people/magnuswaker/sounds/592388/) | CC0 | Heavy collision glass/metal layers |
| `726486_rc_car_metal_impact.mp3` | Impact on metal | JoMungus | [Freesound 726486](https://freesound.org/people/JoMungus/sounds/726486/) | CC0 | Light collision 01 |
| `40158_metal_crash.mp3` | crash.wav | moxobna | [Freesound 40158](https://freesound.org/people/moxobna/sounds/40158/) | CC0 | Medium collision 03 |
| `321482_metal_hit.mp3` | Metal Hit 2 | dslrguide | [Freesound 321482](https://freesound.org/people/dslrguide/sounds/321482/) | CC0 | Light collision 02 |
| `587443_scrap_metal_variants.mp3` | Scrap metal dropping / crashing | SamsterBirdies | [Freesound 587443](https://freesound.org/people/SamsterBirdies/sounds/587443/) | CC0 | Two distinct medium impacts and heavy 02 layer |
| `529225_car_tires_gravel.mp3` | Car Tires Start and Stop on Gravel Shoulder.wav | UnplugTheFridge | [Freesound 529225](https://freesound.org/people/UnplugTheFridge/sounds/529225/) | CC0 | Gravel/grass vehicle loops and gravel hits 01–02 |
| `251662_tires_gravel_road.mp3` | Tires on Gravel Road 2 | OBXJohn | [Freesound 251662](https://freesound.org/people/OBXJohn/sounds/251662/) | CC0 | Gravel hit 03 |
| `364712_rustling_grass.mp3` | Rustling Grass | Allan Legemaate (`alegemaate`) | [Freesound 364712](https://freesound.org/people/alegemaate/sounds/364712/) | CC0 | Grass surface layer |

## Original generated UI audio

`start_beep.wav` and `start_countdown_3.wav` are original electronic interface sounds generated
by `build_audio.py`. They contain no third-party samples. Synthesis is limited to these UI beeps;
no automotive effect is procedurally synthesized.
