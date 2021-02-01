local Plan = require "plan"
local Container = Plan.Container

local Panel = Container:extend()

function Panel:new(rules, colour)
  local panel = Panel.super.new(self, rules)
  panel.colour = colour
  panel.r = 5
  return panel
end

function Panel:draw()
  love.graphics.push("all")
  love.graphics.setColor(self.colour)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, self.r, self.r)
  love.graphics.pop()
  Panel.super.draw(self)
end

return Panel