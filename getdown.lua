if term.getGraphicsMode and term.getGraphicsMode() then term.setGraphicsMode(false) end
term.setBackgroundColor(colors.lightBlue)
term.clear()
local w, h = term.getSize()
w, h = w / 4, h / 4
local bump = 9
local fade = 1
local bx, by = 0, 0
local bc, wc = term.nativePaletteColor(colors.black), term.nativePaletteColor(colors.white)
local br, bg, bb = term.nativePaletteColor(colors.lightBlue)
term.setPaletteColor(colors.lightBlue, wc, wc, wc)
while PLAYER.order == 23 do
    term.setPaletteColor(colors.lightBlue, wc * fade + br * (1 - fade),  wc * fade + bg * (1 - fade), wc * fade + bb * (1 - fade))
    term.setPaletteColor(colors.black, wc * fade + bc * (1 - fade),  wc * fade + bc * (1 - fade), wc * fade + bc * (1 - fade))
    if fade > 0 then fade = fade - 0.25 end
    if by < 4 then
        local x = math.floor(bx * w) + 1
        local lw = math.floor((bx + 1) * w) - math.floor(bx * w)
        local text, fg, bg = (" "):rep(lw), ("0"):rep(lw), ("f"):rep(lw)
        for y = math.floor(by * h) + 1, math.floor((by + 1) * h) do
            term.setCursorPos(x, y)
            term.blit(text, fg, bg)
        end
        by = by + 1
    end
    if PLAYER.row >= bump then
        bump = bump + 8
        fade = 1
        bx, by = bx + 1, 0
    end
    sleep(0.05)
end
term.setPaletteColor(colors.lightBlue, br, bg, bb)
