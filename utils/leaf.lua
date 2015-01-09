--- Leaf
-- @module giblets.utils.leaf
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local awful = require("awful")

local exec = awful.util.spawn

local capi = {
  mouse = mouse,
  client = client,
  screen = screen,
}

local Leaf = {}
Leaf.__index = Leaf

--- Leaf options
-- @string[opt="bottom"] position Position of the leaf. Can be one of "top", "bottom", 
--   "left", or "right".
-- @number[opt=0.3] height Height of the Leaf application. Can be an absolute pixel 
--   size or a percentage of the screen if between `0` and `1`.
-- @number[opt=0.5] width Width of the Leaf application. Can be an absolute pixel size 
--   or a percentage of the screen if between `0` and `1`.
-- @bool[opt=false] sticky Whether the leaf should show up on all tags or not.
-- @table opts

--- Create a new Leaf.
-- TODO: write an actual description
-- @string app Application to execute.
-- @tparam[opt] table opts Options for controlling the look and behavior of the Leaf. For a 
--   break down of all available options and their defaults see @{opts}.
-- @treturn Leaf A new Leaf instance.
-- @usage local termleaf = giblets.utils.leaf("urxvt")
-- termleaf:toggle()
-- @see leaf.lua
function Leaf.new(app, opts)
  local self = setmetatable({}, Leaf)
  self.app = app

  opts = opts or {}
  local p = opts.position
  self.opts = {
    position = (p == "top" or p == "bottom" or p == "left" or p == "right") and p or "bottom",
    height = opts.height or 0.3,
    width = opts.width or 0.5,
    sticky = opts.sticky or false,
  }

  return self
end

-- Used internally to launch the actual app.
function Leaf:_spawn()
  local pid
  local catch_app_open
  catch_app_open = function(c)
    if c.pid ~= pid then
      return
    end

    -- gotchya
    self._client = c
    capi.client.disconnect_signal("manage", catch_app_open)
    c.hidden = true
    c.ontop = true
    c.sticky = self.opts.sticky
    c.skip_taskbar = true
    awful.client.floating.set(c, true)
    awful.titlebar.hide(c)

    -- now we need to listen for the app being closed
    local catch_app_close
    catch_app_close = function(c)
      if c ~= self._client then
        -- not our app
        return
      end

      -- here be our app
      self._client = nil  -- now it can spawn again
      self._last_tag = nil
      capi.client.disconnect_signal("unmanage", catch_app_close)
    end
    capi.client.connect_signal("unmanage", catch_app_close)

    -- now that we have that all taken care of we need to call `toggle`
    -- again to get the app shown and positioned
    self:toggle()
  end

  capi.client.connect_signal("manage", catch_app_open)
  pid = exec(self.app)
end

--- Toggle the leaf.
-- Show the leaf on the active screen/tag. If it is already shown, hide it.
-- If the leaf is already visible, and this is called from a tag the leaf is
-- not currently on, will simply move the leaf to the new active tag.
-- @return The leaf instance.
-- @see leaf.lua
function Leaf:toggle()
  if not self._client then
    self:_spawn()
    return self
  end

  -- our app hasn't finished launching yet
  if not self._client then return self end

  local s = capi.mouse.screen
  local current_tag = awful.tag.selected(s)
  
  -- first time the app has been displayed, set the tag
  if not self._last_tag then self._last_tag = current_tag end

  -- our current tag didn't change so the app needs to be hidden
  if not self._client.hidden and self._last_tag == current_tag then
    self._client.hidden = true
    local tags = self._client:tags()
    for i, _ in ipairs(tags) do
      tags[i] = nil
    end
    self._client:tags(tags)
    return self
  end

  -- when the app is already being shown but a toggle happens from a different
  -- tag simply move the app to that tag
  if not self._client.hidden and self._last_tag ~= current_tag then
    awful.client.movetotag(current_tag, self._client)
    self._last_tag = current_tag
    capi.client.focus = self._client
    return self
  end

  -- client is hidden, show it and set its dimensions and position
  local workarea = capi.screen[s].workarea
  local x, y, width, height

  if self.opts.height <= 1 then height = workarea.height * self.opts.height
  else height = self.opts.height end
  if self.opts.width <= 1 then width = workarea.width * self.opts.width
  else width = self.opts.width end

  local pos = self.opts.position
  if pos == "bottom" then y = workarea.y + workarea.height - height
  elseif pos == "top" then y = workarea.y
  else y = workarea.y + (workarea.height - height) / 2 end

  if pos == "left" then x = workarea.x
  elseif pos == "right" then x = workarea.x + workarea.width - width
  else x = workarea.x + (workarea.width - width) / 2 end

  self._last_tag = current_tag
  self._client:geometry({x = x, y = y, height = height, width = width})
  awful.client.movetotag(current_tag, self._client)
  self._client.hidden = false
  self._client:raise()
  capi.client.focus = self._client
  return self
end

return setmetatable(Leaf, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
