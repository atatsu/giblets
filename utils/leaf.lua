--- Leaf
-- @module giblets.utils.leaf
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local awful = require("awful")

local exec = awful.util.spawn

local capi = {
  mouse = mouse,
  client = client
}

-- flag to prevent multiple signal manipulations
local _pre_managed = false

local Leaf = {}
Leaf.__index = Leaf

--- Leaf options
-- @string[opt="bottom"] position Position of the leaf. Can be one of "top", "bottom", 
--   "left", or "right".
-- @number[opt=0.2] height Height of the Leaf application. Can be an absolute pixel 
--   size or a percentage of the screen if between `0` and `1`.
-- @number[opt=0.2] width Width of the Leaf application. Can be an absolute pixel size 
--   or a percentage of the screen if between `0` and `1`.
-- @bool[opt=false] sticky Whether the leaf should show up on all tags or not.
-- @table opts

--- Create a new Leaf.
-- @string app Application to execute.
-- @tparam[opt] table opts Options for controlling the look and behavior of the Leaf. For a 
--   break down of all available options and their defaults see @{opts}.
-- @treturn Leaf A Leaf instance.
-- @usage local termleaf = giblets.utils.leaf("urxvt")
-- termleaf:toggle()
function Leaf.new(app, opts)
  local self = setmetatable({}, Leaf)
  self.app = app

  opts = opts or {}
  local p = opts.position
  self.opts = {
    position = (p == "top" or p == "bottom" or p == "left" or p == "right") and p or "bottom",
    height = opts.height or 0.2,
    width = opts.width or 0.2,
    sticky = opts.sticky or false,
  }

  self._app_launched = false

  return self
end

Leaf.pre_manage = function(c)
  -- fire the `leafspawn` signal in case any instances are listening
  capi.client.emit_signal("potential-leaf-spawn", c)
end

function Leaf:_spawned(c)
  self._client = c
  -- is it possible to unmanage a specific client?
  c:disconnect_signal("manage", awful.rules.apply)
  -- is it possible to listen on "unmanage" for a specific client?
  c:connect_signal("unmanage", function(c)
    self._client = nil
    self._app_launched = false
  end)

  -- now set all appropriate client properties
  awful.client.floating.set(c, true)
  c.ontop = true
  c.sticky = self.opts.sticky
  c.skip_taskbar = true
  c:raise()
  c.hidden = true

  -- since the app just spawned call `toggle` again to actually display it
  -- and set its dimensions
  self:toggle()
end

function Leaf:toggle()
  if not self._client and not self._app_launched then
    -- listen for a `potential-leaf-spawn` signal
    local check_for_app = function(c)
      if c.pid ~= self._pid then return end
      capi.client.disconnect_signal("potential-leaf-spawn", check_for_app)
      self._spawned(c)
    end
    capi.client.connect_signal("potential-leaf-spawn", check_for_app)
    self._pid = exec(app, false)
    self._app_launched = true
    return
  end

  -- our app hasn't finished launching yet
  if not self._client then return end

  if not self._client.hidden then
    self._client.hidden = true
    return
  end

  local workarea = capi.screen[capi.mouse.screen].workarea
  local x, y, width, height

  if self.opts.height <= 1 then height = workarea.height * self.opts.height
  else height = self.opts.height end
  if self.opts.width <= 1 then width = workarea.width * self.opts.width
  else width = self.opts.width end

  if self.opts.position == "bottom" then
    x = workarea.x + workarea.width - width
    y = workarea.y + workarea.height - height
  elseif self.opts.position == "top" then
    x = workarea.x + workarea.width - width
    y = workarea.y
  elseif self.opts.position == "left" then
    error("not implemented")
  elseif self.opts.position == "right" then
    error("not implemented")
  end


  self._client:geometry({x = x, y = y, height = height, width = width})
  self._client.hidden = false
  -- TODO: move to active tag
end

if not _pre_managed then
  -- TODO: investigate "new" signal, maybe this isn't necessary
  -- setup our own "manage" handler and set its order before that of the stock `awful.rules.apply` handler
  -- register our own signal that will be fired from the pre-manage function, that way we can listen
  -- if we're expecting a new leaf app to spawn
  capi.client.add_signal("potential-leaf-spawn")
  capi.client.disconnect_signal("manage", awful.rules.apply)
  capi.client.connect_signal("manage", Leaf.pre_manage)
  capi.client.connect_signal("manage", awful.rules.apply)

  _pre_managed = true
end

return setmetatable(Leaf, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
