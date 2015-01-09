--- Gizmos for the awesome window manager.
-- A gizmo is essentially a collection of widgets put together to serve
-- a common purpose. For instance, an icon that when clicked displays a wibox
-- window with statistics for all configured mount points.
-- @module giblets.gizmos
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

return {
  diskusage = require("giblets.widgets.diskusage"),
}
