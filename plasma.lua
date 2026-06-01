package.path = package.path .. ";/lib/?.lua"
local box = require "pixelbox".new(term.current(), 15)
local sel = tonumber(...)
local random, mmin, mmax, floor = math.random, math.min, math.max, math.floor
local w, h = box.width, box.height
local e = select(2, math.frexp(math.max(w, h)))
local size = 2^e
local map = {{}}
map[1][1] = 0.00 --math.random()
map[1][size+1] = 0.25 --math.random()
map[size+1] = {}
map[size+1][1] = 0.50 --math.random()
map[size+1][size+1] = 0.75 --math.random()
local min, max = math.huge, -math.huge
for i = 0, e-1 do
    local exp = 2^(e-i)
    local hexp = exp / 2
    -- diamond
    for y = 1, size, exp do
        local by = y + exp
        local ly, lby = map[y], map[by]
        local lhy = map[y + hexp] or {}
        map[y + hexp] = lhy
        for x = 1, size, exp do
            local bx = x + exp
            local c = (ly[x] + ly[bx] + lby[x] + lby[bx]) / 4 + (random() - 0.5) * 0.58^i
            lhy[x + hexp] = c
            if c < min then min = c end
            if c > max then max = c end
        end
    end
    -- square
    for y = 1, size + 1, hexp do
        local r0 = map[y-hexp] or {}
        local r1 = map[y] or {}
        local r2 = map[y+hexp] or {}
        map[y] = r1
        for x = (y % exp == 1) and hexp+1 or 1, size + 1, exp do
            local c = ((r0[x] or 0) + (r2[x] or 0) + (r1[x-hexp] or 0) + (r1[x+hexp] or 0)) / 4 + (random() - 0.5) * 0.58^i
            r1[x] = c
            if c < min then min = c end
            if c > max then max = c end
        end
    end
end
--term.clear()
--term.setCursorPos(1, 1)
if sel > 1 then for i = 0, 14 do term.setPaletteColor(2^i, term.nativePaletteColor(colors.black)) end end
local range = 15 / (max - min)
-- [[
local buf = box.canvas
local err = {{}}
for y = 1, size + 1 do
    local c = {}
    local errl, errl1 = err[y], {}
    err[y+1] = errl1
    local l = map[y]
    for x = 1, size + 1 do
        local v = (l[x] - min) * range + (errl[x] or 0)
        local adj = (mmax(mmin(floor(v), 14), 0))
        local qe = v - adj
        c[x] = adj
        errl[x+1] = (errl[x+1] or 0) + qe * 7 / 16
        errl1[x-1] = (errl1[x-1] or 0) + qe * 3 / 16
        errl1[x] = (errl1[x] or 0) + qe * 5 / 16
        errl1[x+1] = (errl1[x+1] or 0) + qe * 1 / 16
    end
    buf[y] = c
end
box:render()
--[=[]]
for y = 1, size + 1 do
    local c = ""
    for x = 1, size + 1 do
        c = c .. ("%x"):format(math.max(math.min(math.floor((map[y][x] - min) * range), 15), 0))
    end
    term.setCursorPos(1, y)
    term.blit((" "):rep(size + 1), ("0"):rep(size + 1), c)
end
--]=]
--time = time - (os.epoch "utc" - start) / 1000
local base, intensity = 0.4, 0.4
term.setBackgroundColor(colors.black)
local bc = term.nativePaletteColor(colors.black)
term.setPaletteColor(colors.black, bc, bc, bc)
local dropidx = {54, 56, 57}
for i = 1, 2000 do
    for j = 0, 14 do
        local xx = (i / 100 + j / 14) % 1
        local r, g, b
        if sel == 1 then
            r = (math.max(math.abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base
            g = 0
            b = (math.max(1 - math.abs(3.0*xx - 2), 0.0)) * intensity + base
            if i < 40 then
                r, g, b = r * (i / 40) + (1 - i / 40), (1 - i / 40), b * (i / 40) + (1 - i / 40)
            end
        elseif sel == 2 then
            r = (math.max(math.abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base
            g = (math.max(1 - math.abs(3.0*xx - 1), 0.0)) * intensity + base
            b = (math.max(1 - math.abs(3.0*xx - 2), 0.0)) * intensity + base
            if i < 10 then
                r, g, b = r * (i / 10) + bc * (1 - i / 10), g * (i / 10) + bc * (1 - i / 10), b * (i / 10) + bc * (1 - i / 10)
            end
        else
            if xx >= 0.5 then r, g, b = 1 - xx + 0.2, 1 - xx + 0.2, 1 - xx + 0.2
            else r, g, b = xx + 0.2, xx + 0.2, xx + 0.2 end
            if i < 10 then
                r, g, b = r * (i / 10) + bc * (1 - i / 10), g * (i / 10) + bc * (1 - i / 10), b * (i / 10) + bc * (1 - i / 10)
            end
        end
        term.setPaletteColor(2^j, r, g, b)
    end
    if PLAYER.order == dropidx[sel] and PLAYER.row > 56 then term.scroll(math.floor(-h / 64 * (PLAYER.row - 56) / 2)) end
    sleep(0.05)
    --if (os.epoch "utc" - start) / 1000 > time then break end
end
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()