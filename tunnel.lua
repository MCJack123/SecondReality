local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
local bc, wc = term.nativePaletteColor(colors.black), term.nativePaletteColor(colors.white)
for i = 0, 14 do
    local r = (15 - i) / 15
    local c = bc + (wc - bc) * r
    term.setPaletteColor(2^i, c, c, c)
end
local circles = {}
for i = 1, 1000 do
    if PLAYER and PLAYER.order == 18 then break end
    local circle
    local speed = i / (3200 / w)
    circle = {pos = vector.new(w / 2 + math.sin(2 * math.pi * i / (16 / (i / 8000 + 1))) * speed * (w / h), h / 2 + math.sin(2 * math.pi * i / 23) * speed), r = h / 3, o = math.sin(2 * math.pi * i / 8)}
    table.insert(circles, 1, circle)
    if #circles > 32 then circles[#circles] = nil end
    box:clear(15)
    for j, v in ipairs(circles) do
        for t = 0, math.pi * 2 - 0.0000001, math.pi * 2 / (h / 3) do
            local x = math.floor((v.r + v.o * 2 + j * w / 80) * math.cos(t) + v.pos.x)
            local y = math.floor((v.r + v.o * 2 + j * w / 80) * math.sin(t) + v.pos.y)
            if x >= 1 and x <= w and y >= 1 and y <= h then
                if j > 15 then box.canvas[y][x] = math.floor(v.o * 4 + 4)
                else box.canvas[y][x] = (15-j) end
            end
        end
    end
    if PLAYER and PLAYER.order == 17 and PLAYER.row >= 48 then
        for i = 0, 14 do
            local r = (15 - i) / 15 * (63 - PLAYER.row) / 15
            local c = bc + (wc - bc) * r
            term.setPaletteColor(2^i, c, c, c)
        end
    end
    box:render()
    sleep(0.05)
end
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
