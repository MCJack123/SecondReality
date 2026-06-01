local Pine3D = require "Pine3D"
local visu = require "visu"

local MODEL_COUNT = 3
local MODEL_NUMS = {1, 2, 3, 1, 1}
local COLOR_MAP = {[0] = 0, [4] = 1, [8] = 1, [16] = 1, [32] = 2, [48] = 3, [64] = 4, [80] = 5, [96] = 6, [112] = 7, [128] = 8, [144] = 9}

local frame = Pine3D.newFrame(1, 1, term.getSize())
frame:setCamera(0, 0, 0, 0, 0, 0)
local models = {}
for i = 1, MODEL_COUNT do models[i] = visu.readObject(("SCENE/U2A.%03d"):format(i), COLOR_MAP) end
local objs = {}
for i, v in ipairs(MODEL_NUMS) do objs[i] = visu.createObject(frame, models[v]) end
local anim = visu.readAnimation("SCENE/U2A.0AB")
local animpos = 1

local file = assert(fs.open("SCENE/U2A.00M", "rb"))
file.read(16)
local pal = {}
for i = 0, 15 do
    file.read(3*15)
    pal[i] = {file.read() / 255 * 4, file.read() / 255 * 4, file.read() / 255 * 4}
    frame.buffer.blitWin.setPaletteColor(2^i, pal[i][1], pal[i][2], pal[i][3])
end
file.close()

--frame:setWireFrame(true)

local n = 1
while animpos <= #anim do
    animpos = visu.applyAnimation(frame, objs, anim, animpos)
    visu.drawFrame(frame, objs)
    frame:drawBuffer()
    term.setCursorPos(1, 1)
    print(n)
    sleep(0.05)
    n = n + 1
end

term.setCursorPos(1, 2)
