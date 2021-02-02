local Plan = require "plan"
local Rules = Plan.Rules

local Panel = require "examples.panel"

local uiRoot = nil

function love.load()
  -- Plan exposes its internal rules via functions, rather than objects for
  -- ease of use.
  local layoutRules = Rules.new()
    :addX(Plan.center())
    :addY(Plan.pixel(20))
    :addWidth(Plan.aspect(1))
    :addHeight(Plan.relative(0.33))

  local panel = Panel:new(layoutRules, { 0.133, 0.133, 0.133 })

  uiRoot = Plan.new()
  uiRoot:addChild(panel)
end

function love.update(dt)
  uiRoot:update(dt)
end

function love.draw()
  love.graphics.clear({ 0.7, 0.7, 0.7 })
  uiRoot:draw()
end

function love.resize()
  uiRoot:refresh()
end