package com.example.toyracers.race

import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackPoint

data class RaceCompetitor(
    val id: String,
    val progress: RaceProgress,
    val position: TrackPoint,
)

/** Ranks cars by finish result, completed gates, and distance to the next gate. */
class PositionTracker(
    private val track: Track,
) {
    fun positions(competitors: List<RaceCompetitor>): Map<String, Int> {
        require(competitors.map(RaceCompetitor::id).distinct().size == competitors.size) {
            "Competitor ids must be unique"
        }
        return competitors
            .sortedWith(
                compareBy<RaceCompetitor> {
                    if (it.progress.finished) 0 else 1
                }.thenBy {
                    it.progress.finishPosition ?: Int.MAX_VALUE
                }.thenByDescending {
                    it.progress.completedLaps
                }.thenByDescending {
                    it.progress.currentCheckpointIndex
                }.thenBy {
                    distanceSquaredToNextGate(it)
                }.thenBy(RaceCompetitor::id),
            ).mapIndexed { index, competitor -> competitor.id to index + 1 }
            .toMap()
    }

    private fun distanceSquaredToNextGate(competitor: RaceCompetitor): Float {
        val gateCenter =
            if (competitor.progress.currentCheckpointIndex < track.checkpoints.size) {
                val gate = track.checkpoints[competitor.progress.currentCheckpointIndex].gate
                TrackPoint(
                    x = (gate.start.x + gate.end.x) / 2f,
                    y = (gate.start.y + gate.end.y) / 2f,
                )
            } else {
                TrackPoint(
                    x = track.startLine.bounds.x + track.startLine.bounds.width / 2f,
                    y = track.startLine.bounds.y + track.startLine.bounds.height / 2f,
                )
            }
        val deltaX = competitor.position.x - gateCenter.x
        val deltaY = competitor.position.y - gateCenter.y
        return deltaX * deltaX + deltaY * deltaY
    }
}
