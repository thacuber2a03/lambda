-- Copyright (c) 2024 @thacuber2a03
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- TODO: add some form of expression input
-- in the meantime, find the "toplevel" variable and modify it
-- using any of Expr, Var, Func or Apply

local Object = require "classic/classic"

-- TODO: make these configurable elsewhere
local useBuiltinFont = false
local useAscii = false
local externalFontPath = "fonts/FiraCode-Bold.ttf"
local externalSmallFontPath = "fonts/FiraCode-Regular.ttf"
local sizeFactor = 1

local lambda, arrow

if useBuiltinFont or useAscii then
	lambda = "\\"
	arrow = " ->"
else
	lambda = "λ"
	arrow = " →"
end

local Expr = Object:extend()

function Expr:queryExprAt(x, font)
	local w = font:getWidth(tostring(self))
	if x >= 0 and x < w then return self, 0, w end
end

function Expr:displayName()
	return "arbitrary expression"
end

function Expr:__tostring()
	return "e"
end

local Var = Expr:extend()

function Var:new(name)
	self.name = name
end

function Var:displayName()
	return "variable"
end

function Var:__tostring()
	return self.name
end

local Func = Expr:extend()

function Func:new(param, expr)
	self.param = param
	self.expr = expr
end

function Func:displayName()
	return "function abstraction/definition"
end

function Func:queryExprAt(x, font)
	local tx = font:getWidth("(" .. lambda .. self.param .. arrow .. " ")
	local e, ex, ew = self.expr:queryExprAt(x - tx, font)
	if e then return e, ex + tx, ew end

	return self.super.queryExprAt(self, x, font)
end

function Func:__tostring()
	return "("
		.. lambda
		.. self.param
		.. arrow
		.. " "
		.. tostring(self.expr)
		.. ")"
end

local Apply = Expr:extend()

function Apply:new(func, expr)
	self.func = func
	self.expr = expr
end

function Apply:displayName()
	return "function application"
end

function Apply:queryExprAt(x, font)
	local tx, e, ex, ew

	tx = 0
	e, ex, ew = self.func:queryExprAt(x - tx, font)
	if e then return e, ex + tx, ew end

	tx = tx + font:getWidth(tostring(self.func) .. " ")
	if self.expr:is(Apply) then tx = tx + font:getWidth "(" end

	e, ex, ew = self.expr:queryExprAt(x - tx, font)
	if e then return e, ex + tx, ew end

	return self.super.queryExprAt(self, x, font)
end

function Apply:__tostring()
	local f = tostring(self.func)
	local e = tostring(self.expr)

	if self.expr:is(Apply) then return f .. " (" .. e .. ")" end
	return f .. " " .. e
end

local toplevel

-- successor function
local body = Apply(Var "f", Apply(Apply(Var "n", Var "f"), Var "x"))
toplevel = Func("n", Func("f", Func("x", body)))

--[[
-- y-combinator
local vf, vx = Var "f", Var "x"
local yCombHalf = Func("f", Func("x", Apply(vf, Apply(vx, vx))))
toplevel = Apply(yCombHalf, yCombHalf)
--]]

-- NOTE: Love2D specific code onwards

local selexp
local selx, selw, sela = 0, 0, 0
local selgoalx, selgoalw, selgoala = selx, selw, sela

local font, smallFont

function love.load()
	love.window.setTitle "Lambda"
	love.window.setMode(0, 0, { resizable = true })

	local fontSize = 48 * sizeFactor
	local smallFontSize = 18 * sizeFactor

	if useBuiltinFont then
		font = love.graphics.newFont(fontSize)
		smallFont = love.graphics.newFont(smallFontSize)
	else
		font = love.graphics.newFont(externalFontPath, fontSize)
		smallFont = love.graphics.newFont(externalSmallFontPath, smallFontSize)
	end
end

function love.keypressed(k)
	if k == "escape" then love.event.quit() end
end

function love.update(dt)
	local t = math.min(1, dt * 15)
	selx = selx + (selgoalx - selx) * t
	selw = selw + (selgoalw - selw) * t
	sela = sela + (selgoala - sela) * t
end

function love.draw()
	local winWidth = love.graphics.getWidth()
	local winHeight = love.graphics.getHeight()

	love.graphics.clear(0.25, 0.25, 0.3)

	local t = tostring(toplevel)
	local w = font:getWidth(t)
	local h = font:getHeight()
	local x = (winWidth - w) / 2
	local y = (winHeight - h) / 2

	local expr, ex, ew

	local mx, my = love.mouse.getPosition()
	if my >= y and my < y + h then
		expr, ex, ew = toplevel:queryExprAt(mx - x, font)
	end

	selgoala = 0
	if expr then
		selexp = expr
		selgoalx, selgoalw = ex, ew
		selgoala = 1
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.print(t, font, x, y)

	if sela >= 1e-4 then
		local drawX = x + selx

		love.graphics.setColor(1, 1, 1, sela)
		local padding = 3
		love.graphics.rectangle(
			"line",
			drawX - padding,
			y - padding,
			selw + padding * 2,
			font:getHeight() + padding * 2
		)

		if selexp then
			local dn = selexp:displayName()
			local sw = smallFont:getWidth(dn)
			local sh = smallFont:getHeight()
			love.graphics.print(
				dn,
				smallFont,
				math.floor(drawX - (sw - selw) / 2),
				math.floor(y - sh * 1.5)
			)
		end
	end

	local hoverMsg = "hover the mouse over the expression above"
	local hw = smallFont:getWidth(hoverMsg)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(
		hoverMsg,
		smallFont,
		math.floor((winWidth - hw) / 2),
		math.floor(y + h + smallFont:getHeight() / 2)
	)
end
