package io.github.naclador89.timetrack

import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile: clock in or out with one tap (concept §6 E1). */
class QuickTileService : TileService() {
    override fun onStartListening() {
        val tile = qsTile ?: return
        val s = QuickAccess.snapshot(this)
        tile.state = if (s.clockedIn) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.icon = Icon.createWithResource(this, R.drawable.ic_quick)
        tile.label = getString(R.string.app_name)
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = s.title
        tile.updateTile()
    }

    override fun onClick() {
        // Optimistic: the Dart handler redraws the tile with the real state afterwards.
        qsTile?.let {
            it.state = if (it.state == Tile.STATE_ACTIVE) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
            it.updateTile()
        }
        QuickAccess.action(this, "toggle").send()
    }
}
