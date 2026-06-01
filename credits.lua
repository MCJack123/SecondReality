local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
term.setPaletteColor(2^15, term.nativePaletteColor(2^15))
term.setPaletteColor(2^0, term.nativePaletteColor(2^0))

local font = {} do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/?!:.,\"()+- "
    local file = assert(fs.open("credits-font.bmp", "rb"))
    file.seek("set", 0x3E)
    local img = {}
    for y = 124, 1, -1 do
        local line = {}
        img[y] = line
        for x = 1, 168, 8 do
            local c = file.read()
            for i = 0, 7 do line[x+(7-i)] = bit32.btest(c, 2^i) and 0 or 15 end
        end
        file.read(3) -- align to 4
    end
    file.close()
    for cy = 0, 3 do
        for cx = 0, 13 do
            local cimg = {}
            font[chars:sub(cy * 14 + cx + 1, cy * 14 + cx + 1)] = cimg
            for y = 1, 31 do
                local line = {}
                cimg[y] = line
                for x = 1, 24, 2 do line[x] = img[cy*31+y][cx*12+(x-1)/2+1] line[x+1] = line[x] end
            end
        end
    end
end

local function measureText(text) return #text * 24 - select(2, text:gsub("I", "I")) * 16 end

local function drawText(text, img, xo, yo)
    for y = 1, 31 do
        local l, lx = img[yo+y] or {}, xo
        img[yo+y] = l
        for c in text:gmatch "." do
            for x = 1, (c == "I" and 8 or 24) do l[lx+x] = font[c][y][x] or l[lx+x] or 15 end
            lx = lx + (c == "I" and 8 or 24)
        end
    end
    return img
end

local function drawLines(lines, img, yo)
    local iw = 0
    for _, v in ipairs(lines) do iw = math.max(iw, measureText(v)) end
    for i, v in ipairs(lines) do
        drawText(v, img, math.floor((iw - measureText(v)) / 2), yo)
        yo = yo + 36
    end
    return iw
end

local file = assert(fs.open("credits.txt", "r"))
while true do
    local typ = file.readLine()
    if typ == "!SCROLL" then break end
    local img = {} do
        local imgfile = assert(fs.open("credits-img/" .. typ:sub(2) .. ".bmp", "rb"))
        imgfile.seek("set", 0x36)
        for i = 1, 14 do
            local b, g, r = imgfile.read() / 255, imgfile.read() / 255, imgfile.read() / 255
            term.setPaletteColor(2^i, r, g, b)
            imgfile.read()
        end
        if typ ~= "!PIC02" then imgfile.read(8) end
        for y = 100, 1, -1 do
            local line = {}
            img[y] = line
            for x = 1, 160, 2 do
                local c = imgfile.read()
                line[x], line[x+1] = math.floor(c / 16) + 1, (c % 16) + 1
            end
        end
        imgfile.close()
    end
    local lines = {}
    while true do
        local text = file.readLine()
        if text == "" then break end
        lines[#lines+1] = text
    end
    local textimg = {}
    local textw = drawLines(lines, textimg, #lines > 2 and 0 or 36)
    for i = 10, 0, -1 do
        box:clear(15)
        if w >= 300 and h >= 100 then
            local ww = math.floor(h / 3 / 144 * textw)
            local xo = w > ww and math.floor((w - ww) / 2) or 0
            for y = 1, math.floor(h / 3) do
                local iy = math.floor((y - 1) * (144 / (h / 3))) + 1
                local cy = y+math.ceil(h/2+h/12+h/24)+math.floor((i/10)^2*(h/2-h/12-h/24))
                if box.canvas[cy] and textimg[iy] then
                    for x = 1, ww do
                        local ix = math.floor((x - 1) * (textw / ww)) + 1
                        box.canvas[cy][x+xo] = textimg[iy][ix] or 15
                    end
                end
            end
        end
        do
            local ww = math.floor(h / 2 / 100 * 160)
            local xo = w > ww and math.floor((w - ww) / 2) or 0
            for y = 1, math.floor(h / 2) do
                local iy = math.floor((y - 1) * (100 / (h / 2))) + 1
                local cy = y+math.ceil(h/24)
                local xo = xo + math.floor((i/10)^2*(w/2))
                if box.canvas[cy] and img[iy] then
                    for x = 1, ww do
                        local ix = math.floor((x - 1) * (160 / ww)) + 1
                        box.canvas[cy][x+xo] = img[iy][ix] or 15
                    end
                end
            end
        end
        box:render()
        if w < 300 or h < 100 then
            local yo = math.ceil(h / 3 / 2 + h / 3 / 12 + h / 3 / 24 + (#lines > 2 and -1 or 0)) + math.floor((i/10)^2*(h/3/2-h/3/12-h/3/24)) + 2
            term.setTextColor(colors.white)
            for y, v in ipairs(lines) do
                term.setCursorPos(math.floor((w / 2 - #v) / 2) + 1, y + yo)
                term.write(v)
            end
        end
        sleep(0.05)
    end
    sleep(4)
    for i = 0, 10 do
        box:clear(15)
        if w >= 300 and h >= 100 then
            local ww = math.floor(h / 3 / 144 * textw)
            local xo = w > ww and math.floor((w - ww) / 2) or 0
            for y = 1, math.floor(h / 3) do
                local iy = math.floor((y - 1) * (144 / math.floor(h / 3))) + 1
                local cy = y+math.ceil(h/2+h/12+h/24)+math.floor((i/10)^2*(h/2-h/12-h/24))
                if box.canvas[cy] and textimg[iy] then
                    for x = 1, ww do
                        local ix = math.floor((x - 1) * (textw / ww)) + 1
                        box.canvas[cy][x+xo] = textimg[iy][ix] or 15
                    end
                end
            end
        end
        do
            local ww = math.floor(h / 2 / 100 * 160)
            local xo = w > ww and math.floor((w - ww) / 2) or 0
            for y = 1, math.floor(h / 2) do
                local iy = math.floor((y - 1) * (100 / (h / 2))) + 1
                local cy = y+math.ceil(h/24)
                local xo = xo - math.floor((i/10)^2*(w/2+ww/2))
                if box.canvas[cy] and img[iy] then
                    for x = 1, ww do
                        local ix = math.floor((x - 1) * (160 / ww)) + 1
                        box.canvas[cy][x+xo] = img[iy][ix] or 15
                    end
                end
            end
        end
        box:render()
        if w < 300 or h < 100 then
            local yo = math.ceil(h / 3 / 2 + h / 3 / 12 + h / 3 / 24 + (#lines > 2 and -1 or 0)) + math.floor((i/10)^2*(h/3/2-h/3/12-h/3/24)) + 2
            term.setTextColor(colors.white)
            for y, v in ipairs(lines) do
                term.setCursorPos(math.floor((w / 2 - #v) / 2) + 1, y + yo)
                term.write(v)
            end
        end
        sleep(0.05)
    end
    sleep(0.25)
end

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXabcdefghijklmnopqrstuvwxyz0123456789!?,.:\"()+-*='"
local charwidth = {
    21, 16, 15, 18, 15, 15, 18, 18, 10, 14, 19, 15, 20, 19, 17, 14, 17, 18, 14, 14, 18, 19, 26, 17,
    14, 15, 12, 15, 13, 11, 14, 16, 8, 10, 16, 8, 22, 16, 12, 15, 15, 12, 11, 9, 16, 16, 24, 15, 17, 13,
    15, 10, 13, 14, 15, 14, 14, 13, 12, 14, 4, 13, 5, 4, 4, 11, 9, 9, 10, 10, 11, 10, 8, [" "] = 18
}
local font = {[" "] = {}}
for y = 1, 18 do font[" "][y] = {} end
for i = 1, #chars do font[chars:sub(i, i)], charwidth[chars:sub(i, i)] = {}, charwidth[i] end
do
    local file = assert(fs.open("font.bmp", "rb"))
    for y = 1, 18 do
        file.seek("set", 0x36 + 12 + 752 * (30 - y))
        local c
        for i = 1, #chars do
            local l, x = {}, 1
            font[chars:sub(i, i)][y] = l
            if c then
                local v = bit32.band(c, 15)
                if v > 0 then l[x] = 2-v end
                x = 2
            end
            while x <= charwidth[i] do
                c = file.read()
                local v = bit32.rshift(c, 4)
                if v > 0 then l[x] = 2-v end
                if x + 1 <= charwidth[i] then
                    v = bit32.band(c, 15)
                    if v > 0 then l[x+1] = 2-v end
                end
                x = x + 2
            end
            if x - 1 == charwidth[i] then c = nil end
        end
    end
    file.close()
end

local function measureText(text)
    local width = 0
    for c in text:gmatch "." do width = width + math.ceil(charwidth[c] / 2) end
    return width
end

local function drawText(text, img, xo, yo)
    for y = 1, 18, 2 do
        local l, lx = img[yo+(y-1)/2+1] or {}, xo
        img[yo+(y-1)/2+1] = l
        for c in text:gmatch "." do
            for x = 1, charwidth[c], 2 do l[lx+(x-1)/2+1] = font[c][y][x] or l[lx+(x-1)/2+1] or 15 end
            lx = lx + math.ceil(charwidth[c] / 2)
        end
    end
    return img
end

local pendingLines

local function drawLines(lines, img, yo)
    if w < 300 or h < 100 then
        pendingLines = lines
        return
    end
    local widths = {}
    for i, v in ipairs(lines) do widths[i] = measureText(v) end
    for i, v in ipairs(lines) do
        drawText(v, img, math.floor((w - widths[i]) / 2), yo)
        yo = yo + 15
    end
end

local function postDrawLines()
    if pendingLines then
        term.setTextColor(1)
        for i, line in ipairs(pendingLines) do
            term.setCursorPos(math.floor((w / 2 - #line) / 2) + 1, i)
            term.write(line)
        end
    end
end

local lines = {}
for line in file.readLine do lines[#lines+1] = line end
file.close()
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
term.setPaletteColor(2^1, term.nativePaletteColor(colors.lightGray))
if term.getGraphicsMode and term.getGraphicsMode() then term.setGraphicsMode(false) end -- windows don't support GFX
local scrollwin = window.create(term.current(), 1, h / 3, w / 2, math.ceil(#lines * 15 / 3))
local scrollbox = require "pixelbox".new(scrollwin, 15)
drawLines(lines, scrollbox.canvas, 0)
scrollbox:render()
local old = term.redirect(scrollwin)
postDrawLines()
term.redirect(old)
scrollwin.setVisible(true)
for y = h / 3, -math.ceil(#lines * ((w < 300 or h < 100) and 1 or 15) / 3), -1 do
    scrollwin.reposition(1, y)
    sleep(0.05 * (h / 50) * (pendingLines and 15 or 1))
end
term.setPaletteColor(2^1, term.nativePaletteColor(2^1))
term.setCursorPos(1, 1)
