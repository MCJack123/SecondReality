local pixelbox = require "pixelbox"
local fps = jit and config and config.get("clockSpeed") or 20
for i = 0, 7 do term.setPaletteColor(2^i, 1 - i / 7, 1 - i / 7, 1 - i / 7) end
for i = 8, 15 do term.setPaletteColor(2^i, (i - 8) / 7, (i - 8) / 9, (i - 8) / 9) end
--for y = 0, 15 do term.setCursorPos(1, y + 1) term.setBackgroundColor(2^y) term.clearLine() end sleep(2)
local px = pixelbox.new(term.current())
--[[px.distances[1] = {3, 2, 4, 8}
px.distances[2] = {4, 1, 4, 8, 16}
px.distances[4] = {5, 2, 8, 1, 16, 32}
for i = 3, 12 do px.distances[2^i] = {6, 2^(i-1), 2^(i+1), 2^(i-2), 2^(i+2), 2^(i-3), 2^(i+3)} end
px.distances[8192] = {5, 4096, 16384, 2048, 32768, 1024}
px.distances[16384] = {4, 8192, 32768, 4096, 2048}
px.distances[32768] = {3, 16384, 8192, 4096}]]
local floor, sqrt, sin, cos, pi, pi2, min, max = math.floor, math.sqrt, math.sin, math.cos, math.pi, math.pi * 2, math.min, math.max
local w, h = px.width, px.height
local function tri(x) local p = x % pi2 if p >= pi then return (pi2 - p) / pi * 2 - 1 else return p / pi * 2 - 1 end end
local function dtr(x) return min(max(tri(x) * 2, -1), 1) end
local function sqr(x) local p = x % pi2 if p >= pi then return 1 else return -1 end end
local function ssq(x) return sin(x) + sin(x * 3) / 3 + sin(x * 5) / 5 end
local cx1, cy1, cr1, cp1 = floor(w / 2), floor(h / 2), floor(w / 4 + 2), 57
local cx2, cy2, cr2, cp2 = floor(w / 2), floor(h / 2), floor(w / 4 + 2), 49
local bw = w / 150
local bw2 = bw / 1.5
local wc = term.nativePaletteColor(colors.white)
local pi3h = pi * 3 / h
local function fade(x)
    local r = 1
    if PLAYER.order == 22 and PLAYER.row >= 32 then r = math.max((47 - PLAYER.row) / 15, 0) end
    return x * r + wc * (1 - r)
end
--term.setGraphicsMode(1)
local screen = px.canvas
local start = os.epoch "utc"
local iter = 1
local emistart
while iter <= 2000 do
    if PLAYER and PLAYER.order > 22 then break end
    local rstart = os.epoch "utc"
    local ifac = pi2 * iter
    local ifac1, ifac2 = ifac / cp1, ifac / cp2 + math.pi
    local x1, y1 = cx1 + floor(cr1 * cos(ifac1)), cy1 + floor(cr2 * sin(ifac1))
    local x2, y2 = cx2 + floor(cr2 * cos(ifac2)), cy2 + floor(cr1 * sin(ifac2))
    if not emistart and (math.abs(x2 - x1) < 10 and math.abs(y2 - y1) < 10) then emistart = iter end
    local x2mc = (iter - (emistart or iter)) * bw / 20
    for y = 1, h do
        local t = screen[y]
        local x2m = x2 + x2mc * sin(pi3h * y)
        for x = 1, w do
            local r1 = sqrt((x - x1)^2 + (y - y1)^2) / bw % 8
            local r2 = sqrt((x - x2m)^2 + (y - y2)^2) / bw2 % 16 > 7 and 8 or 0
            --t[x] = string.char(floor(((r1 + r2) + 2) * 3.75))
            t[x] = floor((r1 + r2) % 16)
        end
        --screen[y] = table.concat(t)
    end
    --term.drawPixels(0, 0, screen)
    px:render()
    for i = 0, 7 do term.setPaletteColor(2^i, fade(1 - (i - iter) % 7 / 7), fade(1 - (i - iter) % 7 / 7), fade(1 - (i - iter) % 7 / 7)) end
    for i = 8, 15 do term.setPaletteColor(2^i, fade((i - 8 - iter) % 7 / 7), fade((i - 8 - iter) % 7 / 9), fade((i - 8 - iter) % 7 / 8)) end
    sleep(math.max(1 / fps - (os.epoch "utc" - rstart) / 1000, 0))
    iter = iter + (os.epoch "utc" - rstart) / 40
end
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
--term.setGraphicsMode(0)
term.setBackgroundColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
