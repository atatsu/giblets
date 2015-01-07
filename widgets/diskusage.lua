--- DiskUsage widget
-- @module giblets.widgets.diskusage
-- @author Nathan Lundquist (atatsu)
-- @copyright 2015 Nathan Lundquist

local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")

local capi = {
  screen = screen,
  mouse = mouse,
}

-- function aliases
local pread = awful.util.pread

-- command to get partition size, used, avail, and use%
cmd_template = "df -h %s | tail -n %s | awk '{print $6, $2, $3, $4, $5}'"

local DiskUsage = {}
DiskUsage.__index = DiskUsage

--- Default header labels
-- @table default_header_labels
local default_header_labels = {
  mount_point = "<b>Mount point</b>", -- &lt;b&gt;Mount point&lt;/b&gt;
  size = "<b>Size</b>", -- &lt;b&gt;Size&lt;/b&gt;
  avail = "<b>Avail</b>", -- &lt;b&gt;Avail&lt;/b&gt;
  used = "<b>Used</b>" -- &lt;b&gt;Used&lt;/b&gt;
}

--- DiskUsage options
-- @bool[opt=true] enable_header Display column headers.
-- @tparam table header_labels A table of header labels used for columns if they're 
--   enabled. Pango markup is supported. See the @{default_header_labels} for structure
--   and defaults.
-- @int[opt=400] window_width `theme.giblets.diskusage.window_width`
--
--   Controls the width of the DiskUsage widget window.
-- @tparam[opt=10] ?int|table window_margins `theme.giblets.diskusage.window_margins`
--
--   Margins for the DiskUsage widget outer window.
--   Can be a single number representing all margins or a table specifying
--   each margin. If a table of individual margins, valid keys are:
--     * top
--     * bottom
--     * left
--     * right
--  For example: `{top = 10, right = 5, bottom = 10, left = 5}`
--
--  *Note*: If any keys are specified, those left unspecified are assumed
--  to have a value of `0`.
-- @int[opt=1] window_border_width `theme.giblets.diskusage.window_border_width`
--
--   Sets the width of the border surrounding the DiskUsage window.
-- @string[opt="#000000"] window_border_color `theme.giblets.diskusage.window_border_color`
--   Sets the color of the border surrounding the DiskUsage window.
-- @tparam[opt={bottom = 5}] ?int|table header_margins `theme.giblets.diskusage.header_margins`
--
--   Margins surrounding the headers row. Can be a single number representing
--   all margins or a table specifying each margin. If a table of individual
--   margins, valid keys are:
--     * top
--     * bottom
--     * left
--     * right
--   For example: `{top = 10, right = 5, bottom = 10, left = 5}`
--
--   *Note*: If any keys are specified, those left unspecified are assumed
--   to have a value of `0`.
-- @int[opt=12] progressbar_height `theme.giblets.diskusage.progressbar_height`
--
--   Controls the height of the progressbar that is used to represent the % used
--   of the mount point.
-- @tparam[opt={top = 3}] ?int|table progressbar_margins `theme.giblets.diskusage.progressbar_margins`
--
--   Sets the margins surrounding the progressbar. Can be a single number representing all
--   margins or a table specifying each margin. If a table of individual margins, valid
--   keys are:
--     * top
--     * bottom
--     * left
--     * right
--   For example: `{top = 10, right = 5, bottom = 10, left = 5}`
--
--   *Note*: If any keys are specified, those left unspecified are assumed to have
--   a value of `0`.
-- @string[opt="#d509b5"] progressbar_color `theme.giblets.diskusage.progressbar_color`
--
--   Sets the color of the progressbar.
-- @string[opt="#afd700"] progressbar_border_color `theme.giblets.diskusage.progressbar_border_color`
--
--   Sets the color of the progressbar border.
-- @tparam[opt={bottom = 7}] ?int|table mp_container_margins `theme.giblets.diskusage.mp_container_margins`
--
--   Sets the margins surrounding each mount point container (the container encompasses all
--   the sub-widgets specific to a mount point, so the mount label text, size text, used text,
--   avail text, and progressbar). Can be a single number representing all margins or a table
--   specifying each margin. If a table of individual margins, valid keys are:
--     * top
--     * bottom
--     * left
--     * right
--   For example: `{top = 10, right = 5, bottom = 10, left = 5}`
--
--   *Note*: If any keys are specified, those left unspecified are assumed to have
--   a value of `0`.
-- @table opts
  

--- Create a DiskUsage widget.
-- @string icon Icon to use.
-- @tparam table mounts An array of mount points to monitor or an array of mount point/label pairs.
--   If just an array of mount points the mount points themselves will be used as the label. 
--   The order in which mount points are supplied is the order in which they're displayed.
-- @tparam[opt] table opts Options for controlling the look and feel of the DiskUsage widget. 
--   Configuration as well as styling options can be supplied here. Any styling options specified
--   here override theme settings. For a break down of all available options as well as their
--   theme counterparts see @{opts}.
-- @treturn DiskUsage A DiskUsage instance.
-- @usage local du = giblets.widgets.diskusage(beautiful.du_icon, {"/home", "/var"})
-- @usage local du = giblets.widgets.diskusage(
--   beautiful.du_icon, 
--   {{mount = "/home", label = "Home"}, {mount = "/var", label = "Var"}}
-- )
-- @see diskusage.lua
function DiskUsage.new(icon, mounts, opts)
  local self = setmetatable({}, DiskUsage)
  self.mounts = mounts
  local font_size = 0

  -- collect all the options we'll be using
  do
    local theme = beautiful.get()
    local du_theme = theme.giblets and theme.giblets.diskusage or {}
    local found, _, size = theme.font:find("^.+ ([0-9]*)$")
    if found then
      font_size = tonumber(size)
    else
      -- TODO: find out the actual default font size
      font_size = 14
    end

    opts = opts or {}
    local header_labels = opts.header_labels or {}
    self.options = {
      -- configuration options
      enable_header = opts.enable_header or true,
      header_labels = {
        mount_point = header_labels.mount_point or default_header_labels.mount_point,
        size = header_labels.size or default_header_labels.size,
        avail = header_labels.avail or default_header_labels.avail,
        used = header_labels.used or default_header_labels.used,
      },
      -- styling options
      window_width = opts.window_width or du_theme.window_width or 400,
      window_margins = opts.window_margins or du_theme.window_margins or 10,
      window_border_width = opts.window_border_width or du_theme.window_border_width or 1,
      window_border_color = opts.window_border_color or du_theme.window_border_color or "#000000",
      header_margins = opts.header_margins or du_theme.header_margins or {bottom = 5},
      progressbar_height = opts.progressbar_height or du_theme.progressbar_height or 12,
      progressbar_margins = opts.progressbar_margins or du_theme.progressbar_margins or {top = 3},
      progressbar_color = opts.progressbar_color or du_theme.progressbar_color or "#d509b5",
      progressbar_border_color = opts.progressbar_border_color or 
        du_theme.progressbar_border_color or "#afd700",
      mp_container_margins = opts.mp_container_margins or 
        du_theme.mp_container_margins or {bottom = 7},
    }
  end

  -- setup our actual widget
  local widget = wibox.widget.imagebox()
  widget:set_image(icon)
  self.widget = widget

  -- set some default key bindings
  -- left-click, show mount points and their usage stats
  local defaultkeys = awful.button({}, 1, function() self:toggle() end)
  self:buttons(defaultkeys)

  self._cmd_mounts = {}
  -- create all of our widgets, each collection is a table of parts corresponding
  -- to each mount point and each of them to the main layout
  self._widgets = {}
  for i, mount_opt in ipairs(self.mounts) do
    -- set some widgets up for our headers
    if i == 1 and self.options.enable_header then
      local labels = self.options.header_labels
      local headers = {}

      local mount_point = wibox.widget.textbox()
      mount_point:set_markup(labels.mount_point)
      headers.mount_point = mount_point

      local size = wibox.widget.textbox()
      size:set_markup(labels.size)
      headers.size = size

      local avail = wibox.widget.textbox()
      avail:set_markup(labels.avail)
      headers.avail = avail

      local used = wibox.widget.textbox()
      used:set_markup(labels.used)
      headers.used = used

      self._widgets.headers = headers
    end

    local mount_opt = self.mounts[i]
    local mount, label

    if type(mount_opt) == "table" then
      mount = mount_opt.mount
      label = mount_opt.label
    else
      mount = mount_opt
      label = "<b>" .. mount_opt .. "</b>"
    end
    -- store just the mount points themselves in this table so they're
    -- easier to work with when running the `df` command
    self._cmd_mounts[#self._cmd_mounts+1] = mount

    local w = {}
    -- create a progressbar for a visual representation of disk usage
    w.progressbar = awful.widget.progressbar({height = self.options.progressbar_height})
    awful.widget.progressbar.set_border_color(w.progressbar, self.options.progressbar_border_color)
    awful.widget.progressbar.set_color(w.progressbar, self.options.progressbar_color)
    -- create a textbox to hold the mount's label
    w.label = wibox.widget.textbox()
    w.label:set_markup(label)
    -- create a textbox to hold the mount's max capacity
    w.max_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's used space
    w.used_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's available space
    w.avail_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's used percent
    w.percent = wibox.widget.textbox()

    self._widgets[i] = w
  end

  -- now that all the widgets have been created calculate the size the wibox needs
  -- to be to house it all and then create it
  do
    -- find out how much space each collection of widgets for each mount point takes up
    local height = 0

    -- account for the top and bottom margins of widget window
    if type(self.options.window_margins) == "table" then
      height = height + (self.options.window_margins.top or 0)
      height = height + (self.options.window_margins.bottom or 0)
    else
      height = height + self.options.window_margins * 2
    end

    -- account for header text if they are enabled
    if self.options.enable_header then
      height = height + font_size
    end

    -- account for header margins if they are enabled
    if self.options.enable_header then
      if type(self.options.header_margins) == "table" then
        height = height + (self.options.header_margins.top or 0)
        height = height + (self.options.header_margins.bottom or 0)
      else
        height = height + self.options.header_margins * 2
      end
    end

    -- account for the progressbar height and margins for each mount point
    height = height + self.options.progressbar_height * #self.mounts
    if type(self.options.progressbar_margins) == "table" then
      height = height + (self.options.progressbar_margins.top or 0) * #self.mounts
      height = height + (self.options.progressbar_margins.bottom or 0) * #self.mounts
    else
      height = height + self.options.progressbar_margins * 2 * #self.mounts
    end

    -- account for the container margins for each mount point
    if type(self.options.mp_container_margins) == "table" then
      height = height + (self.options.mp_container_margins.top or 0) * #self.mounts
      height = height + (self.options.mp_container_margins.bottom or 0) * #self.mounts
    else
      height = height + self.options.mp_container_margins * 2 * #self.mounts
    end

    -- account for the text row in each widget container for each mount point
    -- FIXME: not sure yet if something is unaccounted for or what but without the 
    -- magical +3 there isn't enough room to display everything
    height = height + (font_size + 3) * #self.mounts

    -- now create the widget window and set dimensions
    self._window = wibox({ 
      ontop = true, 
      width = self.options.window_width, 
      height = height,
      border_width = self.options.window_border_width,
      border_color = self.options.window_border_color,
    })
  end

  -- create the layout the wibox will use as its widget
  self._layout = wibox.layout.fixed.vertical()
  local window_margin = wibox.layout.margin()
  window_margin:set_widget(self._layout)
  -- set widget window margins
  if type(self.options.window_margins) == "table" then
    local margins = self.options.window_margins
    if margins.top then window_margin:set_top(margins.top) end
    if margins.bottom then window_margin:set_bottom(margins.bottom) end
    if margins.right then window_margin:set_right(margins.right) end
    if margins.left then window_margin:set_left(margins.left) end
  else
    window_margin:set_margins(self.options.window_margins)
  end
  self._window:set_widget(window_margin)

  for i, _ in ipairs(self.mounts) do
    -- get our headers added to the widget window if they're enabled
    if i == 1 and self.options.enable_header then
      local headers_container = wibox.layout.fixed.vertical()      
      local headers = wibox.layout.flex.horizontal()
      headers:add(self._widgets.headers.mount_point)
      headers:add(self._widgets.headers.avail)
      headers:add(self._widgets.headers.size)
      headers:add(self._widgets.headers.used)
      headers_container:add(headers)

      -- set header margins
      local header_margin = wibox.layout.margin()
      header_margin:set_widget(headers_container)
      if type(self.options.header_margins) == "table" then
        local margins = self.options.header_margins
        if margins.top then header_margin:set_top(margins.top) end
        if margins.bottom then header_margin:set_bottom(margins.bottom) end
        if margins.left then header_margin:set_left(margins.left) end
        if margins.right then header_margin:set_right(margins.right) end
      else
        header_margin:set_margins(self.options.header_margins)
      end
      self._layout:add(header_margin)
    end

    -- create a set of widgets specific to each mount point being monitored
    -- and wrap them all in a layout
    
    -- the layout object that will hold all of our mount point's widgets
    local mp_container = wibox.layout.fixed.vertical()

    -- the layout object that will hold all the text widgets for our mount point
    local row1 = wibox.layout.flex.horizontal()
    row1:add(self._widgets[i].label)
    row1:add(self._widgets[i].avail_space)
    row1:add(self._widgets[i].max_space)
    row1:add(self._widgets[i].used_space)

    -- the layout object that will hold the progressbar widget for our mount point
    local row2 = wibox.layout.flex.horizontal()
    row2:add(self._widgets[i].progressbar)
    mp_container:add(row1)

    -- set margins for the progressbar row
    local row2_margin = wibox.layout.margin()
    row2_margin:set_widget(row2)
    if type(self.options.progressbar_margins) == "table" then
      local margins = self.options.progressbar_margins
      if margins.top then row2_margin:set_top(margins.top) end
      if margins.bottom then row2_margin:set_bottom(margins.bottom) end
      if margins.left then row2_margins:set_left(margins.left) end
      if margins.right then row2_margins:set_right(margins.right) end
    else
      row2_margin:set_margins(self.options.progressbar_margins)
    end
    mp_container:add(row2_margin)

    -- set margins for the mount point's encompassing layout
    local mp_container_margin = wibox.layout.margin()
    mp_container_margin:set_widget(mp_container)
    if type(self.options.mp_container_margins) == "table" then
      local margins = self.options.mp_container_margins
      if margins.top then mp_container_margin:set_top(margins.top) end
      if margins.bottom then mp_container_margin:set_bottom(margins.bottom) end
      if margins.left then mp_container_margin:set_left(margins.left) end
      if margins.right then mp_container_margin:set_right(margins.right) end
    else
      mp_container_margin:set_margins(self.options.mp_container_margins)
    end
    self._layout:add(mp_container_margin)
  end
  
  -- command to actually run when updating stats
  self._cmd = string.format(cmd_template, table.concat(self._cmd_mounts, " "), #self._cmd_mounts)

  -- return the actual widget (in this case the imagebox) but use the DiskUsage instance
  -- for unknown sets and gets
  return setmetatable(widget, {__index = self, __newindex = self})
end

--- Set the mouse and/or button bindings for the widget.
-- If this is not explicitly called a default is used, left-clicking the
-- widget shows/hides the disk usage stats. This is called by @{new} to set up 
-- the default bindings. If you wish to override simply use it after you have
-- a DiskUsage instance.
-- @tparam table keys A table with one or several button objects (from `awful.button`).
-- @usage local du = giblets.widgets.diskusage(beautiful.du_icon, {"/home"})
-- du:buttons(
--   awful.button({}, 1, function() self:toggle() end)
-- )
function DiskUsage:buttons(keys)
  self.widget:buttons(keys)
end

--- Shows the widget if it is hidden, or hides it if it is shown.
-- In addition to hiding/showing the widget this will update the
-- current stats for each monitored mount point (by use of @{refresh}).
-- With the default keybindings this is called when the widget icon is
-- left-clicked.
function DiskUsage:toggle()
  -- simply hide the window if it is currently visible
  if self._window.visible then
    self._window.visible = false
    return
  end

  -- need to show window after updating all the mount stats
  self:refresh()
  -- calculate the coords that our window (wibox) should be displayed at
  local mouse_coords = mouse.coords()
  local workarea = capi.screen[capi.mouse.screen].workarea
  local w_width_total = self._window.width + self.options.window_border_width * 2
  local w_height_total = self._window.height + self.options.window_border_width * 2
  -- one monitor - { height = 876, width = 1440, x = 0, y = 12 }
  -- two monitors - { height = 1038, width = 1680, x = 1680, y = 12 }

  -- set the initial coords to that of the mouse cursor's
  local x, y = mouse_coords.x, mouse_coords.y

  -- now perform some checks to ensure the window isn't bleeding over the screen edge
  -- start with x
  if x < workarea.x then x = workarea.x end
  if x + w_width_total > workarea.x + workarea.width then 
    x = workarea.x + workarea.width - w_width_total
  end

  -- now handle the y coord
  if y < workarea.y then y = workarea.y end
  if y + w_height_total > workarea.y + workarea.height then
    y = workarea.y + workarea.height - w_height_total
  end

  -- and finally set the widget window coords and make it visible
  self._window.x = x
  self._window.y = y
  self._window.visible = not self._window.visible
end

--- Refreshes the stats of all mount points and updates their corresponding widgets.
-- Refresh all the mount point stats and update their corresponding widgets. This is
-- automatically called by @{toggle}.
function DiskUsage:refresh()
  local output = pread(self._cmd)
  for i, v in ipairs(self._cmd_mounts) do
    local found, _, size, used, avail, use_percent = output:find(
      v .. " ([0-9.]+%u*) ([0-9.]+%u*) ([0-9.]+%u*) ([0-9.]+)%%"
    )
    if not found then
      -- mount point wasn't found in df listing
      size = "err"
      used = "err"
      avail = "err"
      use_percent = 0
    end
    use_percent = tonumber(use_percent)

    self._widgets[i].max_space:set_text(size)
    self._widgets[i].used_space:set_text(used)
    self._widgets[i].avail_space:set_text(avail)
    self._widgets[i].progressbar:set_value(use_percent / 100)
  end
end

return setmetatable(DiskUsage, {
  __call = function(cls, ...)
    return cls.new(...)
  end
})
