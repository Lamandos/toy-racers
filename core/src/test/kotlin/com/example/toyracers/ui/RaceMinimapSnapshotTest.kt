package com.example.toyracers.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class RaceMinimapSnapshotTest {
    @Test
    fun `snapshot retains player and opponent roles`() {
        val snapshot =
            RaceMinimapSnapshot(
                listOf(
                    MinimapParticipantSnapshot(1f, 2f, 90f, MinimapParticipantRole.PLAYER),
                    MinimapParticipantSnapshot(3f, 4f, 0f, MinimapParticipantRole.OPPONENT),
                    MinimapParticipantSnapshot(5f, 6f, 0f, MinimapParticipantRole.OPPONENT),
                ),
            )

        assertEquals(3, snapshot.participants.size)
        assertEquals(1, snapshot.participants.count { it.role == MinimapParticipantRole.PLAYER })
        assertEquals(2, snapshot.participants.count { it.role == MinimapParticipantRole.OPPONENT })
    }
}
