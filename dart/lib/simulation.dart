// Headless, deterministic gameplay simulation contracts for Toy Racers.
//
// This library is intentionally independent of Flutter, Flame, and `dart:ui`.
// Presentation code must observe simulation state through this boundary rather
// than implementing gameplay rules of its own.

export 'simulation/ai/ai_driver.dart';
export 'simulation/ai/ai_race_context.dart';
export 'simulation/car/car_config.dart';
export 'simulation/car/car_model.dart';
export 'simulation/car/car_physics.dart';
export 'simulation/car/car_state.dart';
export 'simulation/collision/collision_system.dart';
export 'simulation/compatibility/compatibility_exception.dart';
export 'simulation/compatibility/behavior_simulation.dart';
export 'simulation/compatibility/compatibility_models.dart';
export 'simulation/compatibility/compatibility_parser.dart';
export 'simulation/compatibility/compatibility_trace_json.dart';
export 'simulation/input/driver_input.dart';
export 'simulation/input/player_control_config.dart';
export 'simulation/math/float32.dart';
export 'simulation/race/race_phase.dart';
export 'simulation/race/race_session.dart';
export 'simulation/scenario/simulation_scenario.dart';
export 'simulation/snapshot/simulation_snapshot.dart';
export 'simulation/surface/surface_speed_config.dart';
export 'simulation/surface/surface_speed_system.dart';
export 'simulation/surface/surface_type.dart';
export 'simulation/track/checkpoint.dart';
export 'simulation/track/start_grid_position.dart';
export 'simulation/track/tiled_track_adapter.dart';
export 'simulation/track/track.dart';
export 'simulation/track/track_geometry.dart';
export 'simulation/track/track_id.dart';
export 'simulation/track/track_loader.dart';
export 'simulation/track/track_point.dart';
