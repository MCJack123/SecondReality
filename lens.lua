local box = require "pixelbox".new(term.current(), 0)
local file = assert(fs.open("lenspic8.bmp", "rb"))
file.seek("set", 0x36)
local pal = {}
for i = 0, 7 do
    local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
    term.setPaletteColor(2^i, r / 255, g / 255, b / 255)
    term.setPaletteColor(2^(i+8), r / 255 * 0.75 + 0.1, g / 255 * 0.75 + 0.1, b / 255 * 0.75 + 0.25)
    pal[i] = {r / 255, g / 255, b / 255}
end
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
local pi, pi2 = math.pi, math.pi * 2
local floor, sqrt = math.floor, math.sqrt
local function tri(x) local p = x % pi2 if p >= pi then return (pi2 - p) / pi * 2 - 1 else return p / pi * 2 - 1 end end
local startx, starty
for i = 1, 1000 do
    local w, h = box.width, box.height
    local ww = floor(h / imgh * (imgw))
    local lr = ww / 6
    local lr2 = lr^2
    local ly, lx
    local xtrim = 0
    if PLAYER.order < 41 then
        ly, lx = -100, -100
        if PLAYER.order == 39 then xtrim = 1 - (PLAYER.row - 57) / 8 end
    elseif PLAYER.order == 41 then
        if PLAYER.row >= 48 then
            if not startx then startx = i end
            ly, lx = h - (math.abs(math.cos(pi2 * (PLAYER.row - 48) / 64)) * (h + lr) + lr), (tri(pi2 * (i - startx) / 107) + 1) / 2 * (ww - lr * 2) + lr
        else ly, lx = -100, -100 end
    elseif PLAYER.order < 44 then
        if not starty then starty = i end
        ly, lx = h - (math.abs(math.sin(pi2 * (i - starty) / 57.5)) * (h * 7/8 - lr * 2) + lr), (tri(pi2 * (i - startx) / 107) + 1) / 2 * (ww - lr * 2) + lr
    else
        if PLAYER.order == 44 and PLAYER.row <= 16 then ly, lx = h - (math.sin(pi2 * (i - starty) / 57.5) * (h - lr * 2) + lr), (tri(pi2 * (i - startx) / 107) + 1) / 2 * (ww - lr * 2) + lr
        else ly, lx = -100, 100 end
    end
    --local ly, lx, lr2 = h / 2 + h / 4 + 1, ww / 2 + 5, (ww / 8)^2
    local xo = w > ww and floor((w - ww) / 2) or 0
    for y = 1, h do
        local iy = floor((y - 1) * (imgh / h)) + 1
        local ily = floor((ly - 1) * (imgh / h)) + 1
        for x = 1 + floor(xtrim * (1 - (y / h)) * ww), ww - floor(xtrim * (y / h) * ww) do
            local d2 = (x - lx)^2 + (y - ly)^2
            if d2 < lr2  then
                local ix = floor((lx - 1) * (imgw / ww)) + 1
                local t = math.atan2(y - ly, x - lx)
                local adj = (d2 ^ 0.75) / sqrt(lr)
                local aix, aiy = floor(ix + adj * math.cos(t) + 0.5), floor(ily + adj * math.sin(t) + 0.5)
                box.canvas[y][x+xo] = ((img[aiy] or {})[aix] or 0) + 8
            else
                local ix = floor((x - 1) * (imgw / ww)) + 1
                box.canvas[y][x+xo] = img[iy][ix]
            end
        end
    end
    box:render()
    sleep(0.05)
end