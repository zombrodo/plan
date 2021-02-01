local Plan = require "Plan"
local Rules = Plan.Rules

local Panel = require "examples.panel"

local ui = nil

function love.load()
  ui = Plan.new()
  local rules = Rules.new()
    :addX(Plan.pixel(10))
    :addY(Plan.center())
    :addWidth(Plan.relative(0.5))
    :addHeight(Plan.aspect(1))

  local panel = Panel:new(rules, { 0.133, 0.133, 0.133 })
  ui:addChild(panel)
end

function love.update(dt)
  ui:update(dt)
end

function love.draw()
  love.graphics.push("all")
  love.graphics.clear(1, 1, 1)
  ui:draw()
  love.graphics.pop()
end

function love.resize(x, y)
  ui:refresh()
end