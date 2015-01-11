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
-- @int[opt=8] segment_height Height of each segment. This is in effect the height
--   of the progressbar.
-- @int[opt=8] segment_width Width of each segment. While not controlling the entire
--   progressbar width, it has a direct impact on it `(num_segments x segment_width
--   + (spacing * num_segments)`).
-- @int[opt=3] spacing The pixel gap between each segment comprising the progressbar.
--   This, combined with the `num_segments` effects the progressbar length.
-- @int[opt=9] num_segments Controls the number of segments that make up the progressbar. 
--   This, combined with the `spacing` effects the progressbar length.
-- @string[opt="#8585ac"] foreground_color Foreground color of the progressbar. Or in other 
--   words, the filled color of segments.
-- @string[opt="#484874"] background_color Background color of the progressbar. Or in other 
--   words, the empty color of segments.
-- @string[opt="#8585ac"] border_color Border color (if `border_width` is non-zero) of the
--   progressbar. Again, affects the border surrounding each segment.
-- @int[opt=1] border_width Pixel width of the border surrounding each segment. Remember if
--   a `border_width` is used it is included in the `segment_height` and `segment_width`, 
--   it doesn't add to it. So if `border_width` is `2`, and `segment_width` is `8` and 
--   `segment_height` is `8`, each segment effectively has a 4x4 area of fill space 
--   (height and width have a border on both sides).
-- @table opts

--- Create a new progressbar widget.
--
-- *Note*: When determining how many segments should be filled, will round up.
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

  local opts = opts or {}
  self.opts = {
    segment_height = tonumber(opts.segment_height) or 8,
    segment_width = tonumber(opts.segment_width) or 8,
    spacing = tonumber(opts.spacing) or 3,
    num_segments = tonumber(opts.num_segments) or 9,
    foreground_color = opts.foreground_color or "#8585ac",
    background_color = opts.background_color or "#484874",
    border_color = opts.border_color or "#8585ac",
    border_width = tonumber(opts.border_width) or 1,
  }

  self.width = self.opts.segment_width * self.opts.num_segments + 
    self.opts.num_segments * self.opts.border_width +
    (self.opts.num_segments - 1) * self.opts.spacing
  self.height = self.opts.segment_height
  self.value = 0

  -- return the actual widget, but use the Progressbar instance for unknown sets and gets
  return setmetatable(self.widget, {__index = self, __newindex = self})
end

function Progressbar:draw(wibox, cr, width, height)
  local x, y = 0, 0
  local border_width = self.opts.border_width

  -- need to determine how many segments should be filled
  local filled = math.ceil(self.opts.num_segments * self.value)

  for i = 1, self.opts.num_segments do
    local width, height = self.opts.segment_width, self.opts.segment_height
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
    y = 0
  end
end

function Progressbar:fit(width, height)
  return self.width, self.height
end

--- Set the value of the progressbar.
-- @number[opt=0] value The value between `0` and `1`.
-- @return The progressbar instance.
-- @usage pbar:set_value(0.4)
function Progressbar:set_value(value)
  local value = tonumber(value) or 0
  self.value = math.min(1, math.max(0, value))
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_width(width)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_height(height)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

--- Set the progressbar's border color.
-- Remember this only has an effect if `border_width` is non-zero.
-- @string[opt="#8585ac"] color Color of the border.
-- @return The progressbar instance.
-- @usage pbar:set_border_color("#8585ac")
function Progressbar:set_border_color(color)
  self.opts.border_color = _color
  self:emit_signal("widget::updated")
  return self
end

--- Set the foreground color of the progressbar.
-- In other words, the filled color of segments.
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
-- @string[opt="#484874"] color Background color.
-- @return The progressbar instance.
-- @usage pbar:set_background_color("#484874")
function Progressbar:set_background_color(color)
  self.opts.background_color = color
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_vertical(vertical)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_max_value(max_value)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_ticks(ticks)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_ticks_gap(gap)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

function Progressbar:set_ticks_size(size)
  -- TODO
  self:emit_signal("widget::updated")
  return self
end

return setmetatable(Progressbar, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
