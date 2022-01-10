local Plan = {
  _VERSION = '0.5.0',
  _DESCRIPTION = 'Plan, a layout helper, designed for LÖVE',
  _URL = 'https://github.com/zombrodo/plan',
  _LICENSE = [[
    MIT License
    Copyright (c) 2021 Jack Robinson
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  ]]
}
Plan.__index = Plan

-- ============================================================================
-- Utils
-- ============================================================================

local function some(x)
  return x ~= nil
end

local function indexOf(coll, item)
  for i, x in ipairs(coll) do
    if x == item then
      return i
    end
  end
  return -1
end

local function contains(coll, item)
  return indexOf(coll, item) ~= -1
end

local function getRoot(container)
  local parent = container.parent
  if parent then
    while parent.parent ~= nil do
      parent = parent.parent
    end
  end
  return parent
end

local function isNumber(maybeNumber)
  return type(maybeNumber) == "number"
end

local function isValidRule(maybeRule)
  return maybeRule.realise ~= nil and type(maybeRule.realise) == "function"
end

-- ============================================================================
-- Root Object (not public)
-- ============================================================================

local Object = {}
Object.__index = Object

function Object:new()
end

function Object:extend()
  local subclass = {}
  for k, v in pairs(self) do
    if k:find("__") == 1 then
      subclass[k] = v
    end
  end
  subclass.__index = subclass
  subclass.super = self
  setmetatable(subclass, self)
  return subclass
end

-- ============================================================================
-- Container
-- ============================================================================

local Container = Object:extend()

function Container:new(rules)
  local container = setmetatable({}, self)
  container.x = 0
  container.y = 0
  container.w = 0
  container.h = 0
  container.rules = rules
  container.parent = nil
  container.children = {}
  container.isUIRoot = false
  return container
end

function Container:__isAttached()
  local root = getRoot(self)
  return root and root.isUIRoot
end

function Container:addChild(child)
  child.parent = self
  table.insert(self.children, child)
  if self.isUIRoot or self:__isAttached() then
    self:refresh()
  end
end

function Container:removeChild(child)
  local toRemove = indexOf(self.children, child)
  if some(toRemove) then
    table.remove(self.children, toRemove)
  end
end

function Container:clearChildren()
  self.children = {}
end

function Container:refresh()
  self.x, self.y, self.w, self.h = self.rules:realise(self)
  for _, child in ipairs(self.children) do
    if some(child.refresh) then
      child:refresh(self)
    end
  end
end

function Container:update(dt)
  for _, child in ipairs(self.children) do
    if some(child.update) then
      child:update(dt)
    end
  end
end

function Container:draw()
  for _, child in ipairs(self.children) do
    if some(child.draw) then
      child:draw()
    end
  end
end

function Container:emit(event, ...)
  for _, child in ipairs(self.children) do
    if some(child[event]) and type(child[event]) == "function" then
      local result = child[event](...)
      -- If we return false, then we stop passing this around.
      if result == false then
        return
      end
    end
  end
end

Plan.Container = Container

-- ============================================================================
-- Default Rules
-- ============================================================================

-- ====================================
-- Pixel Rule
-- ====================================

local PixelRule = {}
PixelRule.__index = PixelRule

function PixelRule.new(value)
  local self = setmetatable({}, PixelRule)
  self.value = value
  return self
end

function PixelRule:realise(dimension, element, rules)
  return self.value
end

function PixelRule:clone()
  return PixelRule.new(self.value)
end

function PixelRule:set(value)
  self.value = value
end

function Plan.pixel(value)
  return PixelRule.new(value)
end

-- ====================================
-- Relative Rule
-- ====================================

local RelativeRule = {}
RelativeRule.__index = RelativeRule

function RelativeRule.new(value)
  local self = setmetatable({}, RelativeRule)
  self.value = value
  return self
end

function RelativeRule:realise(dimension, element, rules)
  if dimension == "w" or dimension == "h" then
    return element.parent[dimension] * self.value
  end

  if dimension == "x" then
    return element.parent["w"] * self.value
  end

  if dimension == "y" then
    return element.parent["h"] * self.value
  end
end

function RelativeRule:clone()
  return RelativeRule.new(self.value)
end

function RelativeRule:set(value)
  self.value = value
end

function Plan.relative(value)
  return RelativeRule.new(value)
end

-- ====================================
-- Center Rule
-- ====================================

local CenterRule = {}
CenterRule.__index = CenterRule

function CenterRule.new()
  local self = setmetatable({}, CenterRule)
  return self
end

function CenterRule:realise(dimension, element, rules)
  if dimension == "w" or dimension == "h" then
    error("Center Rule doesn't work for widths or heights")
  end

  -- We know for sure that the parent has realised its position
  -- But we assume that this element hasn't worked it out yet, so we do it ahead of time.
  -- There is no checks against circular references.

  if dimension == "x" then
    return (element.parent.w / 2) - (rules.w:realise("w", element, rules) / 2)
  end

  if dimension == "y" then
    return (element.parent.h / 2) - (rules.h:realise("h", element, rules) / 2)
  end
end

function CenterRule:clone()
  return CenterRule.new()
end

function CenterRule:set()
  -- no op
end

function Plan.center()
  return CenterRule.new()
end

-- ====================================
-- Aspect Rule
-- ====================================

local AspectRule = {}
AspectRule.__index = AspectRule

function AspectRule.new(value)
  local self = setmetatable({}, AspectRule)
  self.value = value
  return self
end

function AspectRule:realise(dimension, element, rules)
  if dimension == "x" or dimension == "y" then
    error("Aspect rule doesn't work for x or y coordinates")
  end

  if dimension == "w" then
    return rules.h:realise("h", element, rules) * self.value
  end

  if dimension == "h" then
    return rules.w:realise("w", element, rules) * self.value
  end
end

function AspectRule:clone()
  return AspectRule.new(self.value)
end

function AspectRule:set(value)
  self.value = value
end

function Plan.aspect(value)
  return AspectRule.new(value)
end

-- ====================================
-- Parent Rule
-- ====================================

local ParentRule = {}
ParentRule.__index = ParentRule

function ParentRule.new()
  local self = setmetatable({}, ParentRule)
  return self
end

function ParentRule:realise(dimension, element, rules)
  return element.parent[dimension]
end

function ParentRule:clone()
  return ParentRule.new()
end

function ParentRule:set()
  -- no op
end

function Plan.parent()
  return ParentRule.new()
end

-- ====================================
-- Max Rule
-- ====================================

local MaxRule = {}
MaxRule.__index = MaxRule

function MaxRule.new(value)
  local self = setmetatable({}, MaxRule)
  self.value = value or 0
  return self
end

function MaxRule:realise(dimension, element, rules)
  if dimension == "x" then
    return element.parent.w - self.value
  end

  if dimension == "y" then
    return element.parent.h - self.value
  end

  if dimension == "w" then
    return element.parent.w - self.value
  end

  if dimension == "h" then
    return element.parent.h - self.value
  end
end

function MaxRule:set(value)
  self.value = value
end

function MaxRule:clone()
  return MaxRule.new(self.value)
end

function Plan.max(value)
  return MaxRule.new(value)
end

-- ============================================================================
-- Rules Builder
-- ============================================================================

local Rules = {}
Rules.__index = Rules

function Rules.new()
  local self = setmetatable({}, Rules)
  -- Default to take up full parent.
  self.rules = {
    x = Plan.parent(),
    y = Plan.parent(),
    w = Plan.parent(),
    h = Plan.parent(),
  }
  return self
end

local function validateRuleInput(input, dimension)
  if isNumber(input) then
    return PixelRule.new(input)
  end

  if not isValidRule(input) then
    error("An invalid input was passed to " .. dimension .. "dimension")
  end

  return input
end

function Rules:addX(rule)
  self.rules.x = validateRuleInput(rule, "x")
  return self
end

function Rules:getX()
  return self.rules.x
end

function Rules:addY(rule)
  self.rules.y = validateRuleInput(rule, "y")
  return self
end

function Rules:getY()
  return self.rules.y
end

function Rules:addWidth(rule)
  self.rules.w = validateRuleInput(rule, "width")
  return self
end

function Rules:getWidth()
  return self.rules.w
end

function Rules:addHeight(rule)
  self.rules.h = validateRuleInput(rule, "height")
  return self
end

function Rules:getHeight()
  return self.rules.h
end

function Rules:realise(element)
    local parent = element.parent or {}
    return (parent.x or 0) + self.rules.x:realise("x", element, self.rules),
    (parent.y or 0) + self.rules.y:realise("y", element, self.rules),
    self.rules.w:realise("w", element, self.rules),
    self.rules.h:realise("h", element, self.rules)
end

function Rules:clone()
  local copy = Rules.new()

  if self.rules.x then
    copy:addX(self.rules.x:clone())
  end

  if self.rules.y then
    copy:addY(self.rules.y:clone())
  end

  if self.rules.w then
    copy:addWidth(self.rules.w:clone())
  end

  if self.rules.h then
    copy:addHeight(self.rules.h:clone())
  end

  return copy
end

function Rules:update(dimension, fn, ...)
  dimension = string.lower(dimension)
  if dimension == "x" then
    self.rules.x = fn(self:getX(), ...)
  end

  if dimension == "y" then
    self.rules.y = fn(self:getY(), ...)
  end

  if dimension == "w" or dimension == "width" then
    self.rules.w = fn(self:getWidth(), ...)
  end

  if dimension == "h" or dimension == "height" then
    self.rules.h = fn(self:getHeight(), ...)
  end
end

Plan.Rules = Rules

-- ============================================================================
-- Rule Factories
-- ============================================================================

local RuleFactory = {}

function RuleFactory.full()
  local rules = Rules.new()
  rules:addX(Plan.parent())
    :addY(Plan.parent())
    :addWidth(Plan.parent())
    :addHeight(Plan.parent())
  return rules
end

function RuleFactory.half(direction)
  if not contains({"top", "bottom", "right", "left"}, direction) then
    error("Unknown direction passed")
  end

  local rules = RuleFactory.full()

  if direction == "top" then
    rules:addHeight(Plan.relative(0.5))
  end

  if direction == "bottom" then
    rules:addY(Plan.relative(0.5))
    rules:addHeight(Plan.relative(0.5))
  end

  if direction == "left" then
    rules:addWidth(Plan.relative(0.5))
  end

  if direction == "right" then
    rules:addX(Plan.relative(0.5))
    rules:addWidth(Plan.relative(0.5))
  end

  return rules
end

function RuleFactory.relativeGutter(value)
  local rules = Rules.new()
  rules:addX(Plan.relative(value))
      :addY(Plan.relative(value))
      -- margin must be applied on both "sides"
      :addWidth(Plan.relative(1 - value * 2))
      :addHeight(Plan.relative(1 - value * 2))
  return rules
end

function RuleFactory.pixelGutter(value)
  local rules = Rules.new()
  rules:addX(Plan.pixel(value))
    :addY(Plan.pixel(value))
    -- margin must be applied on both "sides"
    :addWidth(Plan.max(value * 2))
    :addHeight(Plan.max(value * 2))
  return rules
end

Plan.RuleFactory = RuleFactory

-- ============================================================================
-- Entrypoint
-- ============================================================================

-- We cannot use `RuleFactory.full` as it relies on a parent, and this is the
-- root.
local function __fullScreen()
  local rules = Rules.new()
    :addX(PixelRule.new(0))
    :addY(PixelRule.new(0))
    :addWidth(PixelRule.new(love.graphics.getWidth()))
    :addHeight(PixelRule.new(love.graphics.getHeight()))
  return rules
end

function Plan.new()
  local self = setmetatable({}, Plan)
  self.root = Container:new(__fullScreen())
  self.root.isUIRoot = true
  return self
end

function Plan:refresh()
  self.root.rules = __fullScreen()
  self.root:refresh()
end

function Plan:addChild(child)
  self.root:addChild(child)
end

function Plan:removeChild(child)
  self.root:removeChild(child)
end

function Plan:update(dt)
  self.root:update(dt)
end

function Plan:draw()
  self.root:draw()
end

function Plan:emit(event, ...)
  self.root:emit(event, ...)
end

return Plan
