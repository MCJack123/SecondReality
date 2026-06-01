local box = require "pixelbox".new(term.current(), 0)
local file = assert(fs.open("water.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 5 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, 0, 0, 0)
    pal[i] = {r / 255, g / 255, b / 255}
end
local imgw, imgh = 320, 200
local img = {}
for y = 1, imgh do
    local line = {}
    img[imgh-y+1] = line
    for x = 1, imgw, 2 do
        local c = file.read()
        line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
    end
end
file.close()
file = assert(fs.open("sword.bmp", "rb"))
file.seek("set", 0x36 + 4)
for i = 6, 15 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, r / 255, g / 255, b / 255)
    pal[i] = {r / 255, g / 255, b / 255}
end
local text = {}
for y = 1, 35 do
    local line = {}
    text[35-y+1] = line
    for x = 1, 400, 2 do
        local c = file.read()
        line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
    end
end
file.close()

local floor, abs, sin, cos = math.floor, math.abs, math.sin, math.cos
term.setBackgroundColor(1)
term.clear()
sleep(0.05)

local bgc = box.canvas
local w, h = box.width, box.height
local ww = floor(h / imgh * imgw)
local xo = w > ww and floor((w - ww) / 2) or 0
for y = 1, h do
    local l = bgc[y]
    local iy = floor((y - 1) * (imgh / h)) + 1
    for x = 1, ww do
        local ix = floor((x - 1) * (imgw / ww)) + 1
        local c = img[iy][ix]
        l[x+xo] = c
    end
end
box:render()

for i = 1, 20 do
    local r = i / 20
    for j = 0, 5 do term.setPaletteColor(2^j, pal[j][1] * r, pal[j][2] * r, pal[j][3] * r) end
    sleep(0.05)
end
if PLAYER then while PLAYER.order < 77 or PLAYER.row < 16 do sleep(0.05) end end

local transforms = {
    {pos = vector.new(0, 0, 0), rot = vector.new(math.pi * 4 / -16, math.pi * 6 / 16, math.pi * 4.5 / -16), offset = 0, stretch = 1},
    {pos = vector.new(0.325, 0.175, 2), rot = vector.new(math.pi * 1 / 16, math.pi * -1 / 16, math.pi * 13 / 16), offset = 0.25, stretch = 2},
    {pos = vector.new(1, 5.4, 10), rot = vector.new(math.pi * -3 / 16, math.pi * 6 / 16, math.pi * -13 / 16), offset = -17.7, stretch = 1},
    {pos = vector.new(0.14, -0.16, 60), rot = vector.new(math.pi * -1 / 16, math.pi * -1 / 16, math.pi * -8 / 16), offset = 11.5, stretch = 1},
}

local ez = ww
for i = -160, 400 do
    if PLAYER and PLAYER.order > 79 then break end
    if PLAYER and PLAYER.order == 79 and PLAYER.row >= 56 then
        local r = math.max((1 - (PLAYER.row - 56) / 7)^2, 0)
        local bc = term.nativePaletteColor(colors.black) * (1 - r)
        for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * r + bc, pal[j][2] * r + bc, pal[j][3] * r + bc) end
    end
    local canvas = {}
    term.setCursorPos(1, 1)
    for _, v in ipairs(transforms) do
        local pos, rot = v.pos, v.rot
        local cx, sx, cy, sy, cz, sz = cos(rot.x), sin(rot.x), cos(rot.y), sin(rot.y), cos(rot.z), sin(rot.z)
        for y = 1, 35 do
            for x = 1, 400 do
                local dx, dy, dz = (x - 200) / 100 - i / 80 + v.offset, (y - 17) / 200 * v.stretch, pos.z
                dx, dy = dx * cz + dy * sz, dx * -sz + dy * cz
                dx, dz = dx * cy + dz * -sy, dx * sy + dz * cy
                dy, dz = dy * cx + dz * sx, dy * -sx + dz * cx
                if dz > pos.z-1 and dz < pos.z then
                    local sx, sy = floor(ez / (dz + 1) * dx + ww / 2 + pos.x * ww / 2), floor(ez / (dz + 1) * dy + h / 2 + pos.y * h / 2)
                    --if x == 1 and y == 1 then term.setTextColor(2^5) print(dx, dy, dz, sx, sy) sleep(0.05) end
                    if bgc[sy] and bgc[sy][sx] then
                        local c = text[y][x]
                        if c > 0 then
                            canvas[sy] = canvas[sy] or setmetatable({}, {__index = bgc[sy]})
                            canvas[sy][sx+xo] = (c+5)
                        end
                    end
                end
            end
        end
    end
    box.canvas = setmetatable(canvas, {__index = bgc})
    box:render()
    sleep(0.05)
end

term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
