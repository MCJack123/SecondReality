local box = require "pixelbox".new(term.current(), 0)
local w, h = box.width, box.height
local bc = term.nativePaletteColor(colors.black)
term.setPaletteColor(2^14, bc, bc, bc)
term.setPaletteColor(2^15, bc, bc, bc)
term.setPaletteColor(2^0, bc, bc, bc)
term.setBackgroundColor(1)
term.clear()

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXabcdefghijklmnopqrstuvwxyz0123456789!?,.:\"()+-*='"
local charwidth = {
    21, 16, 15, 18, 15, 15, 18, 18, 10, 14, 19, 15, 20, 19, 17, 14, 17, 18, 14, 14, 18, 19, 26, 17,
    14, 15, 12, 15, 13, 11, 14, 16, 8, 10, 16, 8, 22, 16, 12, 15, 15, 12, 11, 9, 16, 16, 24, 15, 17, 13,
    15, 10, 13, 14, 15, 14, 14, 13, 12, 14, 4, 13, 5, 4, 4, 11, 9, 9, 10, 10, 11, 10, 8, [" "] = 18
}
local font = {[" "] = {}}
for y = 1, 18 do font[" "][y] = {} end
for i = 1, #chars do font[chars:sub(i, i)], charwidth[chars:sub(i, i)] = {}, charwidth[i] end
local dolby = {}
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
                if v > 0 then l[x] = (v+13) end
                x = 2
            end
            while x <= charwidth[i] do
                c = file.read()
                local v = bit32.rshift(c, 4)
                if v > 0 then l[x] = (v+13) end
                if x + 1 <= charwidth[i] then
                    v = bit32.band(c, 15)
                    if v > 0 then l[x+1] = (v+13) end
                end
                x = x + 2
            end
            if x - 1 == charwidth[i] then c = nil end
        end
    end
    for y = 1, 19 do
        file.seek("set", 0x36 + 12 + 752 * (30 - y) + 507)
        local line = {}
        dolby[y] = line
        for x = 1, 216, 2 do
            local c = file.read()
            line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
        end
    end
    for y = 1, 21 do
        file.seek("set", 0x36 + 12 + 752 * (30 - y) + 615)
        local line = {}
        dolby[y+19] = line
        for x = 0, 216, 2 do
            local c = file.read()
            line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
        end
    end
    file.close()
end

local function measureText(text)
    local width = 0
    for c in text:gmatch "." do width = width + charwidth[c] end
    return width
end

local function drawText(text, img, xo, yo)
    for y = 1, 18, 2 do
        local l, lx = img[yo+(y-1)/2] or {}, xo
        img[yo+(y-1)/2] = l
        for c in text:gmatch "." do
            for x = 1, charwidth[c] do l[lx+x] = font[c][y][x] or l[lx+x] or 0 end
            lx = lx + charwidth[c]
        end
    end
    return img
end

local pendingLines

local function drawLines(lines, img, yo)
    if w < 300 or h < 100 then
        pendingLines = {}
        for i, v in ipairs(lines) do pendingLines[i] = v:gsub(".", "%0 "):gsub(" $", "") end
        return
    end
    local widths = {}
    for i, v in ipairs(lines) do widths[i] = measureText(v) end
    for i, v in ipairs(lines) do
        drawText(v, img, math.floor((w - widths[i]) / 2), yo)
        yo = yo + 19
    end
end

local function postDrawLines()
    if pendingLines then
        term.setTextColor(2^15)
        if pendingLines[1] == "A" then
            term.setCursorPos(math.floor(w / 4) + 1, math.floor(h / 6) - 2)
            term.write("A")
            term.setCursorPos(math.floor((w / 2 - #pendingLines[2]) / 2) + 1, math.floor(h / 6))
            term.write(pendingLines[2])
            term.setCursorPos(math.floor((w / 2 - #pendingLines[3]) / 2) + 1, math.floor(h / 6) + 2)
            term.write(pendingLines[3])
        elseif #pendingLines == 2 then
            term.setCursorPos(math.floor((w / 2 - #pendingLines[1]) / 2) + 1, math.floor(h / 6))
            term.write(pendingLines[1])
            term.setCursorPos(math.floor((w / 2 - #pendingLines[2]) / 2) + 1, math.floor(h / 6) + 2)
            term.write(pendingLines[2])
        else
            term.setCursorPos(math.floor((w / 2 - #pendingLines[1]) / 2) + 1, math.floor(h / 6) - 1)
            term.write(pendingLines[1])
            term.setCursorPos(math.floor((w / 2 - #pendingLines[2]) / 2) + 1, math.floor(h / 6) + 1)
            term.write(pendingLines[2])
            term.setCursorPos(math.floor((w / 2 - #pendingLines[3]) / 2) + 1, math.floor(h / 6) + 3)
            term.write(pendingLines[3])
        end
        pendingLines = nil
    end
end

box:clear(0)
drawLines({"A", "Future Crew", "Production"}, box.canvas, math.floor((h - 33) / 2) - 19)
--for y = 1, h do for x = 1, w do assert(box.canvas[y] and box.canvas[y][x] and box.canvas[y][x] > 0 and box.canvas[y][x] <= 32768, x .. ", " .. y .. " = " .. box.canvas[y][x]) end end
box:render()
postDrawLines()
while PLAYER.order < 3 do sleep(0.25) end
for i = 1, 20 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
while PLAYER.row < 32 do sleep(0.05) end
for i = 19, 1, -1 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
term.setPaletteColor(2^14, bc, bc, bc)
term.setPaletteColor(2^15, bc, bc, bc)

box:clear(0)
drawLines({"First Presented", "at Assembly 93"}, box.canvas, math.floor((h - 33) / 2))
box:render()
postDrawLines()
while PLAYER.order < 4 do sleep(0.25) end
for i = 1, 20 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
while PLAYER.row < 32 do sleep(0.05) end
for i = 19, 1, -1 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
term.setPaletteColor(2^14, bc, bc, bc)
term.setPaletteColor(2^15, bc, bc, bc)

box:clear(0)
if w < 300 or h < 100 then
    term.setTextColor(2^15)
    term.setCursorPos(math.floor(w / 4), math.floor(h / 6) - 1)
    term.write("i n")
    term.setCursorPos(math.floor(w / 4) - 15, math.floor(h / 6))
    term.blit("\x97\x83\x83\x9C" .. ("\x8C"):rep(27) .. "\x93", "000" .. ("f"):rep(28) .. "0", "fff" .. ("0"):rep(28) .. "f")
    term.setCursorPos(math.floor(w / 4) - 15, math.floor(h / 6) + 1)
    term.setTextColor(2^0)
    term.setBackgroundColor(2^15)
    term.write("\x95\x10\x11")
    term.setTextColor(2^15)
    term.setBackgroundColor(2^0)
    term.write("\x95D O L B Y   S U R R O U N D")
    term.blit("\x95", "0", "f")
    term.setCursorPos(math.floor(w / 4) - 15, math.floor(h / 6) + 2)
    term.setTextColor(2^15)
    term.setBackgroundColor(2^0)
    term.write("\x8A\x8F\x8F\x8D" .. ("\x8C"):rep(27) .. "\x8E")
else
    drawText("in", box.canvas, math.floor((w - measureText("in")) / 2), math.floor((h - 20) / 2) - 18)
    do
        local xo, yo = math.floor((w - 216) / 2), math.floor((h - 20) / 2) + 1
        for y = 1, 40, 2 do
            local l = box.canvas[(y-1)/2+yo]
            if l then
                for x = 1, 216 do
                    local c = dolby[y][x]
                    l[x+xo] = c > 0 and c + 13 or 0
                end
            end
        end
    end
    box:render()
end
while PLAYER.order < 5 do sleep(0.25) end
for i = 1, 20 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
while PLAYER.row < 32 do sleep(0.05) end
for i = 19, 1, -1 do
    term.setPaletteColor(2^14, 0.5 * i / 20, 0.5 * i / 20, 0.5 * i / 20)
    term.setPaletteColor(2^15, i / 20, i / 20, i / 20)
    sleep(0.05)
end
term.setPaletteColor(2^14, bc, bc, bc)
term.setPaletteColor(2^15, bc, bc, bc)

do
    local file = assert(fs.open("alku.bmp", "rb"))
    file.seek("set", 0x36)
    local pal = {[14] = {0.5, 0.5, 0.5}, [15] = {1, 1, 1}}
    for i = 0, 13 do
        local b, g, r, _ = file.read(), file.read(), file.read(), file.read()
        --term.setPaletteColor(2^i, r / 255, g / 255, b / 255)
        pal[i] = {r / 255, g / 255, b / 255}
    end
    local imgw, imgh = 320, 200
    local img = {}
    for y = 1, imgh do
        local line = {}
        img[imgh-y+1] = line
        for x = 1, imgw*2, 2 do
            local c = file.read()
            line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
        end
    end
    file.close()
    while PLAYER.row < 48 do sleep(0.05) end
    for k = 0, 320 do
        local ww = math.floor(h / imgh * imgw)
        local xo = w > ww and math.floor((w - ww) / 2) or 0
        for y = 1, h do
            local iy = math.floor((y - 1) * (imgh / h)) + 1
            for x = 1, ww do
                local ix = math.floor((x - 1) * (imgw / ww)) + 1
                box.canvas[y][x+xo] = img[iy][ix+k]
            end
        end
        if k > 80 and k < 110 then
            drawLines({"Graphics", "Marvel", "Pixel"}, box.canvas, math.floor((h - 52) / 2))
            local r = k >= 102 and 1 - (k - 102) / 10 or math.min((k - 80) / 10, 1)
            term.setPaletteColor(2^14, 0.5 * r, 0.5 * r, 0.5 * r)
            term.setPaletteColor(2^15, r, r, r)
        elseif k > 140 and k < 170 then
            drawLines({"Music", "Purple Motion", "Skaven"}, box.canvas, math.floor((h - 52) / 2))
            local r = k >= 162 and 1 - (k - 162) / 10 or math.min((k - 140) / 10, 1)
            term.setPaletteColor(2^14, 0.5 * r, 0.5 * r, 0.5 * r)
            term.setPaletteColor(2^15, r, r, r)
        elseif k > 200 and k < 230 then
            drawLines({"Code", "JackMacWindows", "Psi   Xella"}, box.canvas, math.floor((h - 52) / 2))
            local r = k >= 222 and 1 - (k - 222) / 10 or math.min((k - 200) / 10, 1)
            term.setPaletteColor(2^14, 0.5 * r, 0.5 * r, 0.5 * r)
            term.setPaletteColor(2^15, r, r, r)
        elseif k > 260 and k < 290 then
            drawLines({"Additional Design", "Abyss", "Gore"}, box.canvas, math.floor((h - 52) / 2))
            local r = k >= 282 and 1 - (k - 282) / 10 or math.min((k - 260) / 10, 1)
            term.setPaletteColor(2^14, 0.5 * r, 0.5 * r, 0.5 * r)
            term.setPaletteColor(2^15, r, r, r)
        end
        if k <= 10 then
            local p = k / 10
            for i = 0, 13 do
                term.setPaletteColor(2^i, pal[i][1] * p + bc * (1 - p), pal[i][2] * p + bc * (1 - p), pal[i][3] * p + bc * (1 - p))
            end
        end
        box:render()
        postDrawLines()
        sleep(0.1 + 0.05 * (k % 2))
    end
end
while PLAYER.order < 12 do sleep(0.05) end
while PLAYER.row < 32 do sleep(0.05) end

term.setPaletteColor(colors.black, bc, bc, bc)
do
    local Pine3D = require "Pine3D"
    local visu = require "visu"

    local MODEL_COUNT = 3
    local MODEL_NUMS = {1, 2, 3, 1, 1}
    local COLOR_MAP = {[0] = 6, [4] = 9, [8] = 9, [16] = 9, [32] = 10, [48] = 13, [64] = 4, [80] = 5, [96] = 6, [112] = 7, [128] = 8, [144] = 9}

    local frame = Pine3D.newFrame(1, 1, term.getSize())
    frame.buffer.backgroundColor = nil
    local img = box.canvas
    box.canvas = {}
    for y = 1, #frame.buffer.colorValues do
        local ok = false
        for i = 1, #img[y] do if img[y][i] ~= 0 then ok = true break end end
        if not ok then box.canvas[y] = img[y]
        else box.canvas[y] = setmetatable(frame.buffer.colorValues[y], {__index = img[y]}) end
    end
    frame:setCamera(0, 0, 0, 0, 0, 0)
    local models = {}
    for i = 1, MODEL_COUNT do models[i] = visu.readObject(("SCENE/U2A.%03d"):format(i), COLOR_MAP) end
    local objs = {}
    for i, v in ipairs(MODEL_NUMS) do objs[i] = visu.createObject(frame, models[v]) end
    local anim = visu.readAnimation("SCENE/U2A.0AB")
    local animpos = 1

    local n, start = 0, os.epoch "utc"
    while animpos <= #anim and PLAYER.order < 14 do
        visu.drawFrame(frame, objs)
        box:render()
        frame.buffer:fastClear()
        while n < (os.epoch "utc" - start) * (522 / 11000) do animpos = visu.applyAnimation(frame, objs, anim, animpos) n = n + 1 end
        sleep(0.05)
    end
end
while PLAYER.order < 14 do sleep(0.05) end

do
    local palette = {0x111111, 0x25051C, 0x131424, 0x1C2030, 0x202438, 0x53342B, 0x2A3149, 0x384559, 0x384569, 0x5F5357, 0x435173, 0x9F8070, 0x4E5A87, 0x556890, 0x111111, 0x111111}
    for i = 1, #palette do palette[i] = {bit32.extract(palette[i], 16, 8) / 255, bit32.extract(palette[i], 8, 8) / 255, bit32.extract(palette[i], 0, 8) / 255} end
    local set = {1, 0.6, 0.2, 0, [26] = 0.2, [27] = 0.4, [28] = 0.6, [29] = 0.8, [30] = 1}
    local file = assert(fs.open("prax4.bin", "rb"))
    local imgw, imgh = 320, 200
    for i = 1, 30 do
        local img = {}
        for y = 1, imgh do
            local line = {}
            img[imgh-y+1] = line
            for x = 1, imgw, 2 do
                local c = file.read()
                line[x], line[x+1] = bit32.rshift(c, 4), bit32.band(c, 15)
            end
        end
        local ww = math.floor(h / imgh * imgw)
        local xo = w > ww and math.floor((w - ww) / 2) or 0
        for y = 1, h do
            local iy = math.floor((y - 1) * (imgh / h)) + 1
            for x = 1, ww do
                local ix = math.floor((x - 1) * (imgw / ww)) + 1
                box.canvas[y][x+xo] = img[iy][ix]
            end
        end
        if set[i] then
            local r = set[i]
            for j = 0, 14 do term.setPaletteColor(2^j, palette[j+1][1] * (1 - r) + r, palette[j+1][2] * (1 - r) + r, palette[j+1][3] * (1 - r) + r) end
        end
        box:render()
        sleep(0.1)
    end
end
term.clear()
