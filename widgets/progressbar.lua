--- Progressbar widget
-- @module giblets.widgets.progressbar
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local Progressbar = {}
Progressbar.__index = Progressbar

function Progressbar.new()
  local self = setmetatable({}, Progressbar)
  return self
end

return setmetatable(Progressbar, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
