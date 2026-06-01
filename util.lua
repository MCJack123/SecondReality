--local Pine3D = require "Pine3D"
local util = {}

local floor, sin, cos, min, max = math.floor, math.sin, math.cos, math.min, math.max

function util.mode7(canvas, ox, oy, dx, dy, w, h, col, mod, a, b, c, d)
    local retval = {}
    for y = 1, h do
        local l = {}
        retval[y] = l
        local mx, my, mv, ma, mb, mc, md = dx, dy, 1, a, b, c, d
        if mod then mx, my, mv, ma, mb, mc, md = mod(y, dx, dy, a, b, c, d) end
        if ma == 0 and mb == 0 and mc == 0 and md == 0 then
            for x = 1, w do l[x] = col or 15 end
        else
            for x = 1, w do
                local cx, cy = x + mx - ox, y + my - oy
                local nx = floor(ma * cx + mb * cy + ox)
                local ny = floor(mc * cx + md * cy + oy)
                local cl = canvas[ny]
                l[x] = floor(min(max((cl and cl[nx] or col or 15) / mv, 0), 15))
            end
        end
    end
    return retval
end

function util.matmul(x, y, z, w, a, b, c, d) return x * a + y * c, x * b + y * d, z * a + w * c, z * b + w * d end
function util.base() return 1, 0, 0, 1, -1 end
function util.scale(xres, yres, a, b, c, d) return util.matmul(a, b, c, d, xres, 0, 0, yres) end
function util.rotate(th, a, b, c, d)
    local si, co = sin(th), cos(th)
    return util.matmul(a, b, c, d, co, si, -si, co)
end
function util.shear(xres, yres, a, b, c, d) return util.matmul(a, b, c, d, 1, xres, yres, 1) end
function util.reflectX(a, b, c, d) return util.matmul(a, b, c, d, -1, 0, 0, 1) end
function util.reflectY(a, b, c, d) return util.matmul(a, b, c, d, 1, 0, 0, -1) end
function util.reflectLine(th, a, b, c, d)
    local x, y = cos(th), sin(th)
    return util.matmul(a, b, c, d, x^2 - y^2, 2 * x * y, 2 * x * y, y^2 - x^2)
end

function util.tile(canvas, w, h)
    for y = 1, h do
        if not canvas[y] then canvas[y] = {} end
        setmetatable(canvas[y], {__index = function(self, idx) return self[(idx - 1) % w + 1] end})
    end
    return setmetatable(canvas, {__index = function(self, idx) return self[(idx - 1) % h + 1] end})
end

return util