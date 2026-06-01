local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
local r = math.sqrt((w / 2)^2 + (h / 2)^2)
for t = 0, math.pi * 2 - 0.00000001, 1 / r do
    for v = 1, r do
        local x, y = math.floor(v * math.cos(t) + w / 2), math.floor(v * math.sin(t) + h / 2)
        if x >= 1 and x <= w and y >= 1 and y <= h then
            box.canvas[y][x] = (math.floor(v / (w / 100)) % 8)
        end
    end
end
box:render()
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(colors.black)) end
local bc, wc = term.nativePaletteColor(colors.black), term.nativePaletteColor(colors.white)
local cr, cg, cb = term.nativePaletteColor(colors.cyan)
for j = 1, 1000, 2 do
    if PLAYER.order > 18 then break end
    if PLAYER.row <= 32 then
        local r = PLAYER.row / 32
        for i = 0, 15 do
            if i == j % 8 then term.setPaletteColor(2^i, bc * (1 - r) + cr * r, bc * (1 - r) + cg * r, bc * (1 - r) + cb * r)
            else term.setPaletteColor(2^i, bc, bc, bc) end
        end
    else
        local r = math.min(math.max(PLAYER.row / 8 - 4, 0), 1)
        for i = 0, 15 do
            if i == j % 8 then term.setPaletteColor(2^i, cr * (1 - r) + wc * r, cg * (1 - r) + wc * r, cb * (1 - r) + wc * r)
            else term.setPaletteColor(2^i, bc * (1 - r) + wc * r, bc * (1 - r) + wc * r, bc * (1 - r) + wc * r) end
        end
    end
    sleep(0.05)
end
term.setBackgroundColor(colors.black)
term.clear()
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
