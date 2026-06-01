local Pine3D = require "Pine3D"
local pi, pi2 = math.pi, math.pi * 2
local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
local frame = Pine3D.newFrame()
frame:setCamera(0, 0, 0, 0, 0, 0)
frame:setFoV(60)
frame:setBackgroundColor(15)
local w, h = 64, 64
local base, intensity = 0.4, 0.4
local img = {}
local obj
local n = 0
local dir = {[0] = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local bc = term.nativePaletteColor(colors.black)
for i = 1, 2000 do
    if PLAYER.order == 66 then break end
    for y = 1, h do
        local l = {}
        img[y] = l
        for x = 1, w do
            l[x] = min(max(floor((abs((y / h + x / w / 2 - 0.75) * 4 - math.sin(pi2 * (i + x) / w)) * 3)^1.5), 0), 14)
        end
    end
    local rotX, rotY, rotZ = math.rad(i), math.rad(i * 4), math.rad(i / 2)
    local forward = vector.new(1)
    --[[forward = vector.new(
        vector.new(math.cos(rotY), 0, math.sin(rotY)):dot(forward),
        vector.new(0, 1, 0):dot(forward),
        vector.new(-math.sin(rotY), 0, math.cos(rotY)):dot(forward)
    )
    forward = vector.new(
        vector.new(math.cos(rotZ), -math.sin(rotZ), 0):dot(forward),
        vector.new(math.sin(rotZ), math.cos(rotZ), 0):dot(forward),
        vector.new(0, 0, 1):dot(forward)
    )
    forward = vector.new(
        vector.new(1, 0, 0):dot(forward),
        vector.new(0, math.cos(rotX), -math.sin(rotX)):dot(forward),
        vector.new(0, math.sin(rotX), math.cos(rotX)):dot(forward)
    )]]
    if not obj then
        obj = frame:newObject(Pine3D.models:cube {texture = img}, 4, 0, 0, 0, 0, 0)
        obj:setVertexShader(function(x, y, z, poly, vn)
            if not poly.n then
                poly.n = n
                local a = vector.new(poly[1], poly[2], poly[3])
                local b = vector.new(poly[4], poly[5], poly[6])
                local c = vector.new(poly[7], poly[8], poly[9])
                dir[n] = min(max((c - a):cross(b - a):dot(forward), (b - a):cross(c - a):dot(forward), 0), 1)
                n = n + 1
            end
            return x, y, z
        end)
        obj:setFragmentShader(function(x, y, depth, poly, texcolor, interpVars)
            return (floor(texcolor / 3) + floor(poly.n / 4) % 3 * 5)
        end)
    end
    n = 0
    obj:setRot(rotX, rotY, rotZ)
    obj:setPos(math.cos(pi2 * i / 400) + 3, -(max(20 - i, 0)/10)^2, 0)
    frame:drawObjects {obj}
    local rat = 1
    if PLAYER.order == 65 then rat = (64 - PLAYER.row) / 64 end
    for j = 0, 4 do
        local xx = (i / 50 + j / 14) % 1
        local r, g, b
        r = ((max(abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base) * dir[0] * rat + bc * (1 - rat)
        g = bc * (1 - rat)
        b = ((max(1 - abs(3.0*xx - 2), 0.0)) * intensity + base) * dir[0] * rat + bc * (1 - rat)
        frame.buffer.blitWin.setPaletteColor(2^j, r, g, b)
    end
    for j = 5, 9 do
        local xx = (i / 50 + j / 14) % 1
        local r, g, b
        r = ((max(abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base) * dir[4] * rat + bc * (1 - rat)
        g = ((max(1 - abs(3.0*xx - 2), 0.0)) * intensity + base) * dir[4] * rat + bc * (1 - rat)
        b = bc * (1 - rat)
        frame.buffer.blitWin.setPaletteColor(2^j, r, g, b)
    end
    for j = 10, 14 do
        local xx = (i / 50 + j / 14) % 1
        local r, g, b
        r = bc * (1 - rat)
        g = ((max(abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base) * dir[8] * rat + bc * (1 - rat)
        b = ((max(1 - abs(3.0*xx - 2), 0.0)) * intensity + base) * dir[8] * rat + bc * (1 - rat)
        frame.buffer.blitWin.setPaletteColor(2^j, r, g, b)
    end
    frame:drawBuffer()
    sleep(0.05)
end