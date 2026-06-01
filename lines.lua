local floor, sin, cos, min, max, pi, abs, tan = math.floor, math.sin, math.cos, math.min, math.max, math.pi, math.abs, math.tan
local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
local w2, h2, h10, pi2, pih = w / 2 + 1, h / 2 + 1, h / 10, pi * 2, pi / 2
local bc, wc = term.nativePaletteColor(colors.black), term.nativePaletteColor(colors.white)
for i = 0, 14 do
    local c = bc * i / 15 + wc * (1 - i / 15)
    term.setPaletteColor(2^i, c, c, c)
end

local lines = {{stretch = 1, stretchr = 0, rot = 0, roti = 0, start = 1, bounce = true}}
local p = 1
local lastRow = PLAYER.row % 8
local mode = 0
local istart = 0
for i = 1, 800 do
    if PLAYER.order == 31 and PLAYER.row > 52 then break end
    box:clear(15)
    -- for j, v in ipairs(lines) do
    --     box.canvas = util.mode7(img, 7.5, 1, w / -2, h / -2, w, h, 0x8000, box.canvas, util.rotate(math.pi * 2 * (i / 200)^4 + (v.rot * (1 + (i / 200)^4)), util.scale(1 / (v.stretch * w / 32 * (((i + j) / 5 % 1) / 40 + 1)), 1, util.base())))
    -- end
    local rot, xycoeff = (i / 111) + pi / 8, (-sin(i / ((800 - i) / 150)^2) / (4 - i / 200) * (mode / 6) + 0.75) / h10
    if mode == 6 then rot = (i / 111)^4 + pi / 8
    elseif mode == 7 then rot, xycoeff = ((i - istart) / 50)^4 - 1 / 8, (-cos(i / ((800 - i + istart) / 200)^2) / (2 - (i - istart) / 400) + 0.75) / h10 end
    local rot1, rotpi = 1 + rot, pi2 * -rot + pih
    for j, v in ipairs(lines) do
        local t = rotpi + (v.rot * rot1 + v.roti * (i - v.start))
        local st, ct = sin(t), cos(t)
        local m = st / ct
        local sr = (ct + m * st)
        local ss = v.bounce and (i + j) * 1.25182352 % 2 or 1
        if ss > 1 then ss = 2 - ss end
        local s = v.stretch * (ss / 5 + 1) + v.stretchr * ct
        v.sr, v.m, v.s = sr, m, s
    end
    local xadd, yadd
    if mode == 7 then xadd, yadd = w2 + cos(i / 5) * (i / 200)^2 * (w / 50), h2 + sin(i / 5) * (i / 200)^2 * (w / 50)
    else xadd, yadd = w2, h2 end
    local xo = PLAYER.order == 31 and PLAYER.row > 32 and floor(((PLAYER.row - 32) / 16)^3 * w) or 0
    for y = 1, h do
        local line = box.canvas[y]
        local uy = (y - yadd) * xycoeff
        for x = 1, w do
            local ux = (x - xadd) * xycoeff
            local c = 15
            for j = 1, #lines do
                local v = lines[j]
                local d = uy - v.m * ux
                if d < 0 then d = -d end
                local sr = v.sr
                if sr > 0 then d = d + sr / 4
                else d = d - sr / 4 end
                local e = v.s * sr
                if e < 0 then e = -e end
                if d < 5 * e and d % e < e / 2 then c = c - 3 end
            end
            line[x+xo] = c
        end
    end
    box:render()
    if PLAYER.row % 8 < lastRow then p = 1 end
    lastRow = PLAYER.row % 8
    if p >= 0 then
        for i = 0, 14 do
            local c = bc * i / 15 + wc * (1 - i / 15)
            term.setPaletteColor(2^i, c, c * (7 + (2 - 2 * p)) / 9, c * (7 + (1 - p)) / 8)
        end
        p = p - 0.25
    end
    if #lines < 5 then
        lines[#lines+1] = {stretch = i / 16 + 1, stretchr = 0, rot = pi / 64 * floor(i / 2) * (i % 2 == 0 and -1 or 1), roti = 0, start = 1, bounce = true}
    end
    if mode == 0 then
        if PLAYER.order == 25 and PLAYER.row >= 32 then
            mode = 1
            lines[mode] = {stretch = 1, stretchr = 1, rot = mode * pi / 64, roti = -(1 / 24 + mode / 64), start = i}
        end
    elseif mode < 5 then
        mode = mode + 1
        lines[mode] = {stretch = 1, stretchr = 1, rot = mode * pi / 64, roti = -(1 / 24 + mode / 64), start = i}
    elseif mode == 5 and PLAYER.order == 26 and PLAYER.row > 24 and PLAYER.row < 40 then
        for _, v in ipairs(lines) do v.stretchr, v.roti = 0, v.roti * 2 end
        mode = 6
    elseif mode == 6 and PLAYER.order == 29 then
        for j = 1, 5 do
            lines[j] = {stretch = 1, stretchr = 0, rot = pi / 32 * floor(j / 2) * (j % 2 == 0 and -1 or 1), roti = -(1 / 24 + mode / 64), start = i}
        end
        istart = i
        mode = 7
    end
    sleep(0.05)
end
