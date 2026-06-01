local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
local h2 = math.floor(h / 2)
local floor, min, max, sin, cos = math.floor, math.min, math.max, math.sin, math.cos
local pi2 = math.pi * 2

local bg = {}
do
    local lastl, lastc = {}, 15
    for x = 1, w do lastl[x] = lastc end
    for y = 1, h2 do bg[y] = lastl end
    for y = h2 + 1, h do
        local c = (min(max(floor(0.4 / ((y - h2) / h)), 0), 7)+8)
        if lastc ~= c then
            local l = {}
            for x = 1, w do l[x] = c end
            lastl, lastc = l, c
        end
        bg[y] = lastl
    end
end

local bc = term.nativePaletteColor(32768)
for i = 8, 14 do term.setPaletteColor(2^i, bc, bc, bc) end
box.canvas = bg
box:render()
repeat sleep(0.05) until not PLAYER or PLAYER.row > 32

for j = 1, 10 do
    for i = 1, 7 do
        local c = bc + (0.25 - bc) * i / 7 * j / 10
        term.setPaletteColor(2^(15-i), c, c, c)
    end
    sleep(0.05)
end
for i = 1, 7 do
    local c = bc + (0.5 - bc) * i / 7
    term.setPaletteColor(2^(8-i), bc, c, c)
end

local bobs = {}
local function render(rot)
    local canvas = {}
    local rc, rs = cos(rot * pi2), sin(rot * pi2)
    for _, v in ipairs(bobs) do
        local vx, vz = v.x * rc + v.z * rs, v.x * -rs + v.z * rc
        do
            local x, y = floor((w / 4) / (vz + 2.5) * vx + w / 2), floor((w / 4) / (vz + 2.5) * (1-v.y) + h2)
            if bg[y] and bg[y][x] then
                canvas[y] = canvas[y] or setmetatable({}, {__index = bg[y]})
                canvas[y][x] = (8-min(max(floor(4 / max(vz + 1, 0)), 1), 7))
            end
        end
        do
            local x, y = floor((w / 4) / (vz + 2.5) * vx + w / 2), floor((w / 4) / (vz + 2.5) + h2)
            if bg[y] and bg[y][x] then
                canvas[y] = canvas[y] or setmetatable({}, {__index = bg[y]})
                canvas[y][x] = bg[y][x] + 1
            end
        end
    end
    box.canvas = setmetatable(canvas, {__index = bg})
    box:render()
end

local startrot
for i = 1, 4000 do
    local b
    if PLAYER then
        if PLAYER.order >= 73 then
            b = vector.new((math.random() - 0.5) * 4, (math.random() - 0.5) * 4, (math.random() - 0.5) * 4)
            b.b = 0.8
            b.v = 0
        elseif PLAYER.order >= 70 then
            local r = sin(i * pi2 / 300) * 0.5 + 0.5
            b = vector.new(cos(i / 2) * r, 0, sin(i / 2) * r)
            b.b = 0.8
            b.v = 4
        elseif PLAYER.order > 68 or (PLAYER.order == 68 and PLAYER.row > 32) then
            b = vector.new(cos(i / 5.5) * 1.5, 0, sin(i / 5.5) * 1.5)
            b.b = 0.9
            b.v = 3.75
        else
            b = vector.new(sin(i / 3 / 3), 1.5 + cos(i / 3 / 4) / 3, -sin(i / 3 / 8))
            b.b = 0.75
            b.v = 0
        end
    else
        b = vector.new(sin(i / 3 / 3), 2, cos(i / 3 / 8))
        b.b = 0.75
        b.v = 0
    end
    bobs[(i - 1) % 300 + 1] = b
    if PLAYER and PLAYER.order >= 74 and (startrot or (sin(i * pi2 / 900) < -0.95 and sin(i * pi2 / 900) > sin((i-1) * pi2 / 900))) then
        if not startrot then startrot = i end
        render(sin(startrot * pi2 / 900) / 2 + ((i - startrot) / 200)^2)
        for _, v in ipairs(bobs) do
            v.y = v.y + v.v * 0.05 / 3
            v.v = v.v - 0.2 * 0.05 / 3
            if v.y < 0 then v.y, v.v = -v.y, -v.v * v.b end
        end
    else
        render(sin(i * pi2 / 900) / 2)
        for _, v in ipairs(bobs) do
            v.y = v.y + v.v * 0.05 / 3
            v.v = v.v - 4 * 0.05 / 3
            if v.y < 0 then v.y, v.v = -v.y, -v.v * v.b end
        end
    end
    if PLAYER and PLAYER.order == 75 then
        if PLAYER.row > 44 then break end
        if PLAYER.row > 32 then
            local r = (PLAYER.row - 32) / 12
            for i = 0, 7 do
                local c = (bc + (0.25 - bc) * i / 7) * (1 - r) + r
                term.setPaletteColor(2^(15-i), c, c, c)
            end
            for i = 1, 7 do
                local c = (bc + (0.5 - bc) * i / 7) * (1 - r) + r
                term.setPaletteColor(2^(8-i), bc * (1 - r) + r, c, c)
            end
        end
    end
    if i % 3 == 0 then sleep(0.05) end
end

term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()
while PLAYER.order == 75 and PLAYER.row < 57 do
    local r = (PLAYER.row - 44) / 12
    local c = bc * r + (1 - r)
    for i = 0, 15 do term.setPaletteColor(2^i, c, c, c) end
    sleep(0.05)
end
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
