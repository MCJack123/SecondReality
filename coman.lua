local wavesin, wave1, wave2, zwave = {}, {}, {}, {}
local sin, cos, floor, rshift, band, lrotate, pi2 = math.sin, math.cos, math.floor, bit32.rshift, bit32.band, bit32.lrotate, math.pi * 2
local box = require "pixelbox".new(term.current(), 15)
local w, h = box.width, box.height
local imgw, imgh = 160, 192

local function docol(si, di, cx, dx, bp, es)
    local fs, gs = wave1, wave2
    local l
    local sina = 1
    local theloop_xsina = {cx, cx * 2}
    local theloop_ysina = {dx, dx * 2}
    local eax = 0
    local bx
    local ecx = lrotate(-(200-70)*2560, 16)
    local j = 0
    while j < 192 do
        if j == 64 then sina = 2 end
        si = band(si + theloop_xsina[sina], 0xFFFF)
        bx = fs[floor(si/2)]
        di = band(di + theloop_ysina[sina], 0xFFFF)
        bx = bx + gs[floor(di/2)]
        bx = bx + zwave[j] - 240

        if band(eax, 0xFFFF) - (band(eax, 0x8000) * 2) < bx then
            dx = band(bx + 120-floor(j/8), 0xFFFF)
            dx = band(dx, 0xFF00) + rshift(band(dx, 0xFF), 1)

            l = lrotate(j*2560, 16)
            local br
            repeat
                eax = eax + l
                if eax > 0xFFFFFFFF then eax = eax - 0xFFFFFFFF end
                es[bp] = band(dx, 0xFF)
                if band(eax, 0xFFFF) - (band(eax, 0x8000) * 2) >= bx then br = 1 break end
                eax = eax + l
                if eax > 0xFFFFFFFF then eax = eax - 0xFFFFFFFF end
                es[bp-160] = band(dx, 0xFF)
                if band(eax, 0xFFFF) - (band(eax, 0x8000) * 2) >= bx then br = 2 break end
                eax = eax + l
                if eax > 0xFFFFFFFF then eax = eax - 0xFFFFFFFF end
                es[bp-320] = band(dx, 0xFF)

                ecx = ecx + 0x1E000000
                if ecx > 0xFFFFFFFF then ecx = ecx - 0xFFFFFFFF end
                bp = band(bp - 160*3, 0xFFFF)
            until band(eax, 0xFFFF) - (band(eax, 0x8000) * 2) >= bx

            if br == 2 then
                bp = band(bp - 160, 0xFFFF)
                ecx = ecx + lrotate(2560, 16)
            end
            if br then
                if ecx > 0xFFFFFFFF then ecx = ecx - 0xFFFFFFFF end
                ecx = ecx + lrotate(2560, 16)
                if ecx > 0xFFFFFFFF then ecx = ecx - 0xFFFFFFFF end
                bp = band(bp - 160, 0xFFFF)
            end
        end

        eax = eax + ecx
        if sina == 2 then
            if eax > 0xFFFFFFFF then eax = eax - 0xFFFFFFFF end
            eax = eax + ecx
        end
        if eax > 0xFFFFFFFF then eax = eax - 0x100000000
        else eax = band(eax, 0xFFFF0000) + band(band(eax, 0xFFFF) - 1, 0xFFFF) end
        j = j + sina
    end
end

local function doit()
    local startrise = 160
    local x, y, xa, ya, xw, yw, r
    local rot2, rot, rsin, rcos, xwav, ywav = 0, 0, nil, nil, 0, 0
    local rsin2, rcos2
    local frame = 0
    rot, rot2 = 0, 0
    while frame < 1000 do
        if PLAYER.order == 83 and PLAYER.row > 48 then startrise = startrise + 2 * (PLAYER.row - 48)
        elseif startrise > 0 then startrise = startrise - 5 end
        local fb = {}
        rot2 = rot2 + 4
        rot = rot + floor(sin(pi2 * rot2 / 1024) * 17)
        r = rshift(rot, 3)
        rsin = floor(sin(pi2 * r / 1024) * 255)
        rcos = floor(cos(pi2 * r / 1024) * 255)
        rsin2 = floor(sin(pi2 * (r + 177) / 1024) * 255)
        rcos2 = floor(cos(pi2 * (r + 177) / 1024) * 255)
        xw, yw = xwav, ywav
        for a = 0, 159 do
            x = a - 80
            y = 160
            xa = floor((x*rcos + y*rsin) / 256)
            ya = floor((y*rcos2 - x*rsin2) / 256)
            docol(xw, yw, xa, ya, a + 192*160, fb)
            if a == 80 then xwav, ywav = xwav + xa*4, ywav + ya*4 end
        end
        for y = 1, h do
            local iy = floor((y - 1) * (imgh / h)) - startrise
            for x = 1, w do
                local ix = floor((x - 1) * (imgw / w))
                local c = fb[iy*imgw+ix]
                box.canvas[y][x] = c and floor(c / 8) or 15
            end
        end
        box:render()
        box:clear(15)
        sleep(0.05)
        frame = frame + 1
    end
end

for x = 0, 1023 do
    local f=x*math.pi*3.0/1024.0;
    f=sin(f);
    local g=x/700;
    if g>1 then g=2-g; end
    f=f*g*g;
    local y=floor(f*400.0);
    wavesin[x]=y;
end
local u = 0
for _ = 0, 127 do
    for a = 0, 255 do
        local k=rshift((u*1024*7),15);
        local j=floor(wavesin[k%1024]/8);
        k=rshift((u*1024*3),15);
        j=j+floor(wavesin[k%1024]/7)+((math.random(0, 7))*floor(a/256));
        wave1[u]=floor(j*5/9);
        k=rshift((u*1024*5),15);
        j=floor(wavesin[k%1024]/5);
        k=rshift((u*1024*2),15);
        j=j+floor(wavesin[k%1024]/6);
        wave2[u]=floor(j*7/9);
        u=u+1
    end
end
for i = 0, 191 do zwave[i]=floor(16*sin(i*pi2*3/192)) end
for i = 0, 6 do term.setPaletteColor(2^i, math.sqrt((7 - i) / 15), 0.0, 1.0) end
for i = 7, 14 do term.setPaletteColor(2^i, 0.0, math.sqrt((i - 7) / 16), 1.0) end
doit()
for i = 0, 14 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
