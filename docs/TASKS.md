# Tasks

## Foundation

- [x] Initialize the Git repository and documentation
- [x] Generate the Kotlin libGDX project with GDX-Liftoff
- [x] Verify Gradle sync and the checked-in wrapper
- [x] Run the desktop launcher
- [ ] Build and run the Android launcher on a real phone
- [x] Record exact generated Gradle task names in `README.md` and `AGENTS.md`
- [x] Define module boundaries, package ownership, and runtime data flow
- [x] Complete the MVP game design document

## MVP implementation

- [ ] Establish screens and asset loading
- [ ] Implement deterministic car state and arcade physics with unit tests
- [ ] Add touch and desktop debug controls
- [ ] Define an original track, checkpoints, and collision boundaries
- [ ] Implement ordered checkpoints, laps, timing, and positions with tests
- [ ] Add three waypoint-following AI opponents
- [ ] Implement countdown, pause, HUD, and results
- [ ] Persist the best time
- [ ] Add original or properly licensed visuals and basic sounds

## Quality gates

- [x] Unit tests pass
- [x] Desktop launcher runs correctly
- [x] Android debug APK builds
- [ ] Touch controls are validated on a real phone
- [ ] Frame pacing and memory use are acceptable on the target phone
- [ ] Asset licenses and attribution are documented
- [ ] MVP playthrough completes without invalid laps or progression blockers
