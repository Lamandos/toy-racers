/// Stable IDs and display names of the built-in track definitions.
enum TrackId {
  livingRoom(id: 'track-01', displayName: 'LIVING ROOM'),
  bathroom(id: 'track-02', displayName: 'BATHROOM');

  const TrackId({required this.id, required this.displayName});

  final String id;
  final String displayName;

  static TrackId fromId(String id) {
    for (final trackId in TrackId.values) {
      if (trackId.id == id) {
        return trackId;
      }
    }
    throw ArgumentError.value(id, 'id', 'Unknown track');
  }
}
