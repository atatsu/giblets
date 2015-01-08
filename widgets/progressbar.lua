--- Progressbar widget
-- @module giblets.widgets.progressbar
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local base = require("wibox.widget.base")

local Progressbar = {}
Progressbar.__index = Progressbar

function Progressbar.new()
  local self = setmetatable({}, Progressbar)
  self.widget = base.make_widget()
  return self
end

function Progressbar:draw(wibox, cr, width, height)
end

return setmetatable(Progressbar, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
