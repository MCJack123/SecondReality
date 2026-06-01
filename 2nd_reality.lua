local libtracc = require "libtracc"
libtracc.interpolation = jit and "linear" or "none"
local loop = require "taskmaster"()

local speaker = peripheral.find "speaker"
if not speaker then error("Please attach a speaker.") end
local stereo = peripheral.isPresent("left") and peripheral.isPresent("right")
local file = assert(fs.open("2ND_PM_pack.s3m", "rb"))
local xm = libtracc.readS3MFile(file)
file.close()
file = assert(fs.open("2ND_SK_pack.s3m", "rb"))
local skxm = libtracc.readS3MFile(file)
file.close()
xm.loop, skxm.loop = false, false
if select(2, ...) and term.getGraphicsMode then _G.USE_GFX = true else _G.USE_GFX = nil end

local function clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(false)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
end

local function getSpeakers()
    if stereo and peripheral.isPresent("left") and peripheral.isPresent("right") and peripheral.hasType("left", "speaker") and peripheral.hasType("right", "speaker") then
        -- CraftOS-PC hack
        pcall(peripheral.call, "left", "setPosition", 1, 0, 0)
        pcall(peripheral.call, "right", "setPosition", -1, 0, 0)
        return peripheral.wrap "left", peripheral.wrap "right"
    else return peripheral.find "speaker" end
end

local exit = false
local function exitListener()
    repeat local event, key = os.pullEvent() until event == "char" or (event == "key" and key == keys.enter)
    local pal = {}
    for i = 0, 15 do pal[i] = {term.getPaletteColor(2^i)} end
    local bc = term.nativePaletteColor(2^15)
    local gv = _G.PLAYER and _G.PLAYER.globalVolume
    for i = 1, 20 do
        local p = i / 20
        for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * (1 - p) + bc * p, pal[j][2] * (1 - p) + bc * p, pal[j][3] * (1 - p) + bc * p) end
        if _G.PLAYER then _G.PLAYER.globalVolume = gv * (1-p)^2 end
        sleep(0.05)
    end
    exit = true
    loop:stop()
end

local function finish()
    if term.getGraphicsMode and term.getGraphicsMode() then term.setGraphicsMode(false) end
    for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    local w, h = term.getSize()
    term.setTextColor(colors.gray)
    term.write("\x9C" .. ("\x8C"):rep(w - 2))
    term.blit("\x93", "f", "7")
    term.setCursorPos(1, 2)
    term.blit("\x95  S E C O N D   R E A L I T Y", "777333333333333333333333333333", "ffffffffffffffffffffffffffffff")
    term.setCursorPos(w, 2)
    term.blit("\x95", "f", "7")
    term.setCursorPos(1, 3)
    term.blit("\x95", "7", "f")
    term.setCursorPos(w - 32, 3)
    term.blit("Copyright (C) 1993 Future Crew  \x95", "9999999999999999999333333333333ff", "ffffffffffffffffffffffffffffffff7")
    term.setCursorPos(1, 4)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.gray)
    term.write("\x9D" .. ("\x8C"):rep(w - 2))
    term.blit("\x91", "f", "7")
    local win = window.create(term.current(), 4, 5, w - 8, h, false)
    local old = term.redirect(win)
    term.setTextColor(colors.blue)
    local lines = print[[This demonstration is licensed under the MIT license. Copyright (C) 2025-2026 JackMacWindows. All image/3D/sound assets are copyright (C) 1993 Future Crew, and are released into the public domain under the Unlicense.]]
    term.redirect(old)
    win.reposition(4, 5, w - 8, lines)
    win.setVisible(true)
    for y = 5, 4 + lines do
        term.setCursorPos(1, y)
        term.blit("\x95", "7", "f")
        term.setCursorPos(w, y)
        term.blit("\x95", "f", "7")
    end
    term.setCursorPos(1, 5 + lines)
    term.setTextColor(colors.gray)
    term.setBackgroundColor(colors.black)
    term.write("\x8D" .. ("\x8C"):rep(w - 2) .. "\x8E")
    term.setTextColor(colors.white)
    term.setCursorPos(1, 7 + lines)
end

local parts = {
    {name = "srtitle", order = 4, noclear = true},
    {name = "glenz", order = 14},
    {name = "tunnel", order = 18},
    {name = "rings", order = 19},
    {name = "interference", order = 23, noclear = true},
    {name = "getdown", order = 24, noclear = true},
    {name = "lines", order = 31, row = 56},
    {name = "panicpic", order = 36},
    {name = "forest", order = 39, row = 57},
    {name = "lens", order = 45},
    {name = "mode7", order = 53},
    {name = "plasma 1", order = 55, noclear = true},
    {name = "plasma 2", order = 57},
    {name = "plasma 3", order = 58},
    {name = "plasmacube", order = 66},
    {name = "bobs", order = 76},
    {name = "water", order = 80},
    {name = "coman", order = 84},
    {name = "jplogo", order = 84, row = 48, endplayer = true}
}

local start
if ... then
    for i, v in ipairs(parts) do
        if v.name == ... then start = i break end
    end
end
if not start then
    start = 1
    clear()
    require "taskmaster"():task(function()
        _G.PLAYER = skxm
        libtracc.play(skxm, 1, 2400, getSpeakers())
    end):task(function()
        while skxm.order < 14 do sleep(0.25) end
        while skxm.row < 32 do sleep(0.05) end
    end):task(function()
        shell.run("intro")
    end):task(exitListener):waitForAny()
    if exit then return finish() end
end

local playerTask
loop:task(function(task)
    playerTask = task
    _G.PLAYER = xm
    if start > 1 then
        if parts[start-1].row then xm.order, xm.row = parts[start-1].order + 1, parts[start-1].row
        else xm.order = parts[start-1].order end
    else sleep(2) end
    libtracc.play(xm, 1, 2400, getSpeakers())
end):task(function()
    for i = start, #parts do
        local v = parts[i]
        if not v.noclear then clear() end
        local task = loop:addTask(function() shell.run(v.name) end)
        while xm.order < v.order do sleep(0.25) end
        if v.row then while xm.row < v.row do sleep(0.05) end end
        if v.endplayer then
            sleep(2)
            playerTask:remove()
            sleep(3)
        end
        task:remove()
    end
    loop:stop()
end):task(exitListener):run()
if exit then return finish() end

loop:task(function(task)
    playerTask = task
    _G.PLAYER = skxm
    skxm.order = 15
    skxm.row = 1
    libtracc.play(skxm, 1, 2400, getSpeakers())
end):task(function()
    local pal = {}
    for i = 0, 15 do pal[i] = {term.getPaletteColor(2^i)} end
    for i = 0, 10 do
        local p = i / 10
        for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * (1 - p) + p, pal[j][2] * (1 - p) + p, pal[j][3] * (1 - p) + p) end
        sleep(0.05)
    end
    while skxm.order == 15 do sleep(0.05) end
    local task = loop:addTask(function() shell.run("city") end)
    while skxm.order < 22 do sleep(0.25) end
    while skxm.row < 32 do sleep(0.05) end
    task:remove()
    task = loop:addTask(function() shell.run("nuts") end)
    while skxm.order < 24 do sleep(0.25) end
    task:remove()
    shell.run("credits")
    local gv = skxm.globalVolume
    for i = 1, 20 do
        local p = i / 20
        skxm.globalVolume = gv * (1-p)^2
        sleep(0.1)
    end
    loop:stop()
end):task(exitListener):run()
return finish()
