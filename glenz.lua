local Pine3D = require "Pine3D"
local pi, pi2 = math.pi, math.pi * 2
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local function newPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, c)
	---@type Polygon
	local poly = {
		x1 = x1,
		y1 = y1,
		z1 = z1,
		x2 = x2,
		y2 = y2,
		z2 = z2,
		x3 = x3,
		y3 = y3,
		z3 = z3,
		c = c,
	}
	return poly
end

---@param options {color: number?, color2: number?}
local function isocube(options)
	options.color = options.color or 15
	options.color2 = options.color2 or 0
    local rt2 = 0.333333
	---@class Model
	local cube = {
		newPoly(0, -.5, 0, rt2, -rt2, rt2, -rt2, -rt2, rt2, options.color),
		newPoly(0, -.5, 0, -rt2, -rt2, rt2, -rt2, -rt2, -rt2, options.color2),
		newPoly(0, -.5, 0, -rt2, -rt2, -rt2, rt2, -rt2, -rt2, options.color),
		newPoly(0, -.5, 0, rt2, -rt2, -rt2, rt2, -rt2, rt2, options.color2),

		newPoly(0, .5, 0, -rt2, rt2, rt2, rt2, rt2, rt2, options.color),
		newPoly(0, .5, 0, -rt2, rt2, -rt2, -rt2, rt2, rt2, options.color2),
		newPoly(0, .5, 0, rt2, rt2, -rt2, -rt2, rt2, -rt2, options.color),
		newPoly(0, .5, 0, rt2, rt2, rt2, rt2, rt2, -rt2, options.color2),

		newPoly(-.5, 0, 0, -rt2, rt2, rt2, -rt2, rt2, -rt2, options.color),
		newPoly(-.5, 0, 0, -rt2, rt2, -rt2, -rt2, -rt2, -rt2, options.color2),
		newPoly(-.5, 0, 0, -rt2, -rt2, -rt2, -rt2, -rt2, rt2, options.color),
		newPoly(-.5, 0, 0, -rt2, -rt2, rt2, -rt2, rt2, rt2, options.color2),

		newPoly(.5, 0, 0, rt2, rt2, -rt2, rt2, rt2, rt2, options.color),
		newPoly(.5, 0, 0, rt2, -rt2, -rt2, rt2, rt2, -rt2, options.color2),
		newPoly(.5, 0, 0, rt2, -rt2, rt2, rt2, -rt2, -rt2, options.color),
		newPoly(.5, 0, 0, rt2, rt2, rt2, rt2, -rt2, rt2, options.color2),

		newPoly(0, 0, -.5, rt2, rt2, -rt2, rt2, -rt2, -rt2, options.color),
		newPoly(0, 0, -.5, rt2, -rt2, -rt2, -rt2, -rt2, -rt2, options.color2),
		newPoly(0, 0, -.5, -rt2, -rt2, -rt2, -rt2, rt2, -rt2, options.color),
		newPoly(0, 0, -.5, -rt2, rt2, -rt2, rt2, rt2, -rt2, options.color2),

		newPoly(0, 0, .5, rt2, -rt2, rt2, rt2, rt2, rt2, options.color),
		newPoly(0, 0, .5, -rt2, -rt2, rt2, rt2, -rt2, rt2, options.color2),
		newPoly(0, 0, .5, -rt2, rt2, rt2, -rt2, -rt2, rt2, options.color),
		newPoly(0, 0, .5, rt2, rt2, rt2, -rt2, rt2, rt2, options.color2),
	}

	for name, func in pairs(Pine3D.transforms) do
		cube[name] = func
	end

	return cube
end

local function texplane(texture, res, w, h, scale)
    res = res or 32
    w, h = w or #texture[1], h or #texture
    scale = scale or 1
    ---@type Model
    local model = {}
    local resinv = 1 / res
    for y = 0, 0.9999999, resinv do
        for x = 0, 0.9999999, resinv do
            local u1, v1, u2, v2 = floor(x * w + 1), floor(y * h + 1), floor((x + resinv) * w), floor((y + resinv) * h)
            model[#model+1] = newPoly(
                (0.5 - y) * scale, 0, (x - 0.5) * scale,
                (0.5 - y - resinv) * scale, 0, (x - 0.5) * scale,
                (0.5 - y - resinv) * scale, 0, (x + resinv - 0.5) * scale,
                {u1, v1, u1, v2, u2, v2, texture}
            )
            model[#model+1] = newPoly(
                (0.5 - y) * scale, 0, (x + resinv - 0.5) * scale,
                (0.5 - y) * scale, 0, (x - 0.5) * scale,
                (0.5 - y - resinv) * scale, 0, (x + resinv - 0.5) * scale,
                {u2, v1, u1, v1, u2, v2, texture}
            )
        end
    end

    for name, func in pairs(Pine3D.transforms) do
		model[name] = func
	end

	return model
end

local frame = Pine3D.newFrame()
frame:setCamera(0, 0, 0, 0, 0, 0)
frame:setFoV(60)
frame:setBackgroundColor(15)
--frame:setWireFrame(true)
local model = isocube({color = 11, color2 = 0})
for _, v in pairs(model) do if type(v) == "table" and v.x1 then v.forceRender = true end end
local obj = frame:newObject(model, 4, 2, 0, 0, 0, 0)
local floorobj = frame:newObject(texplane(setmetatable({}, {__index = function(_, y) return setmetatable({}, {__index = function(_, x) return (((x+y)%2+1)*4) end}) end}), 8, 8, 8, 2.5), 4, -1, 0, 0, 0, 0)
local obj2 = frame:newObject(model:scale(2.5), 4, 0, 0, 0, 0, 0)
local list = {floorobj, obj}
local compress, compressDiff = 0, 0
obj:setVertexShader(function(x, y, z, poly, vn)
    local vx = vector.new(x, y, z)
    if vn == 1 then poly.v1 = vx
    elseif vn == 2 then poly.v2 = vx
    else poly.intensity = (vx - poly.v1):cross(poly.v2 - poly.v1):dot(vector.new(1)) end
    return x, y * (1 - compress), z * (1 + compress)
end)
local y, vy = 2, 0
local function blendColors2(a, b, alpha, beta)
    local ar, ag, ab = term.nativePaletteColor(a)
    local br, bg, bb = term.nativePaletteColor(b)
    local ialpha = 1 - alpha
    return ar * ialpha + br * beta * alpha,
           ag * ialpha + bg * beta * alpha,
           ab * ialpha + bb * beta * alpha
end
local function blendColors3(a, b, c, alpha, beta)
    local ar, ag, ab = term.nativePaletteColor(a)
    local br, bg, bb = term.nativePaletteColor(b)
    local cr, cg, cb = term.nativePaletteColor(c)
    local ialpha = 1 - alpha
    return ar * ialpha * ialpha + br * beta * alpha * ialpha + cr * beta * alpha,
           ag * ialpha * ialpha + bg * beta * alpha * ialpha + cg * beta * alpha,
           ab * ialpha * ialpha + bb * beta * alpha * ialpha + cb * beta * alpha
end
local function blendColors4(a, b, c, d, alpha, beta)
    local ar, ag, ab = term.nativePaletteColor(a)
    local br, bg, bb = term.nativePaletteColor(b)
    local cr, cg, cb = term.nativePaletteColor(c)
    local dr, dg, db = term.nativePaletteColor(d)
    local ialpha = 1 - alpha
    return ar * ialpha * ialpha * ialpha + br * beta * alpha * ialpha * ialpha + cr * beta * alpha * ialpha + dr * beta * alpha,
           ag * ialpha * ialpha * ialpha + bg * beta * alpha * ialpha * ialpha + cg * beta * alpha * ialpha + dg * beta * alpha,
           ab * ialpha * ialpha * ialpha + bb * beta * alpha * ialpha * ialpha + cb * beta * alpha * ialpha + db * beta * alpha
end
frame.buffer.blitWin.setPaletteColor(2^0, blendColors3(colors.black, colors.lightGray, colors.lightGray, 0.75, 0.25))
frame.buffer.blitWin.setPaletteColor(2^1, blendColors3(colors.black, colors.lightGray, colors.lightGray, 0.75, 0.5))
frame.buffer.blitWin.setPaletteColor(2^2, blendColors3(colors.black, colors.lightGray, colors.lightGray, 0.75, 0.75))
frame.buffer.blitWin.setPaletteColor(2^3, blendColors3(colors.black, colors.lightGray, colors.lightGray, 0.75, 1.0))
frame.buffer.blitWin.setPaletteColor(2^4, blendColors3(colors.black, colors.purple, colors.purple, 0.75, 0.25))
frame.buffer.blitWin.setPaletteColor(2^5, blendColors3(colors.black, colors.blue, colors.blue, 0.75, 0.5))
frame.buffer.blitWin.setPaletteColor(2^6, blendColors3(colors.black, colors.blue, colors.blue, 0.75, 0.75))
frame.buffer.blitWin.setPaletteColor(2^7, blendColors3(colors.black, colors.blue, colors.blue, 0.75, 1.0))
frame.buffer.blitWin.setPaletteColor(2^8, blendColors3(colors.black, colors.magenta, colors.magenta, 0.75, 0.25))
frame.buffer.blitWin.setPaletteColor(2^9, blendColors3(colors.black, colors.blue, colors.lightGray, 0.75, 0.5))
frame.buffer.blitWin.setPaletteColor(2^10, blendColors3(colors.black, colors.blue, colors.lightGray, 0.75, 0.75))
frame.buffer.blitWin.setPaletteColor(2^11, blendColors3(colors.black, colors.blue, colors.lightGray, 0.75, 1.0))
frame.buffer.blitWin.setPaletteColor(2^12, blendColors3(colors.black, colors.lightGray, colors.blue, 0.75, 0.5))
frame.buffer.blitWin.setPaletteColor(2^13, blendColors3(colors.black, colors.lightGray, colors.blue, 0.75, 0.75))
frame.buffer.blitWin.setPaletteColor(2^14, blendColors3(colors.black, colors.lightGray, colors.blue, 0.75, 1.0))
local white = {[0] = 15, 0, 1, 2, 3}
local blue = {[0] = 15, 4, 5, 6, 7}
local blendA = {[0] = 15, 8, 9, 10, 11}
local blendB = {[0] = 15, 8, 12, 13, 14}
for i = 1, 20 do
    floorobj:setPos(4, -(i / 20)^2 * 0.666666666 - 0.33333333, 0)
    frame:drawObjects(list)
    frame:drawBuffer()
    sleep(0.05)
end
for i = 1, 5 do
    floorobj:setPos(4, (i / 30)^2-1, 0)
    frame:drawObjects(list)
    frame:drawBuffer()
    sleep(0.05)
end
for i = 5, 0, -1 do
    floorobj:setPos(4, (i / 30)^2-1, 0)
    frame:drawObjects(list)
    frame:drawBuffer()
    sleep(0.05)
end
for i = 1, 3 do
    floorobj:setPos(4, (i / 40)^2-1, 0)
    frame:drawObjects(list)
    frame:drawBuffer()
    sleep(0.05)
end
for i = 2, 0, -1 do
    floorobj:setPos(4, (i / 40)^2-1, 0)
    frame:drawObjects(list)
    frame:drawBuffer()
    sleep(0.05)
end
while PLAYER.order < 5 do sleep(0.1) end
while PLAYER.row < 24 do sleep(0.05) end
local state = 1
local fadeTimer = 0
local motionStart, motionStart2
--local ft = fs.open("glenztimeflat.txt", "w")
for i = 1, 4000, 2 do
    local drawn = {}
    if state < 3 then
        obj:setFragmentShader(function(x, y, depth, poly, texcolor, interpVars)
            --do return texcolor == colors.white and 2^4 or 2^9 end
            if drawn[y] and drawn[y][x] then
                local other, thisc = drawn[y][x], texcolor
                local otherc, intensity = other[1], min(floor(max(other[2], poly.intensity, 0) * 20), 4)
                if other[3] > depth then otherc, thisc = thisc, otherc end
                if otherc == 0 and thisc == 0 then
                    return white[intensity]
                elseif otherc == 11 and thisc == 0 then
                    return blendA[intensity]
                elseif otherc == 0 and thisc == 11 then
                    return blendB[intensity]
                else
                    return blue[intensity]
                end
            else
                drawn[y] = drawn[y] or {}
                drawn[y][x] = {texcolor, poly.intensity, depth}
                return texcolor --2^math.min(math.max(floor((depth - 0.15) * 80), 1), 15)
            end
        end)
    else
        obj:setFragmentShader(function(x, y, depth, poly, texcolor, interpVars)
            --do return texcolor == colors.white and 2^4 or 2^9 end
            local l = drawn[y]
            if l then
                l[x] = bit32.bor(l[x] or 0, texcolor == 0 and 4 or 8)
            else
                l = {}
                drawn[y] = l
                l[x] = texcolor == 0 and 4 or 8
            end
            return (l[x]-1)
        end)
        obj2:setFragmentShader(function(x, y, depth, poly, texcolor, interpVars)
            --do return texcolor == colors.white and 2^4 or 2^9 end
            local l = drawn[y]
            if l then
                l[x] = bit32.bor(l[x] or 0, texcolor == 0 and 1 or 2)
            else
                l = {}
                drawn[y] = l
                l[x] = texcolor == 0 and 1 or 2
            end
            return (l[x]-1)
        end)
    end
    obj:setRot(math.rad(i / 3), math.rad(i * 4), math.rad(i / 2))
    obj2:setRot(-math.rad(i / 5), -math.rad(i * 2), -math.rad(i / 4))
    if state == 1 then
        y = y + vy
        vy = max(vy - 0.003, -0.09)
        if PLAYER.order == 8 and vy > 0 and y > 0 then state = 2 end
    elseif state == 2 then
        frame.buffer.blitWin.setPaletteColor(2^4, blendColors3(colors.black, colors.purple, colors.purple, 0.75 - 0.75 * fadeTimer / 20, 0.25))
        frame.buffer.blitWin.setPaletteColor(2^8, blendColors3(colors.black, colors.magenta, colors.magenta, 0.75 - 0.75 * fadeTimer / 20, 0.25))
        fadeTimer = fadeTimer + 1
        if fadeTimer == 20 then
            fadeTimer = 0
            state = 3
        end
    elseif state == 3 then
        list = {obj2, obj}
        frame.buffer.blitWin.setPaletteColor(2^0, blendColors2(colors.black, colors.red, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^1, blendColors2(colors.black, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^2, blendColors3(colors.black, colors.red, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^3, blendColors2(colors.black, colors.blue, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^4, blendColors3(colors.black, colors.blue, colors.red, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^5, blendColors3(colors.black, colors.blue, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^6, blendColors4(colors.black, colors.red, colors.blue, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^7, blendColors2(colors.black, colors.white, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^8, blendColors3(colors.black, colors.white, colors.red, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^9, blendColors3(colors.black, colors.white, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^10, blendColors4(colors.black, colors.red, colors.white, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^11, blendColors3(colors.black, colors.white, colors.blue, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^12, blendColors4(colors.black, colors.blue, colors.white, colors.red, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^13, blendColors4(colors.black, colors.blue, colors.white, colors.gray, 0.5, 1))
        frame.buffer.blitWin.setPaletteColor(2^14, blendColors4(colors.red, colors.blue, colors.white, colors.gray, 0.5, 1))
        obj2:setVertexShader(function(x, y, z, poly, vn)
            return x * fadeTimer / 20, y * fadeTimer / 20, z * fadeTimer / 20
        end)
        state = 4
    elseif state == 4 then
        fadeTimer = fadeTimer + 1
        if fadeTimer == 20 then
            obj:setVertexShader(nil)
            obj2:setVertexShader(nil)
            fadeTimer = 0
            motionStart = i
            state = 5
        end
    elseif state == 5 then
        if PLAYER.order == 12 and PLAYER.row > 32 then state, motionStart2 = 6, i end
    elseif state == 6 then
        if PLAYER.order == 13 and PLAYER.row > 32 then state = 7 end
    elseif state == 7 then
        if PLAYER.order > 13 or PLAYER.row > 48 then break end
        frame.buffer.blitWin.setPaletteColor(2^0, blendColors2(colors.black, colors.red, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^1, blendColors2(colors.black, colors.gray, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^2, blendColors3(colors.black, colors.red, colors.gray, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^3, blendColors2(colors.black, colors.blue, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^4, blendColors3(colors.black, colors.red, colors.blue, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^5, blendColors3(colors.black, colors.gray, colors.blue, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^6, blendColors4(colors.black, colors.red, colors.blue, colors.gray, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^7, blendColors2(colors.black, colors.white, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^8, blendColors3(colors.black, colors.red, colors.white, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^9, blendColors3(colors.black, colors.gray, colors.white, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^10, blendColors4(colors.black, colors.red, colors.white, colors.gray, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^11, blendColors3(colors.black, colors.white, colors.blue, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^12, blendColors4(colors.black, colors.red, colors.blue, colors.white, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^13, blendColors4(colors.black, colors.gray, colors.blue, colors.white, (48 - PLAYER.row) / 31, 1))
        frame.buffer.blitWin.setPaletteColor(2^14, blendColors4(colors.red, colors.blue, colors.white, colors.gray, (48 - PLAYER.row) / 31, 1))
    end
    --local oy, oz = math.abs(math.cos(pi2 * i / 128)) * 1.2 - 0.8, tri(pi2 * i / 90)
    if state < 5 then
        local oy = y
        if y < -0.5 then
            local oldc = compress
            compress = (-0.5 - y) / 2
            compressDiff = compress - oldc
            oy = y + compress
            vy = vy + compress / 3
        else
            compress = compress - compressDiff * 2.5
            compressDiff = compressDiff * 0.9 + compress * 0.25
            --compress = 0
        end
        obj:setPos(4, oy, 0)
    elseif state == 5 then
        obj:setPos(4 + math.sin(pi2 * (i - motionStart) / 169) / 4, math.sin(pi2 * (i - motionStart) / 121) / 2, math.sin(pi2 * (i - motionStart) / 147) / 2)
        obj2:setPos(4 - math.sin(pi2 * (i - motionStart) / 169 / 1.5) / 12, -math.sin(pi2 * (i - motionStart) / 121 / 1.5) / 6, -math.sin(pi2 * (i - motionStart) / 147 / 1.5) / 6)
    else
        local obj2speed = (i - motionStart2) / 160 + 1
        local obj2amp = (i - motionStart2) / 20 + 1
        obj:setPos(4 + math.sin(pi2 * (i - motionStart) / 169) / 4, math.sin(pi2 * (i - motionStart) / 121 * ((obj2speed - 1) / 5 + 1)) / 2 + (i - motionStart2) / 60, math.sin(pi2 * (i - motionStart) / 147) / 2)
        obj2:setPos(3 + obj2amp - math.sin(pi2 * (i - motionStart) / 169 / 1.5 * obj2speed) / 12 * obj2amp, -math.sin(pi2 * (i - motionStart) / 121 / 1.5 * obj2speed) / 6 * obj2amp, -math.sin(pi2 * (i - motionStart) / 147 / 1.5 * obj2speed) / 6 * obj2amp - obj2amp / 2 + 0.5)
    end
    normdat = {}
    local start = os.epoch "utc"
    frame:drawObjects(list)
    frame:drawBuffer()
    term.setCursorPos(1, 1)
    term.setTextColor(2^14)
    --ft.writeLine(os.epoch "utc" - start)
    --print(("% .2f % .2f % .2f"):format(compress, compressDiff, y))
    sleep(0.05)
end
--ft.close()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
