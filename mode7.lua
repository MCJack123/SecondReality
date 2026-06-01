local pixelbox = require "pixelbox"
local util = require "util"
local fps = jit and config and config.get("clockSpeed") or 20

local pi, pi2 = math.pi, math.pi * 2
local floor, sin, cos = math.floor, math.sin, math.cos

local file = assert(fs.open("lenspic.bmp", "rb"))
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
    for i = 0, 16*imgh, imgh do img[imgh-y+1+i] = line end
    for x = 1, imgw, 2 do
        local c = file.read()
        local a, b = bit32.rshift(c, 4), bit32.band(c, 15)
        for i = 0, 16*imgw, imgw do line[x+i], line[x+i+1] = a, b end
    end
end
file.close()

util.tile(img, imgw, imgh)
local px = pixelbox.new(term.current(), 15)
local w, h = px.width, px.height

local i = 1
local rs = h / imgh
local slock
while i <= 4001 do
    local rstart = os.epoch "utc"
    local th = 2 * math.pi * (i / 1600)
    local scale = 1 + (i / 1600)^4
    local s = (-sin(th * 1.5) / 2 * scale + 1) / rs
    if PLAYER.order == 45 and PLAYER.row <= 16 then
        local r = math.min(PLAYER.row / 8, 1)
        local wc = term.nativePaletteColor(colors.white)
        for j = 0, 15 do
            term.setPaletteColor(2^j, pal[j][1] * r + wc * (1 - r), pal[j][2] * r + wc * (1 - r), pal[j][3] * r + wc * (1 - r))
        end
    elseif PLAYER.order >= 46 and PLAYER.order <= 48 then
        if not slock then slock = s end
        s = slock
    elseif slock then
        if math.abs(s - slock) < 0.05 then slock = nil
        else s = slock end
    elseif PLAYER.order == 52 and PLAYER.row > 32 then
        local r = math.max(1 - (PLAYER.row - 32) / 16, 0)
        local wc = term.nativePaletteColor(colors.white)
        for j = 0, 15 do
            term.setPaletteColor(2^j, pal[j][1] * r + wc * (1 - r), pal[j][2] * r + wc * (1 - r), pal[j][3] * r + wc * (1 - r))
        end
    elseif PLAYER.order == 53 then break end
    px.canvas = util.mode7(img, 8*imgw, 8*imgh, 8*imgw, 8*imgh, w, h, 15, nil, util.rotate(-th * (i / 1600), util.scale(s, s, util.base())))
    --local pstart = os.epoch "nano"
    px:render()
    --local ptime = os.epoch "nano" - pstart
    local t = (os.epoch "utc" - rstart)
    --term.setCursorPos(1, 1)
    --print(t, ptime / 1000)
    sleep(math.max(1 / fps - t / 1000, 0))
    i = i + (os.epoch "utc" - rstart) / 10
end
term.clear()
