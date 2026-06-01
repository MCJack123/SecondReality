local box = require "pixelbox".new(term.current(), 0)
local bc = term.nativePaletteColor(colors.black)
local file = assert(fs.open("forest.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 11 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, bc, bc, bc)
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
file = assert(fs.open("foresttext.bmp", "rb"))
file.seek("set", 0x36 + 4)
for i = 12, 15 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, bc, bc, bc)
    pal[i] = {r / 255, g / 340, b / 319}
end
local text = {}
for y = 1, 32 do
    local line = {}
    text[32-y+1] = line
    for x = 1, 640, 2 do
        local c = file.read()
        line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
    end
end
file.close()

local floor, abs, rt22 = math.floor, math.abs, math.sqrt(2) / 8

term.setBackgroundColor(1)
term.clear()
for i = -40, 640 do
    if i < 1 then
        if i <= -35 then
            local r = (i + 40) / 5
            for j = 7, 11 do term.setPaletteColor(2^j, pal[j][1] * r + bc * (1 - r), pal[j][2] * r + bc * (1 - r), pal[j][3] * r + bc * (1 - r)) end
        elseif i > -10 then
            local r = (i + 10) / 10
            for j = 0, 6 do term.setPaletteColor(2^j, pal[j][1] * r + bc * (1 - r), pal[j][2] * r + bc * (1 - r), pal[j][3] * r + bc * (1 - r)) end
            for j = 12, 15 do term.setPaletteColor(2^j, pal[j][1] * r + bc * (1 - r), pal[j][2] * r + bc * (1 - r), pal[j][3] * r + bc * (1 - r)) end
        end
    elseif PLAYER.order == 39 and PLAYER.row >= 48 then
        local r = math.max(1 - (PLAYER.row - 48) / 7, 0)
        for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * r + bc * (1 - r), pal[j][2] * r + bc * (1 - r), pal[j][3] * r + bc * (1 - r)) end
    end
    local w, h = box.width, box.height
    local ww = floor(h / imgh * imgw)
    local xo = w > ww and floor((w - ww) / 2) or 0
    for y = 1, h do
        local iy = floor((y - 1) * (imgh / h)) + 1
        local wm = iy / (imgh * 1.25) + (1 - 1/1.25)
        for x = 1, ww do
            local ix = floor((x - 1) * (imgw / ww)) + 1
            local c = img[iy][ix]
            if c < 7 --[[and abs((imgh - iy) - ix / 1) <= 192 * wm]] then
                local ly = imgh - iy + (7 - (iy > 75 and math.max(c, 4) or c)) * 4 - 64 * wm
                local tx, ty = floor((ly + ix / 1.25) * rt22 / wm) + i, floor((ix / 1.25 - ly) * rt22 / wm) + 1
                if text[ty] then
                    local t = text[ty][tx]
                    if t and t > 0 then box.canvas[y][x+xo] = (t+11)
                    else box.canvas[y][x+xo] = c end
                else box.canvas[y][x+xo] = c end
            else
                box.canvas[y][x+xo] = c
            end
        end
    end
    box:render()
    sleep(0.05)
end
