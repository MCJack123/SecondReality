local box = require "pixelbox".new(term.current(), 0)
local file = assert(fs.open("panicpic.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 15 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, r / 255, g / 255, b / 255)
    pal[i] = {r / 255, g / 255, b / 255}
end
local bc = term.nativePaletteColor(colors.black)
term.setPaletteColor(1, bc, bc, bc)
pal[0] = {bc, bc, bc}
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
local sinc = {[0] = 0, 0.25, 0.1, 0.15, 0.05, 0}
for i = -10, 5 do
    local w, h = box.width, box.height
    local ww = floor(h / imgh * imgw)
    local xo = (w > ww and floor((w - ww) / 2) or 0) + math.max(floor(-i / 10 * w), 0)
    if i >= 0 then
        local r = (5 - i) / 5
        for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * (1 - r) + r, pal[j][2] * (1 - r) + r, pal[j][3] * (1 - r) + r) end
        xo = xo + floor(w * sinc[i] / 4)
    end
    for y = 1, h do
        local iy = floor((y - 1) * (imgh / h)) + 1
        for x = 1, ww do
            local ix = floor((x - 1) * (imgw / ww)) + 1
            box.canvas[y][x+xo] = img[iy][ix]
        end
    end
    box:render()
    sleep(0.05)
    box:clear(0)
end
while PLAYER.order < 34 do sleep(0.1) end
--sleep(1)
local p = 1
while p >= 0.0625 do
    local w, h = box.width, box.height
    local ww = floor(h / imgh * imgw)
    local hh = floor(h * p)
    local xo = (w > ww and floor((w - ww) / 2) or 0)
    local b = floor((h - hh) / 2)
    for y = b + 1, b + hh do
        local iy = floor((y - b - 1) * (imgh / hh)) + 1
        for x = 1, ww do
            local ix = floor((x - 1) * (imgw / ww)) + 1
            box.canvas[y][x+xo] = img[iy][ix]
        end
    end
    box:render()
    sleep(0.05)
    box:clear(0)
    local ar, ag, ab = term.nativePaletteColor(colors.white)
    for i = 1, 15 do
        term.setPaletteColor(2^i, pal[i][1] * p + ar * (1 - p), pal[i][2] * p + ag * (1 - p), pal[i][3] * p + ab * (1 - p))
    end
    sleep(0.05)
    p = p / 2
end
local w, h = term.getSize()
local w2 = floor(h / imgh * imgw)
term.setBackgroundColor(1)
term.clear()
for i = 1, 20 do
    local ww = floor(w2 / i)
    term.setCursorPos(floor((w - ww) / 2) + 1, floor(h / 2) + 1)
    term.setBackgroundColor(1)
    term.clearLine()
    term.setBackgroundColor(2)
    term.write((" "):rep(ww))
    sleep(0.05)
end
term.setBackgroundColor(1)
term.clear()
