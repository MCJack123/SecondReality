local box = require "pixelbox".new(term.current(), 0)
local file = assert(fs.open("nuts.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 15 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, 255, 255, 255)
    pal[i] = {r / 255, g / 255, b / 255}
end
local imgw, imgh = 320, 400
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
do
    local w, h = box.width, box.height
    local ww = math.floor(h / imgh * (imgw * 2))
    local xo = w > ww and math.floor((w - ww) / 2) or 0
    for y = 1, h do
        local iy = math.floor((y - 1) * (imgh / h)) + 1
        for x = 1, ww do
            local ix = math.floor((x - 1) * (imgw / ww)) + 1
            box.canvas[y][x+xo] = img[iy][ix]
        end
    end
    box:render()
    sleep(0.05)
    for j = 1, 20 do
        local p = j / 20
        for i = 0, 15 do
            term.setPaletteColor(2^i, pal[i][1] * p + pal[14][1] * (1 - p), pal[i][2] * p + pal[14][2] * (1 - p), pal[i][3] * p + pal[14][3] * (1 - p))
        end
        sleep(0.05)
    end
end
while PLAYER.order < 23 do sleep(0.25) end
while PLAYER.row < 12 do sleep(0.05) end
while PLAYER.order < 24 do
    local p = math.max((28 - PLAYER.row) / 16, 0)
    local ar, ag, ab = term.nativePaletteColor(colors.black)
    for i = 0, 15 do
        term.setPaletteColor(2^i, pal[i][1] * p + ar * (1 - p), pal[i][2] * p + ag * (1 - p), pal[i][3] * p + ab * (1 - p))
    end
    sleep(0.05)
end
term.setBackgroundColor(colors.black)
term.clear()