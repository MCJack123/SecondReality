local visu = {}

local objBlocks = {}

function objBlocks:VERS(data)
    assert(data == "\0\1\0\0")
end

function objBlocks:NAME(data)
    self.name = data:gsub("%z+$", "")
end

function objBlocks:VERT(data)
    local nvert, pos = ("<I2xx"):unpack(data)
    self.vert = {}
    for i = 1, nvert do
        local v = {}
        v.x, v.y, v.z, v.n, pos = ("<i4i4i4i2xx"):unpack(data, pos)
        self.vert[i] = v
    end
end

function objBlocks:NORM(data)
    local nnum, nnum1, pos = ("<I2I2"):unpack(data)
    self.basicNorms = nnum1
    self.norm = {}
    for i = 1, nnum do
        local n = {}
        n.x, n.y, n.z, pos = ("<i2i2i2xx"):unpack(data, pos)
        self.norm[i] = n
    end
end

function objBlocks:POLY(data)
    local pos = 3
    self.poly, self.polylut = {}, {}
    while pos < #data do
        local p, n = {}
        self.polylut[pos] = p
        n, p.flags, p.color = data:byte(pos, pos+2)
        if n == 0 or n == nil then break end
        pos = pos + 4
        if pos > #data then break end
        p.norm, pos = ("<I2"):unpack(data, pos)
        if pos > #data then break end
        p.vert = {}
        for i = 1, n do p.vert[i], pos = ("<I2"):unpack(data, pos) end
        self.poly[#self.poly+1] = p
    end
end

-- do we need ORD blocks? Pine3D sorts for us

---Triangulate a simple polygon using the ear clipping algorithm.
---Works for both convex and concave polygons (non-self-intersecting).
---@param vertices {x: number, y: number, z: number}[] list of vertices with x,y,z fields
---@param color? number optional color passed through to each triangle
---@return table list of triangles with x1,y1,z1,x2,y2,z2,x3,y3,z3,c fields
local function triangulatePolygon(vertices, color)
    local n = #vertices
    if n < 3 then return {} end

    local function cross(i1, i2, i3)
        assert(vertices[i1], debug.traceback(i1))
        assert(vertices[i2], debug.traceback(i2))
        assert(vertices[i3], debug.traceback(i3))
        return (vertices[i2].x - vertices[i1].x) * (vertices[i3].y - vertices[i2].y)
             - (vertices[i2].y - vertices[i1].y) * (vertices[i3].x - vertices[i2].x)
    end

    local function isConvex(i, prev, next_)
        return cross(prev, i, next_) > 0
    end

    local function pointInTriangle(ip, i1, i2, i3)
        return (cross(i1, i2, ip) > 0) and cross(i2, i3, ip) > 0 and cross(i3, i1, ip) > 0
    end

    local indices = {}
    for i = 1, n do
        indices[i] = i
    end

    local triangles = {}
    local vn = n

    local convex = isConvex(1, #indices, 2)
    while vn > 3 do
        local found = false
        for i = 1, vn do
            local prev = indices[i > 1 and (i - 1) or vn]
            local iCurr = indices[i]
            local next_ = indices[i < vn and (i + 1) or 1]

            if isConvex(iCurr, prev, next_) == convex then
                local inside = false
                for j = 1, vn do
                    if j ~= i and j ~= (i % vn) + 1 then
                        local candidate = indices[j]
                        if pointInTriangle(candidate, iCurr, prev, next_) then
                            inside = true
                            break
                        end
                    end
                end
                if not inside then
                    triangles[#triangles + 1] = {
                        x1 = vertices[prev].x, y1 = vertices[prev].y, z1 = vertices[prev].z,
                        x2 = vertices[iCurr].x, y2 = vertices[iCurr].y, z2 = vertices[iCurr].z,
                        x3 = vertices[next_].x, y3 = vertices[next_].y, z3 = vertices[next_].z,
                        c = color,
                    }
                    table.remove(indices, i)
                    vn = vn - 1
                    found = true
                    break
                end
            end
        end
        if not found then break end
    end

    if vn == 3 then
        triangles[#triangles + 1] = {
            x1 = vertices[indices[1]].x, y1 = vertices[indices[1]].y, z1 = vertices[indices[1]].z,
            x2 = vertices[indices[2]].x, y2 = vertices[indices[2]].y, z2 = vertices[indices[2]].z,
            x3 = vertices[indices[3]].x, y3 = vertices[indices[3]].y, z3 = vertices[indices[3]].z,
            c = color,
        }
    end

    return triangles
end

---Reorder triangle vertices so that the computed normal aligns with a target normal.
---Uses Pine3D's convention: normal is (v2-v1) x (v3-v1), and the triangle is
---front-facing when the XY cross product is < 0 (CW in screen space).
---@param triangle {x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, x3: number, y3: number, z3: number}
---@param targetNormal {x: number, y: number, z: number}
---@return {x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, x3: number, y3: number, z3: number}
local function flipTriangleToNormal(triangle, targetNormal)
    local e1x = triangle.x2 - triangle.x1
    local e1y = triangle.y2 - triangle.y1
    local e1z = triangle.z2 - triangle.z1
    local e2x = triangle.x3 - triangle.x1
    local e2y = triangle.y3 - triangle.y1
    local e2z = triangle.z3 - triangle.z1

    local nx = e1y * e2z - e1z * e2y
    local ny = e1z * e2x - e1x * e2z
    local nz = e1x * e2y - e1y * e2x

    if nx * targetNormal.x + ny * targetNormal.y + nz * targetNormal.z < 0 then
        triangle.x2, triangle.x3 = triangle.x3, triangle.x2
        triangle.y2, triangle.y3 = triangle.y3, triangle.y2
        triangle.z2, triangle.z3 = triangle.z3, triangle.z2
    end

    return triangle
end

function visu.readObject(path, colorMap)
    local file = assert(fs.open(path, "rb"))
    local state = {}
    while true do
        local tag = file.read(4)
        if not tag or tag == "END " then break end
        local len = ("<I4"):unpack(file.read(4))
        local data = file.read(len)
        if objBlocks[tag] then objBlocks[tag](state, data) end
    end
    file.close()
    local model = {name = state.name}
    for _, v in ipairs(state.vert) do v.n = state.norm[v.n+1] end
    for k, p in ipairs(state.poly) do
        p.norm = state.norm[p.norm+1]
        for i, v in ipairs(p.vert) do p.vert[i] = state.vert[v+1] end
        local tris = triangulatePolygon(p.vert, assert(colorMap[p.color], p.color))
        for _, v in ipairs(tris) do
            model[#model+1] = flipTriangleToNormal(v, p.norm)
            v.norm = p.norm
            --v.forceRender = true
        end
    end
    return model
end

function visu.readAnimation(path)
    local file = assert(fs.open(path, "rb"))
    local function readlen(n)
        n = bit32.band(n, 3)
        if n == 0 then return 0 end
        if n == 3 then n = 4 end
        return ("<i" .. n):unpack(file.read(n))
    end
    local anim = {}
    local objnum = 0
    while true do
        local cmd = file.read()
        if not cmd then break end
        if cmd == 0xFF then
            objnum = 0
            cmd = file.read()
            if not cmd then break end
            if cmd <= 0x7F then
                anim[#anim+1] = {fov = cmd}
            elseif cmd == 0xFF then
                anim[#anim+1] = {endframe = true}
            end
        else
            if bit32.band(cmd, 0xC0) == 0xC0 then
                objnum = bit32.band(cmd, 0x3F) * 16
                cmd = file.read()
            end
            objnum = bit32.band(objnum, 0xFF0) + bit32.band(cmd, 0xF)
            local action = {}
            anim[#anim+1] = action
            action.obj = objnum
            if bit32.band(cmd, 0xC0) == 0x80 then action.on = true
            elseif bit32.band(cmd, 0xC0) == 0x40 then action.on = false end
            local pflag = file.read(bit32.band(cmd, 0x30) / 16)
            if #pflag == 0 then pflag = 0
            else pflag = ("<I" .. #pflag):unpack(pflag) end
            action.dx = readlen(pflag)
            action.dy = readlen(bit32.rshift(pflag, 2))
            action.dz = readlen(bit32.rshift(pflag, 4))
            action.dr = {}
            local mlen = bit32.btest(pflag, 0x40) and 2 or 1
            for i = 1, 9 do
                if bit32.btest(pflag, 0x40 * 2^i) then
                    local n = readlen(mlen)
                    action.dr[i] = n
                else action.dr[i] = 0 end
            end
        end
    end
    file.close()
    return anim
end

function visu.applyAnimation(frame, objlist, anim, pos)
    while anim[pos] and not anim[pos].endframe do
        local action = anim[pos]
        pos = pos + 1
        if action.obj then
            local obj = action.obj == 0 and frame.camera or assert(objlist[action.obj])
            if action.on ~= nil then obj.isVisible = action.on end
            obj.x = (obj.x or 0) + action.dx
            obj.y = (obj.y or 0) + action.dy
            obj.z = (obj.z or 0) + action.dz
            local m = obj.m or {0, 0, 0, 0, 0, 0, 0, 0, 0}
            obj.m = m
            for i = 1, 9 do m[i] = m[i] + action.dr[i] end
        elseif action.fov then
            frame:setFoV(action.fov * 1.5)
            pos = pos - 1
            break
        end
    end
    return pos + 1
end

local function flipTriangleToNormalB(triangle, targetNormalX, targetNormalY, targetNormalZ)
    local e1x = triangle[2][1] - triangle[1][1]
    local e1y = triangle[2][2] - triangle[1][2]
    local e1z = triangle[2][3] - triangle[1][3]
    local e2x = triangle[3][1] - triangle[1][1]
    local e2y = triangle[3][2] - triangle[1][2]
    local e2z = triangle[3][3] - triangle[1][3]

    local nx = e1y * e2z - e1z * e2y
    local ny = e1z * e2x - e1x * e2z
    local nz = e1x * e2y - e1y * e2x

    if nx * targetNormalX + ny * targetNormalY + nz * targetNormalZ < 0 then
        triangle[2][1], triangle[3][1] = triangle[3][1], triangle[2][1]
        triangle[2][2], triangle[3][2] = triangle[3][2], triangle[2][2]
        triangle[2][3], triangle[3][3] = triangle[3][3], triangle[2][3]
    end

    return triangle
end

function visu.createObject(frame, model)
    local obj = frame:newObject(model, 0, 0, 0, 0, 0, 0)
    for i, v in ipairs(model) do
        obj[7][i].norm = v.norm
        obj[7][i][10] = nil
        setmetatable(obj[7][i], {
            __index = function(_, idx)
                if idx == 10 then
                    return debug.getinfo(2, "n").name == "drawObject"
                end
            end
        })
    end
    obj.m = {0, 0, 0, 0, 0, 0, 0, 0, 0}
    obj.x, obj.y, obj.z = 0, 0, 0
    obj:setVertexShader(function(x, y, z, poly, vn)
        if vn == 1 then
            local vxlist = {}
            poly.vxlist = vxlist
            local cm, om = {}, {}
            for j = 1, 9 do
                cm[j] = frame.camera.m[j] --+ 16385) % 32770 - 16385
                cm[j] = cm[j] / (cm[j] < 0 and 16385 or 16384)
                om[j] =          obj.m[j] --+ 16385) % 32770 - 16385
                om[j] = om[j] / (om[j] < 0 and 16385 or 16384)
            end
            local m = {
                cm[1] * om[1] + cm[2] * om[4] + cm[3] * om[7],
                cm[1] * om[2] + cm[2] * om[5] + cm[3] * om[8],
                cm[1] * om[3] + cm[2] * om[6] + cm[3] * om[9],
                cm[4] * om[1] + cm[5] * om[4] + cm[6] * om[7],
                cm[4] * om[2] + cm[5] * om[5] + cm[6] * om[8],
                cm[4] * om[3] + cm[5] * om[6] + cm[6] * om[9],
                cm[7] * om[1] + cm[8] * om[4] + cm[9] * om[7],
                cm[7] * om[2] + cm[8] * om[5] + cm[9] * om[8],
                cm[7] * om[3] + cm[8] * om[6] + cm[9] * om[9],
            }
            local ox, oy, oz =
                (obj.x * cm[1] + obj.y * cm[2] + obj.z * cm[3]),
                (obj.x * cm[4] + obj.y * cm[5] + obj.z * cm[6]),
                (obj.x * cm[7] + obj.y * cm[8] + obj.z * cm[9])
            ox, oy, oz = ox + frame.camera.x, oy + frame.camera.y, oz + frame.camera.z
            for v = 1, 9, 3 do
                local x, y, z = poly[v], poly[v+1], poly[v+2]
                x, y, z =
                    (x * m[1] + y * m[2] + z * m[3]),
                    (x * m[4] + y * m[5] + z * m[6]),
                    (x * m[7] + y * m[8] + z * m[9])
                x, y, z = x + ox, y + oy, z + oz
                vxlist[(v-1)/3+1] = {x, y, z}
            end
            local nx, ny, nz = poly.norm.x, poly.norm.y, poly.norm.z
            nx, ny, nz =
                (nx * m[1] + ny * m[2] + nz * m[3]),
                (nx * m[4] + ny * m[5] + nz * m[6]),
                (nx * m[7] + ny * m[8] + nz * m[9])
            flipTriangleToNormalB(vxlist, nx, ny, nz)
        end
        return poly.vxlist[vn][3], -poly.vxlist[vn][2], poly.vxlist[vn][1]
    end)
    return obj
end

function visu.drawFrame(frame, objs)
    frame.buffer:clearDepth()
    for _, v in ipairs(objs) do if v.isVisible then frame:drawObject(v, {frame.camera[1], frame.camera[2], frame.camera[3], 0, 0, 0, frame.camera[7], frame.camera[8]}, {0, 1, 0, 1, 0, 1}) end end
end

return visu
