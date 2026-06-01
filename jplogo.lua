local box = require "pixelbox".new(term.current(), 0)
local file = assert(fs.open("jplogo.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 15 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, r / 255, g / 255, b / 255)
    pal[i] = {r / 255, g / 255, b / 255}
end
local imgw, imgh = 320, 240
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
local floor = math.floor
local ys = -1
local yv = 0
local ya = 0
for i = 1, 500 do
    local w, h = box.width, box.height
    local ww = floor(h / imgh * imgw)
    local xo = (w > ww and floor((w - ww) / 2) or 0) + math.max(floor(-i / 10 * w), 0)
    local yo = math.min(floor(ys * h), h)
    local hh = math.min(h - yo, h)
    for y = yo + 1, math.min(yo + h, h) do
        if y >= 1 and y <= h then
            local iy = floor((y - yo - 1) * (imgh / hh)) + 1
            if img[iy] then
                for x = 1, w do
                    local ix = floor((x - xo - 1) * (imgw / ww)) + 1
                    if yo > 0 then
                        ix = ix + floor(math.sin(math.pi * iy / imgh) * math.max(yo / 5, 0) * (w / 2 - ix) / 75)
                    end
                    box.canvas[y][x] = img[iy][ix] or 0
                end
            end
        end
    end
    box:render()
    ya = -math.max(ys, 0) / 20
    yv = yv * 0.97 + (ya + 0.005)
    ys = ys + yv
    --term.setCursorPos(1, 1) print(ys, yv, ya)
    sleep(0.05)
    box:clear(0)
end
