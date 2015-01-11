--- Progressbar widget.
-- TODO: write an actual description
-- @module giblets.widgets.progressbar
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local base = require("wibox.widget.base")
local gcolor = require("gears.color")

local Progressbar = {}
Progressbar.__index = Progressbar

--- Progressbar options.
-- @int[opt=100] width Width of the progressbar.
-- @int[opt=12] height Height of the progressbar.
-- @bool[opt=false] vertical Draw the progressbar vertically.
-- @number[opt=1] max_value Maximum value the progressbar should support.
-- @string[opt="#8585ac"] foreground_color Foreground color of the progressbar. Or in other 
--   words, the filled color of ticks.
-- @string[opt="#484874"] background_color Background color of the progressbar. Or in other 
--   words, the empty color of ticks.
-- @string[opt="#8585ac"] border_color Border color (if `border_width` is non-zero) of the
--   progressbar. Again, affects the border surrounding each tick.
-- @int[opt=1] border_width Pixel width of the border surrounding each tick. 
-- @int[opt=3] ticks_gap Spacing between each tick.
-- @tparam[opt=8] ?int|table ticks_size Size of each tick. Can be a number 
--   representing both width and height or a table with separate width and height 
--   dimentions with the keys `width` and `height` (`{width = 10, height = 5}`).
-- @string[opt="center"] ticks_align Set the alignment of the ticks. Can be one of
--   `center`, `top`, `bottom`.
-- @table opts


--- Create a new progressbar widget.
-- This progressbar is very similar to the one you get with `awful.widget.progressbar`, 
-- except that it is always drawn with segments, or ticks. In addition, rather than being
-- drawn with a solid border and ticks inside the border, each tick is drawn as
-- though it is its own entity. So if a border is used, all four sides of each tick
-- will have a border.
--
-- All the functions implemented by `awful.widget.progressbar` are also implemented
-- here. So a `giblets.widgets.progressbar` can be a drop-in replacement for any
-- `awful.widget.progressbar`'s that are in use. Keep in mind though that 
-- `giblets.widgets.progressbar` does have additional functions so the reverse isn't
-- true.
--
-- @tparam[opt] table opts Options for controlling the dimensions and look of
--   the progressbar. For a break down of all available options and their default
--   values see @{opts}.
-- @treturn Progressbar A new Progressbar instance.
-- @usage local giblets = require("giblets")
--local pbar = giblets.widgets.progressbar()
-- @see progressbar.lua
function Progressbar.new(opts)
  local self = setmetatable({}, Progressbar)
  self.widget = base.make_widget()

  do
    local opts = opts or {}
    local ticks_size = {}
    if type(opts.ticks_size) == "table" then
      ticks_size.width = tonumber(opts.ticks_size.width) or 8
      ticks_size.height = tonumber(opts.ticks_size.height) or 8
    else
      ticks_size.width = tonumber(opts.ticks_size) or 8
      ticks_size.height = tonumber(opts.ticks_size) or 8
    end
    local align = opts.ticks_align
    self.opts = {
      vertical = opts.vertical or false,
      max_value = tonumber(opts.max_value) or 1,
      foreground_color = opts.foreground_color or "#8585ac",
      background_color = opts.background_color or "#484874",
      border_color = opts.border_color or "#8585ac",
      border_width = tonumber(opts.border_width) or 1,
      tick_height = ticks_size.height,
      tick_width = ticks_size.width,
      spacing = tonumber(opts.ticks_gap) or 3,
      ticks_align = (align == "top" or align == "bottom" or align == "center") and align or "center",
    }
    self.width = tonumber(opts.width) or 100
    self.height = tonumber(opts.height) or 12
  end

  self.value = 0
  
  -- figure out how many ticks we'll need to draw
  do
    local x = 0
    local num_segments = 0
    while x <= self.width and self.width - x > self.opts.tick_width + self.opts.spacing do
      x = x + self.opts.tick_width + self.opts.spacing
      num_segments = num_segments + 1
    end
    self._num_segments = num_segments
  end

  -- helper for getting the appropriate y coord based on the alignment value of
  -- `opts.ticks_align`
  self._y_align = {
    center = function()
      return self.height / 2 - self.opts.tick_height / 2
    end,
    top = function()
      return 0
    end,
    bottom = function()
      return self.height - self.opts.tick_height
    end,
  }

  -- return the actual widget, but use the Progressbar instance for unknown sets and gets
  return setmetatable(self.widget, {__index = self, __newindex = self})
end

function Progressbar:draw(wibox, cr, width, height)
  local x, y = 0, 0
  local border_width = self.opts.border_width

  -- first draw a filled space so that the specified size is taken up, fill will be transparent
  cr:rectangle(x, y, self.width, self.height)
  cr:set_source(gcolor("#00000000"))
  cr:fill()

  -- need to determine how many segments should be filled
  local filled = math.ceil(self._num_segments * self.value)

  -- now determine where the y coord needs to be based on whether the alignment is
  -- center, top, or bottom
  local align = self._y_align[self.opts.ticks_align]

  y = align()
  for i = 1, self._num_segments do
    local width, height = self.opts.tick_width, self.opts.tick_height
    -- draw border if border width is a non-zero value
    if self.opts.border_width then
      cr:set_line_width(border_width)
      -- there needs to be room for the stroke path, so pull in the x and y coords by
      -- half the border_width value, then pull in the outer edges by the border_width
      local tuck = border_width / 2
      cr:rectangle(x + tuck, y + tuck, width - border_width, height - border_width)
      cr:set_source(gcolor(self.opts.border_color))
      cr:stroke()
      x = x + border_width
      y = y + border_width
      width = width - border_width * 2  -- need to account for the border on both sides!
      height = height - border_width * 2  -- need to account for the border on both sides!
    end

    cr:rectangle(x, y, width, height)
    local fill_color
    if i > filled then fill_color = self.opts.background_color
    else fill_color = self.opts.foreground_color end
    cr:set_source(gcolor(fill_color))
    cr:fill()

    x = x + width + self.opts.spacing + border_width
    y = align()
  end
end

function Progressbar:fit(width, height)
  return self.width, self.height
end

--- Set the value of the progressbar.
--
-- **Emits:** `widget::updated`
-- @number[opt=0] value The value between `0` and `1`.
-- @return The progressbar instance.
-- @usage pbar:set_value(0.4)
function Progressbar:set_value(value)
  local value = tonumber(value) or 0
  self.value = math.min(1, math.max(0, value))
  self:emit_signal("widget::updated")
  return self
end

--- Sets the width of the progressbar.
--
-- **Emits:** `widget::updated`
-- @int[opt=100] width Width of the progressbar.
-- @return The progressbar instance.
-- @usage pbar:set_width(100)
function Progressbar:set_width(width)
  self.width = tonumber(width) or 100
  self:emit_signal("widget::updated")
  return self
end

--- Sets the height of the progressbar.
--
-- **Emits:** `widget::updated`
-- @int[opt=12] height Height of the progressbar.
-- @return The progressbar instance.
-- @usage pbar:set_height(12)
function Progressbar:set_height(height)
  self.height = tonumber(height) or 12
  self:emit_signal("widget::updated")
  return self
end

--- Set the progressbar's border color.
-- Remember this only has an effect if `border_width` is non-zero.
--
-- **Emits:** `widget::updated`
-- @string[opt="#8585ac"] color Color of the border.
-- @return The progressbar instance.
-- @usage pbar:set_border_color("#8585ac")
function Progressbar:set_border_color(color)
  self.opts.border_color = color or self.opts.border_color
  self:emit_signal("widget::updated")
  return self
end

--- Set the foreground color of the progressbar.
-- In other words, the filled color of segments.
--
-- **Emits:** `widget::updated`
-- @string[opt="#8585ac"] color Foreground color.
-- @return The progressbar instance.
-- @usage pbar:set_color("#8585ac")
function Progressbar:set_color(color)
  self.opts.foreground_color = color or self.opts.foreground_color
  self:emit_signal("widget::updated")
  return self
end

--- Set the background color of the progressbar.
-- Or in other words, the empty color of segments.
--
-- **Emits:** `widget::updated`
-- @string[opt="#484874"] color Background color.
-- @return The progressbar instance.
-- @usage pbar:set_background_color("#484874")
function Progressbar:set_background_color(color)
  self.opts.background_color = color or self.opts.background_color
  self:emit_signal("widget::updated")
  return self
end

--- Instructs the progressbar to be drawn vertically.
--
-- **Emits:** `widget::updated`
-- @bool[opt=false] vertical Draw vertical or not.
-- @return The progressbar instance.
-- @usage pbar:set_vertical(true)
function Progressbar:set_vertical(vertical)
  self.vertical = vertical or false
  self:emit_signal("widget::updated")
  return self
end

--- Sets the maximum value the progressbar can handle.
--
-- **Emits:** `widget::updated`
-- @number[opt=1] value Max value of the progressbar.
-- @return The progressbar instance.
-- @usage pbar:set_max_value(2)
function Progressbar:set_max_value(value)
  self.opts.max_value = tonumber(value) or 1
  self:emit_signal("widget::updated")
  return self
end

--- Set the progressbar to draw ticks (**non-functional**).
-- This function doesn't do anything. It merely exists for compatibility with
-- `awful.widget.progressbar`. A giblets' progressbar is always drawn with
-- ticks, therefor they are not optional and cannot be turned off.
-- @bool[opt=true] ticks This will **always** be `true`.
-- @return The progressbar instance.
function Progressbar:set_ticks(ticks)
  self:emit_signal("widget::updated")
  return self
end

--- Set the spacing between each segment (tick).
--
-- **Emits:** `widget::updated`
-- @int[opt=3] gap Pixel space between each segment (tick).
-- @return The progressbar instance.
-- @return widget::updated
-- @usage pbar:set_ticks_gap(3)
function Progressbar:set_ticks_gap(gap)
  self.opts.spacing = tonumber(gap) or 3
  self:emit_signal("widget::updated")
  return self
end

--- Set the segment (tick) size of the progressbar.
-- Can be a number representing both width and height or a table with separate width
-- and height dimentions with the keys `width` and `height` (`{width = 10, height = 5}`).
--
-- **Emits:** `widget::updated`
-- @tparam[opt=8] ?int|table size Size of each segment (tick).
-- @return The progressbar instance.
-- @usage pbar:set_ticks_size(8)
-- @usage pbar:set_ticks_size({width = 10, height = 5})
function Progressbar:set_ticks_size(size)
  local _size = {}
  if type(size) == "table" then
    _size.width = tonumber(size.width) or 8
    _size.height = tonumber(size.height) or 8
  else
    _size.width = tonumber(size) or 8
    _size.height = tonumber(size) or 8
  end
  self.opts.tick_height = _size.height
  self.opts.tick_width = _size.width
  self:emit_signal("widget::updated")
  return self
end

return setmetatable(Progressbar, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
