--- DiskUsage gizmo.
-- Displays an icon that when clicked shows a floating wibox populated with a 
-- configurable set of mount points and their usage stats. The icon itself is
-- a `wibox.widget` so all the standard functions are available.
-- @module giblets.gizmos.diskusagenew
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local widgets = require("giblets.widgets")

local capi = {
  screen = screen,
  mouse = mouse,
}

-- function aliases
local pread = awful.util.pread

-- command to get partition size, used, avail, and use%
local cmd_template = "df -h %s | tail -n %s | awk '{print $6, $2, $3, $4, $5}'"

-- regex for parsing the output returned from the `df` command
local re_df = " ([0-9.]+%u*) ([0-9.]+%u*) ([0-9.]+%u*) ([0-9.]+)%%"

local function create_widgets(du)
  local main_layout = wibox.layout.fixed.vertical()
  local window_margin = wibox.layout.margin()
  window_margin:set_widget(main_layout)
  -- TODO: make configurable
  local margins = 4
  window_margin:set_margins(margins)
  du.window:set_widget(window_margin)

  for _, v in ipairs(du.mounts) do
    local widget_group = {}
    local stats = wibox.widget.textbox()
    stats:set_align("center")
    local progressbar = du.opts.progressbar()
    progressbar:set_width(du.opts.width - margins * 2)

    local mountpoint_container = wibox.layout.fixed.vertical()
    -- layout that will hold the text output from the `df` command
    local row1 = wibox.layout.flex.horizontal()
    row1:add(stats)
    -- layout that will hold the progressbar
    local row2 = wibox.layout.flex.horizontal()
    row2:add(progressbar)

    mountpoint_container:add(row1)
    mountpoint_container:add(row2)

    main_layout:add(mountpoint_container)

    widget_group.stats = stats
    widget_group.progressbar = progressbar
    du.widgets[v.mount] = widget_group
  end
end

local DiskUsage = {}
DiskUsage.__index = DiskUsage

--- DiskUsage options.
-- @int[opt=400] width Width of the diskusage window.
-- @tparam[opt=giblets.widgets.progressbar] progressbar The constructor for a progressbar widget
--   supporting the functions provided by `awful.widget.progressbar`. This is used to represent
--   the use % of the mount point.
-- @int[opt=0] border_width Sets the border width of the diskusage window.
-- @string[opt="#000000"] border_color Sets the color of the diskusage window border.
-- @string[opt] background_color Sets the background color of the diskusage window.
-- @string[opt] foreground_color Sets the foreground color of the diskusage window.
-- @string[opt="$1 -- $4 free of $2, $3 used"] stats_format Sets the format of the 
--   stats text display. The available replacement tokens and their corresponding
--   stat is as follows:
--     * `$1` - Mount point (or label if a label was specified
--     * `$2` - Total size of the mount point
--     * `$3` - Used amount of the mount point
--     * `$4` - Available space remaining on the mount point
-- @table opts

--- Create a new diskusage gizmo.
-- @tparam ?string|cairoimage icon Either the path to an image file or a cairo image surface.
-- @tparam table mounts A table of tables containing the keys `mount` and `label`, with
--   `label` being optional. If no `label` is supplied the mount point itself will be
--   used. For instance, 
--   `{{mount = "/home/me", label = "home"}, {mount = "/var", label = "var"}}`.
-- @tparam[opt] table opts Options for controlling the look of the diskusage gizmo. For a break 
--   down of all available options and their default values see @{opts}. There are 
--   corresponding methods for each option, if you'd rather use those.
-- @treturn DiskUsage A new DiskUsage instance.
-- @raise 'mounts' argument must be a table
-- @raise Invalid 'mounts' argument supplied
-- @raise Not a progressbar constructor
-- @see diskusage.lua
-- @usage local giblets = require("giblets")
--local du = giblets.gizmos.diskusage(
--  beautiful.du_icon, 
--  {{mount = "/home", label = "home"}, {mount = "/var", label = "var"}}
-- )
function DiskUsage.new(icon, mounts, opts)
  if type(mounts) ~= "table" then
    error("'mounts' argument must be a table")
  end
  -- sanity check the mounts table
  for _, v in ipairs(mounts) do
    if not v.mount then  -- 'label' is optional
      error("Invalid 'mounts' argument supplied")
    end
  end

  local self = setmetatable({}, DiskUsage)
  self.mounts = mounts
  self.widget = wibox.widget.imagebox()
  self.widget:set_image(icon)

  -- get all the options set
  opts = opts or {}
  self.opts = {}

  self:set_progressbar(opts.progressbar)

  -- now create the wibox window and populate it with widgets
  self.window = wibox({
    ontop = true,
    height = 400,
  })
  self.opts.height = 400
  self.window.visible = false
  self:set_width(opts.width)
  self:set_border_width(opts.border_width)
  self:set_border_color(opts.border_color)
  self:set_background_color(opts.background_color)
  self:set_foreground_color(opts.foreground_color)
  self:set_stats_format(opts.stats_format)

  self._window_pos = nil

  -- add signals to the widget
  self.widget:add_signal("property::progressbar")
  self.widget:add_signal("property::border_width")
  self.widget:add_signal("property::border_color")
  self.widget:add_signal("property::background_color")
  self.widget:add_signal("property::foreground_color")
  self.widget:add_signal("property::stats_format")
  self.widget:add_signal("property::width")
  self.widget:add_signal("property::visible")
  
  local defaultkeys = awful.button({}, 1, function() self:toggle() end)
  self.widget:buttons(defaultkeys)

  -- actual command to run when updating stats
  local mount_points = {}
  for _, v in ipairs(self.mounts) do
    mount_points[#mount_points+1] = v.mount
  end
  self._cmd = string.format(cmd_template, table.concat(mount_points, " "), #mount_points)

  -- now get all the widgets created and added to the window
  self.widgets = {}
  create_widgets(self)

  return setmetatable(self.widget, {__index = self, __newindex = self})
end

--- Set the type of progressbar that gets used for representing the use % of the mount point.
-- Remember this must be a progressbar constructor. Not an instantiated progressbar.
-- @tparam[opt=giblets.widgets.progressbar] progressbar The progressbar constructor supporting
--   all functions provided by `awful.widget.progressbar`.
-- @return The diskusage instance.
-- @raise Not a progressbar constructor
-- @signal property::progressbar
-- @usage du:set_progressbar(awful.widget.progressbar)
function DiskUsage:set_progressbar(progressbar)
  -- sanity checking
  if progressbar and type(progressbar) ~= "function" then
    error("Not a progressbar constructor")
  end

  self.opts.progressbar = progressbar or widgets.progressbar

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  self:emit_signal("property::progressbar")
  return self
end

--- Set the border width of the diskusage window.
-- @int[opt=0] width Pixel width of the border.
-- @return The diskusage instance.
-- @signal property::border_width
-- @usage du:set_border_width(2)
function DiskUsage:set_border_width(width)
  width = tonumber(width) or 0
  self.opts.border_width = width
  self.window.border_width = width

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  self:emit_signal("property::border_width")
  return self
end

--- Set the border color of the diskusage window.
-- @string[opt="#000000"] color Color of the border.
-- @return The diskusage instance.
-- @signal property::border_color
-- @usage du:set_border_color("#ff0000")
function DiskUsage:set_border_color(color)
  color = color or "#000000"
  self.opts.border_color = color
  self.window.border_color = color

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  self:emit_signal("property::border_color")
  return self
end

--- Set the background color of the diskusage window.
-- Since the diskusage "window" is merely a wibox the background color will
-- default to `bg_normal` if set in your theme file.
-- @string color Background color of the diskusage window.
-- @return The diskusage instance.
-- @signal property::background_color
-- @usage du:set_background_color("#222222")
function DiskUsage:set_background_color(color)
  color = color or beautiful.bg_normal
  self.opts.background_color = color
  self.window:set_bg(color)

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return 
  end

  self:emit_signal("property::background_color")
  return self
end

--- Set the foreground color of the diskusage window.
-- Since the diskusage "window" is merely a wibox the foreground color will
-- default to `fg_normal` if set in your theme file.
-- @string color Foreground color of the diskusage window.
-- @return The diskusage instance.
-- @signal property::foreground_color
-- @usage du:set_foreground_color("ffffff")
function DiskUsage:set_foreground_color(color)
  color = color or beautiful.fg_normal
  self.opts.foreground_color = color
  self.window:set_fg(color)

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  self:emit_signal("property::foreground_color")
  return self
end

--- Set the width of the diskusage window.
-- @int[opt=400] width Pixel width of the diskusage window.
-- @return The diskusage instance.
-- @signal property::width
-- @usage du:set_width(600)
function DiskUsage:set_width(width)
  width = tonumber(width) or 400
  self.opts.width = width
  self.window.width = width

  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  for _, v in ipairs(self.mounts) do
    self.widgets[v.mount].progressbar:set_width(width)
  end

  self:emit_signal("property::width")
  return self
end

--- Set the format of the stats text display. 
-- The available replacement tokens and their corresponding stat is as follows:
--   * `$1` - Mount point (or label if a label was specified
--   * `$2` - Total size of the mount point
--   * `$3` - Used amount of the mount point
--   * `$4` - Available space remaining on the mount point
-- @string[opt="$1 -- $4 free of $2, $3 used"] format Format string.
-- @return The diskusage instance.
-- @signal property::stats_format
-- @usage du:set_stats_format("$1 - $3/$2 ($4)")
function DiskUsage:set_stats_format(format)
  format = format or "$1 -- $4 free of $2, $3 used"
  self.opts.stats_format = format
  
  if not self.emit_signal then
    -- this was called from the constructor so our signal functions don't exist yet
    return
  end

  self:emit_signal("property::stats_format")
  return self
end

local function calc_coords(width, height, border)
  local mouse_coords = capi.mouse.coords()
  local workarea = capi.screen[capi.mouse.screen].workarea
  -- set the initial coords to that of the mouse cursor's
  local x, y = mouse_coords.x, mouse_coords.y
  local width_total = width + border * 2
  local height_total = height + border * 2
  -- ensure window doesn't bleed past the screen edges
  if x < workarea.x then x = workarea.x end
  if x + width_total > workarea.x + workarea.width then
    x = workarea.x + workarea.width - width_total
  end
  if y < workarea.y then y = workarea.y end
  if y + height_total > workarea.y + workarea.height then
    y = workarea.y + workarea.height - height_total
  end

  return x, y
end

--- Show the diskusage window if it is hidden, or hide it if it is shown.
-- @return The diskusage instance.
-- @signal property::visible
-- @usage du:toggle()
function DiskUsage:toggle()
  -- just hide the window if it is already visible
  if self.window.visible then
    return self:hide()
  else
    return self:show()
  end
end

--- Show the diskusage window.
-- @return The diskusage instance.
-- @signal property::visible
-- @usage du:show()
function DiskUsage:show()
  if self.window.visible then
    return self
  end

  if not self._window_pos then
    local x, y = calc_coords(self.opts.width, self.opts.height, self.opts.border_width)
    self.window.x = x
    self.window.y = y
    self.window_pos = {x, y}
  end

  self:refresh()
  self.window.visible = true
  self:emit_signal("property::visible")
  return self
end

--- Hide the diskusage window.
-- @return The diskusage instance.
-- @signal property::visible
-- @usage du:hide()
function DiskUsage:hide()
  if self.window.visible then
    self.window.visible = false
    self:emit_signal("property::visible")
  end
  return self
end

--- Refreshes the mount point stats.
-- @return The diskusage instance.
-- @usage du:refresh()
function DiskUsage:refresh()
  local size, used, avail, use_percent
  local output = pread(self._cmd)
  for _, v in ipairs(self.mounts) do
    local found, _, size, used, avail, use_percent = output:find(v.mount .. re_df)
    if not found then
      -- invalid mount point or some such
      size, used, avail, use_percent = "err", "err", "err", 0
    end
    use_percent = tonumber(use_percent)

    -- update the widgets
    local stats = self.opts.stats_format:gsub(
      "$1", v.label or v.mount
    ):gsub(
      "$2", size
    ):gsub(
      "$3", used
    ):gsub(
      "$4", avail
    )
    self.widgets[v.mount].stats:set_text(stats)
    self.widgets[v.mount].progressbar:set_value(use_percent / 100)
  end

  return self
end

return setmetatable(DiskUsage, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
