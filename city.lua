local Pine3D = require "Pine3D"
local visu = require "visu"

local MODEL_COUNT = 42
local COLOR_MAP = {}
for i = 0, 255 do COLOR_MAP[i] = i % 15 end

local file = assert(fs.open("SCENE/U2E.00M", "rb"))
file.read(16)
local pal = {}
for i = 0, 15 do
    file.read(3*7)
    pal[i] = {file.read() / 255 * 4, file.read() / 255 * 4, file.read() / 255 * 4}
    file.read(3*8)
end

local frame = Pine3D.newFrame(1, 1, term.getSize())
local models = {}
for i = 1, MODEL_COUNT do models[i] = visu.readObject(("SCENE/U2E.%03d"):format(i), COLOR_MAP) end
local objs = {}
local objcount = ("<I2"):unpack(file.read(2)) - 1
for i = 1, objcount do objs[i] = visu.createObject(frame, models[("<I2"):unpack(file.read(2))]) end
file.close()
local anim = visu.readAnimation("SCENE/U2E.0AB")
local animpos = 1
frame.buffer.backgroundColor = 15
for i = 0, 14 do frame.buffer.blitWin.setPaletteColor(2^i, table.unpack(pal[i])) end
frame.buffer.blitWin.setPaletteColor(2^15, term.nativePaletteColor(2^15))

--file = fs.open("u2e.txt", "w")
--file.write(textutils.serialize(anim))
--file.close()
--frame:setWireFrame(true)

local n, start = 0, os.epoch "utc"
while animpos <= #anim do
    while n < (os.epoch "utc" - start) * (1800 / 50000) do animpos = visu.applyAnimation(frame, objs, anim, animpos) n = n + 1 end
    visu.drawFrame(frame, objs)
    frame:drawBuffer()
    sleep(0.05)
end

pal[15] = {term.nativePaletteColor(colors.black)}
for i = 1, 5 do
    local p = i / 5
    for j = 0, 15 do term.setPaletteColor(2^j, pal[j][1] * (1 - p) + p, pal[j][2] * (1 - p) + p, pal[j][3] * (1 - p) + p) end
    sleep(0.05)
end
