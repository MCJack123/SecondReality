local file = assert(fs.open(shell.resolve(...), "rb"))
local s3mdata = assert(file.readAll())
file.close()
local numOrders, instrumentCount, patternCount = ("<HHH"):unpack(s3mdata, 0x21)
-- we assume instruments fill the end of the file
local newdata = s3mdata:sub(1, ("<H"):unpack(s3mdata, ("<H"):unpack(s3mdata, 0x61 + numOrders) * 16 + 0x0F) * 16)
for i = 1, instrumentCount do
    local base = ("<H"):unpack(s3mdata, 0x61 + numOrders + (i-1)*2) * 16 + 1
    if s3mdata:byte(base) == 1 then
        file = assert(fs.open(shell.resolve(...):gsub("%.s3m$", "_samples/" .. ("%02d"):format(i) .. ".flac"), "rb"))
        local flac = assert(file.readAll())
        file.close()
        newdata = newdata:sub(1, base + 0x0D) .. ("<HI"):pack(#newdata / 16, #flac) .. newdata:sub(base + 0x14, base + 0x1D) .. "\xFC" .. newdata:sub(base + 0x1F) .. flac
        if #newdata % 16 > 0 then newdata = newdata .. ("\0"):rep(16 - #newdata % 16) end
    end
end
file = assert(fs.open(shell.resolve(...):gsub("%.s3m$", "_pack.s3m"), "wb"))
file.write(newdata)
file.close()