local box = require "pixelbox".new(term.current(), 15)
local file = assert(fs.open("srtitle.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 14 do
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
        for i = 0, 14 do
            term.setPaletteColor(2^i, pal[i][1] * p + pal[14][1] * (1 - p), pal[i][2] * p + pal[14][2] * (1 - p), pal[i][3] * p + pal[14][3] * (1 - p))
        end
        sleep(0.05)
    end
end
while PLAYER.order < 3 do sleep(0.25) end
while PLAYER.row < 48 do sleep(0.05) end
while PLAYER.order < 4 do
    local w, h = term.getSize()
    local p = (63 - PLAYER.row) / 15
    local t = (2 * h / 3 - 1) * (1 - p) + 1
    local b = (2 * h / 3 + 1) + (h / 3) * p
    local text, fg, bgb = (" "):rep(w), ("0"):rep(w), ("f"):rep(w)
    for y = 1, t - 1 do
        term.setCursorPos(1, y)
        term.blit(text, fg, bgb)
    end
    for y = b + 1, h + 1 do
        term.setCursorPos(1, y)
        term.blit(text, fg, bgb)
    end
    local ar, ag, ab = term.nativePaletteColor(colors.black)
    local br, bg, bb = term.nativePaletteColor(colors.purple)
    for i = 0, 13 do
        term.setPaletteColor(2^i, pal[i][1] * p + ar * (1 - p), pal[i][2] * p + ag * (1 - p), pal[i][3] * p + ab * (1 - p))
    end
    term.setPaletteColor(2^14, pal[14][1] * p + br * (1 - p) * 0.25, pal[14][2] * p + bg * (1 - p) * 0.25, pal[14][3] * p + bb * (1 - p) * 0.25)
    sleep(0.05)
end