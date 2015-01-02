local wibox = require("wibox")
local awful = require("awful")

local inspect = require("inspect")

-- function aliases
local pread = awful.util.pread

-- command to get partition size, used, avail, and use%
--cmd_template = "df -h %s | tail -n 1 | awk '{print $2, $3, $4, $5}'"
cmd_template = "df -h %s | tail -n %s | awk '{print $6, $2, $3, $4, $5}'"

local DiskUsage = {}
DiskUsage.__index = DiskUsage

--- Create a DiskUsage widget.
-- @param icon Icon to use.
-- @param mounts An array of mount points to monitor or an array of mount point/label pairs.
--               If just an array of mount points the mount points themselves will be used
--               as the label. The order in which mount points are supplied is the order in
--               which they're displayed.
-- @usage local du = diskusage(beautiful.du_icon, {"/home", "/var"})
-- @usage local du = diskusage(
--                     beautiful.du_icon, 
--                     {{mount = "/home", label = "Home"}, {mount = "/var", label = "Var"}}
--                   )
function DiskUsage.new(icon, mounts)
  local self = setmetatable({}, DiskUsage)
  self.mounts = mounts

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
    if i == 1 then
      self._widgets.headers = {}
      local mount_point = wibox.widget.textbox()
      mount_point:set_markup("<b>Mount point</b>")
      self._widgets.headers.mount_point = mount_point
      local size = wibox.widget.textbox()
      size:set_markup("<b>Size</b>")
      self._widgets.headers.size = size
      local avail = wibox.widget.textbox()
      avail:set_markup("<b>Avail</b>")
      self._widgets.headers.avail = avail
      local used = wibox.widget.textbox()
      used:set_markup("<b>Used</b>")
      self._widgets.headers.used = used
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
    self._cmd_mounts[#self._cmd_mounts+1] = mount

    self._widgets[i] = {}
    -- create a progressbar for a visual representation of disk usage
    self._widgets[i].progressbar = awful.widget.progressbar({height = 12})
    -- TODO: set progressbar dimensions and colors
    awful.widget.progressbar.set_border_color(self._widgets[i].progressbar, "#afd700")
    awful.widget.progressbar.set_color(self._widgets[i].progressbar, "#d509b5")
    -- create a textbox to hold the mount's label
    self._widgets[i].label = wibox.widget.textbox()
    self._widgets[i].label:set_markup(label)
    -- create a textbox to hold the mount's max capacity
    self._widgets[i].max_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's used space
    self._widgets[i].used_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's available space
    self._widgets[i].avail_space = wibox.widget.textbox()
    -- create a textbox to hold the mount's used percent
    self._widgets[i].percent = wibox.widget.textbox()
  end

  -- now that all the widgets have been created calculate the size the wibox needs
  -- to be to house it all and then create it
  self._window = wibox({ ontop = true, width = 400, height = 300 })
  -- create the layout the wibox will use as its widget
  self._layout = wibox.layout.fixed.vertical()
  local margin = wibox.layout.margin()
  margin:set_widget(self._layout)
  margin:set_margins(10)
  -- TODO: set layout's dimensions
  self._window:set_widget(margin)

  for i, _ in ipairs(self.mounts) do
    -- get our headers added
    if i == 1 then
      local headers_container = wibox.layout.fixed.vertical()      
      local headers = wibox.layout.flex.horizontal()
      headers:add(self._widgets.headers.mount_point)
      headers:add(self._widgets.headers.avail)
      headers:add(self._widgets.headers.size)
      headers:add(self._widgets.headers.used)
      headers_container:add(headers)
      local margin = wibox.layout.margin()
      margin:set_widget(headers_container)
      margin:set_bottom(5)
      self._layout:add(margin)
    end

    local container = wibox.layout.fixed.vertical()
    local row1 = wibox.layout.flex.horizontal()
    local row2 = wibox.layout.flex.horizontal()
    row1:add(self._widgets[i].label)
    row1:add(self._widgets[i].avail_space)
    row1:add(self._widgets[i].max_space)
    row1:add(self._widgets[i].used_space)
    row2:add(self._widgets[i].progressbar)
    container:add(row1)
    local row2_margin = wibox.layout.margin()
    row2_margin:set_widget(row2)
    row2_margin:set_top(3)
    container:add(row2_margin)
    local container_margin = wibox.layout.margin()
    container_margin:set_widget(container)
    container_margin:set_bottom(7)
    self._layout:add(container_margin)
  end
  
  -- command to actually run when updating stats
  self._cmd = string.format(cmd_template, table.concat(self._cmd_mounts, " "), #self._cmd_mounts)

  -- return the actual widget (in this case the imagebox) but use the DiskUsage instance
  -- for unknown sets and gets
  return setmetatable(widget, {__index = self, __newindex = self})
end

--- Set the mouse and/or button bindings for the widget.
-- If this is not explicitly called a default is used, left-clicking the
-- widget shows/hides the disk usage stats.
function DiskUsage:buttons(keys)
  self.widget:buttons(keys)
end

--- Shows the widget if it is hidden, or hides it if it is shown.
-- In addition to hiding/showing the widget this will update the
-- current stats for each monitored mount point.
function DiskUsage:toggle()
  -- simply hide the window if it is currently visible
  if self._window.visible then
    self._window.visible = false
    return
  end

  -- need to show window after updating all the mount stats
  self:refresh()
  -- calculate the coords for our wibox
  local workarea = screen[mouse.screen].workarea
  local mouse_coords = mouse.coords()

  -- find out if our icon was clicked towards the top of the screen or the bottom
  if mouse_coords.y < workarea.height / 2 then
    -- we're at the top of the screen so we can just set the y coord to the workarea's y
    self._window.y = workarea.y
  else
    -- we're at the bottom of the screen, ensure we don't bleed over below the workarea
    local window_y = workarea.height
    if window_y + self._window.height > workarea.height then
      window_y = workarea.height - self._window.height + workarea.y
    end
    self._window.y = window_y
  end

  -- now find out if we're on the left or right side of the screen
  if mouse_coords.x < workarea.width / 2 then
    -- left side, we can just set the x coord to the workarea's x
    self._window.x = workarea.x
  else
    -- right side, need to adjust x pos so we don't bleed over
    local window_x = mouse_coords.x
    if window_x + self._window.width > workarea.width then
      window_x = window_x - (window_x + self._window.width - workarea.width)
    end
    self._window.x = window_x
  end
  self._window.visible = not self._window.visible
end

--- Refreshes the stats of all mount points and updates their corresponding widgets.
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
