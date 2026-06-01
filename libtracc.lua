-- libtracc XM/S3M/IT module player library
-- Licensed under the MIT license.
-- Copyright (c) 2021-2025 JackMacWindows.

local libtracc = {
    interpolation = "none"
}

local noteRange = {
    banjo = 3,
    basedrum = 3,
    bass = 1,
    bell = 5,
    bit = 3,
    chime = 5,
    cow_bell = 4,
    didgeridoo = 1,
    flute = 4,
    guitar = 2,
    harp = 3,
    hat = 3,
    iron_xylophone = 3,
    pling = 3,
    snare = 3,
    xylophone = 5
}

local amigaTable = {
[0]=907,900,894,887,881,875,868,862,856,850,844,838,832,826,820,814,
    808,802,796,791,785,779,774,768,762,757,752,746,741,736,730,725,
    720,715,709,704,699,694,689,684,678,675,670,665,660,655,651,646,
    640,636,632,628,623,619,614,610,604,601,597,592,588,584,580,575,
    570,567,563,559,555,551,547,543,538,535,532,528,524,520,516,513,
    508,505,502,498,494,491,487,484,480,477,474,470,467,463,460,457,453
}

local portaDrift = 192

---@class tracc.sample
---@field size number
---@field loopStart number
---@field loopLength number
---@field volume number
---@field finetune number
---@field type number
---@field pan number
---@field note number
---@field name string
---@field wavetable number[]

---@class tracc.envelope
---@field points {x: number, y: number}[]
---@field sustain number
---@field loopStart number
---@field loopEnd number
---@field loopType number

---@class tracc.instrument
---@field samples tracc.sample[]
---@field samplesByNumber tracc.sample[]
---@field volumeEnvelope tracc.envelope
---@field panningEnvelope tracc.envelope
---@field vibrato {type: number, sweep: number, depth: number, rate: number, sweep_mult: number}
---@field fadeOut number

---@class tracc.note
---@field note number|nil
---@field instrument number|nil
---@field volume number|nil
---@field effect number|nil
---@field effect_param number|nil

---@class tracc.module
---@field instruments tracc.instrument[]
---@field patterns tracc.note[][]
---@field order number[]
---@field name string
---@field tracker string
---@field amigaSlides boolean
---@field restartPosition number

---@class tracc.channel
---@field num number
---@field effectMemory table
---@field playing {note: number, instrument: number, volume: number, effect: number, effect_param: number}
---@field volume number
---@field pan number
---@field volumeEnvelope {volume: number, pos: number, x: number, sustain: boolean, rate: number}
---@field panningEnvelope {panning: number, pos: number, x: number, sustain: boolean, rate: number}
---@field vibrato {type: number, pos: number}
---@field speaker table|nil
---@field note number|nil
---@field finetune number|nil
---@field frequency number|nil
---@field lastFrequency number|nil
---@field instrument tracc.instrument|nil
---@field didSetInstrument boolean|nil
---@field lastNote number|nil

---@class tracc
---@field type "xm"|"s3m"|"it"
---@field tempo number
---@field bpm number
---@field channels tracc.channel[]
---@field module tracc.module
---@field order number
---@field row number
---@field tick number|nil
---@field globalVolume number
---@field mutedChannels table<number, boolean>
---@field mixVolume number
---@field loop boolean
---@field sound tracc.sound
---@field usedB boolean|nil
---@field usedD boolean|nil
---@field usedE6 number|nil
---@field usedEE number|nil
---@field currentOrder number
---@field currentRow number

-- Software mixer emulating craftos2-sound (custom waves only for now)
local function makeSound()
    ---@class tracc.sound
    local sound = {channels = {}, version = 2, interpolation = libtracc.interpolation}
    for i = 1, 32 do sound.channels[i] = {frequency = 0, volume = 0, panning = 0} end
    function sound.getFrequency(c) return sound.channels[c].frequency end
    function sound.setFrequency(c, freq) sound.channels[c].frequency = freq end
    function sound.getVolume(c) return sound.channels[c].volume end
    function sound.setVolume(c, vol) sound.channels[c].volume = vol end
    function sound.setWaveType(c, type, tab, loopStart, loopType, keepPos)
        if type == "none" then sound.channels[c].wavetable = nil
        elseif type == "custom" then
            if loopStart >= #tab then loopStart = 0 end
            local ch = sound.channels[c]
            ch.wavetable, ch.pos, ch.loopStart, ch.loopType, ch.dir = tab, keepPos and ch.pos or 0, loopStart or 0, loopType or 1, 1
        else error("Invalid wave type", 2) end
    end
    function sound.setPan(c, p) sound.channels[c].pan = p end
    function sound.fadeOut(c, time)
        local info = sound.channels[c]
        if (time < -0.000001) then
            info.fadeSamplesInit = 1 - info.volume;
            info.fadeDirection = 1;
            info.fadeSamples, info.fadeSamplesMax = -time * 48000, -time * 48000;
        elseif (time < 0.000001) then
            info.fadeSamplesInit = 0.0;
            info.fadeSamples, info.fadeSamplesMax = 0, 0;
        else
            info.fadeSamplesInit = info.volume;
            info.fadeDirection = -1;
            info.fadeSamples, info.fadeSamplesMax = time * 48000, time * 48000;
        end
    end
    function sound.setPosition(c, p) sound.channels[c].pos = (p / #sound.channels[c].wavetable) % 1 end
    function sound.setInterpolation(c, i) sound.channels[c].interpolation = i end
    local function tovu(n) return math.log(1+9*math.abs(n), 10) end
    function sound.generate(state, length, cc, stereo)
        local retval, right, vu = {}, {}, {}
        for j = 1, length do
            local sample, rs = 0, 0
            local num = 0
            for i = 1, (cc or 32) do
                local c = sound.channels[i]
                local interp = c.interpolation or sound.interpolation
                if c.wavetable and c.volume > 0 and c.frequency > 0 then
                    local p = c.pos * #c.wavetable
                    local s
                    if interp == "none" then s = c.wavetable[math.floor(p)+1] * c.volume
                    elseif interp == "linear" then s = (c.wavetable[math.floor(p)+1] + (c.wavetable[math.floor(p+1) % #c.wavetable+1] - c.wavetable[math.floor(p)+1]) * (p - math.floor(p))) * c.volume end
                    if stereo then
                        sample, rs = sample + s * math.min(c.pan+1, 1) * state.mixVolume, rs + s * math.min(1-c.pan, 1) * state.mixVolume
                        if vu[i] then vu[i][1], vu[i][2] = vu[i][1] + tovu((state.globalVolume / 64) * s * math.min(c.pan+1, 1) * state.mixVolume), vu[i][2] + tovu((state.globalVolume / 64) * s * math.min(1-c.pan, 1) * state.mixVolume)
                        else vu[i] = {tovu((state.globalVolume / 64) * s * math.min(c.pan+1, 1)), tovu((state.globalVolume / 64) * s * math.min(1-c.pan, 1) * state.mixVolume)} end
                    else
                        sample = sample + s * state.mixVolume
                        if vu[i] then vu[i][1], vu[i][2] = vu[i][1] + tovu((state.globalVolume / 64) * s), vu[i][2] + tovu((state.globalVolume / 64) * s)
                        else vu[i] = {tovu((state.globalVolume / 64) * s), tovu((state.globalVolume / 64) * s)} end
                    end
                    c.pos = c.pos + c.frequency / 48000 * c.dir
                    if c.pos < 0 then c.pos, c.dir = 0, 1 end
                    while c.pos >= 1 do
                        if c.loopType == 0 then c.wavetable, c.pos = nil, 0
                        elseif c.loopType == 1 then c.pos = c.pos - 1 + (c.loopStart / #c.wavetable)
                        else c.pos, c.dir = 1 - c.frequency / 48000, -1 end
                    end
                    if ((c.fadeSamplesMax or 0) > 0) then
                        c.volume = c.volume + (c.fadeSamplesInit / c.fadeSamplesMax * c.fadeDirection);
                        c.fadeSamples = c.fadeSamples - 1
                        if (c.fadeSamples <= 0) then
                            c.fadeSamples, c.fadeSamplesMax = 0, 0;
                            c.fadeSamplesInit = 0.0;
                            c.volume = c.fadeDirection == 1 and 1 or 0;
                        end
                    end
                    num = num + 1
                end
            end
            --if num > 0 then sample, rs = sample / (cc or num), rs / (cc or num) end
            retval[j] = math.max(math.min((state.globalVolume / 64) * sample / 2, 1), -1) * 127
            right[j] = math.max(math.min((state.globalVolume / 64) * rs / 2, 1), -1) * 127
        end
        for i = 1, (cc or 32) do vu[i] = vu[i] and {vu[i][1] / length, vu[i][2] / length} or {0, 0} end
        return retval, right, vu
    end
    return sound
end

local function fromLE(str)
    if not str then error(debug.traceback("Bad str"), 2) end
    local n = 0
    for i = 1, #str do n = n + bit32.lshift(str:byte(i), 8*(i-1)) end
    return n
end

---@param state tracc
---@param note number
---@param finetune number
---@return number
local function toFreq(state, note, finetune)
    if state.module.amigaSlides then
        local a = ((note % 12)*8 + math.floor(finetune/16)) % 96
        return (state.type == "xm" and 14317456 or 14187580)/((amigaTable[a]*(1-(finetune/16 % 1)) + amigaTable[a+1]*((finetune/16 % 1))) * 16 / 2^math.floor(note / 12 - 1))
    else return 8363*2^((6*12*16*4 - (10*12*16*4 - (note-1)*16*4 - math.floor(finetune/2))) / (12*16*4)) end
end
---@param state tracc
---@param frequency number
---@param slide number
---@return number
local function slideFreq(state, frequency, slide, isPorta)
    if isPorta and state.type == "xm" then slide = slide * 2 end
    --elseif isPorta and state.type == "s3m" then slide = slide / 2 end
    if state.module.amigaSlides then
        local f = state.type == "xm" and 3579364 or 3546895
        return f / math.max(f / frequency - slide, 1)
    else return frequency * 2^(slide / portaDrift) end
end
---@param note number
---@param name string
---@return number
local function toNote(note, name) return note - 12*(noteRange[name]-1) - 7 end
---@param note number
---@return number
local function toSpeed(note) return 2^((note - 49)/12) end
---@param state tracc
---@param channel number
---@param sample tracc.sample
local function getFrequency(state, channel, sample) return state.sound.getFrequency(channel) * #sample.wavetable end
---@param state tracc
---@param channel number
---@param freq number
---@param sample tracc.sample
local function setFrequency(state, channel, freq, sample) state.sound.setFrequency(channel, freq / #sample.wavetable) end

---@param state tracc
---@param channel tracc.channel
---@param vol number
local function setVolume(state, channel, vol)
    channel.volume = vol
    if not channel.speaker then
        if state.mutedChannels[channel.num] then state.sound.setVolume(channel.num, 0)
        else state.sound.setVolume(channel.num, vol / 64 * (channel.volumeEnvelope.volume / 64) * (channel.instrument and channel.instrument.volume or 1)) end
    end
end

---@param state tracc
---@param channel tracc.channel
---@param pan number
local function setPan(state, channel, pan)
    channel.pan = pan
    if not channel.speaker then
        state.sound.setPan(channel.num, -math.max((pan - 127) / 127, -1))
    end
    -- TODO: Add stereo capability to CC speakers
end

---@param state tracc
---@param channel tracc.channel
---@param inst number
local function setInstrument(state, channel, inst)
    if not state.module.instruments[inst] then return end
    channel.instrument = state.module.instruments[inst]
    if #channel.instrument.volumeEnvelope.points > 0 --[[and channel.instrument.volumeEnvelope.loopType % 2 == 1]] then
        if #channel.instrument.volumeEnvelope.points == 1 or (bit32.btest(channel.instrument.volumeEnvelope.loopType, 2) and channel.instrument.volumeEnvelope.sustain == 1) then channel.volumeEnvelope = {volume = channel.instrument.volumeEnvelope.points[1].y, pos = 1, x = 0, sustain = true}
        else channel.volumeEnvelope = {volume = channel.instrument.volumeEnvelope.points[1].y, pos = 1, x = 0, rate = (channel.instrument.volumeEnvelope.points[2].y - channel.instrument.volumeEnvelope.points[1].y) / (channel.instrument.volumeEnvelope.points[2].x - channel.instrument.volumeEnvelope.points[1].x)} end
    else
        channel.volumeEnvelope = {volume = 64, pos = 0, x = 0}
    end
    if #channel.instrument.panningEnvelope.points > 0 --[[and channel.instrument.panningEnvelope.loopType % 2 == 1]] then
        if #channel.instrument.panningEnvelope.points == 1 or (bit32.btest(channel.instrument.panningEnvelope.loopType, 2) and channel.instrument.panningEnvelope.sustain == 1) then channel.panningEnvelope = {panning = channel.instrument.panningEnvelope.points[1].y, pos = 1, x = 0, sustain = true}
        else channel.panningEnvelope = {panning = channel.instrument.panningEnvelope.points[1].y, pos = 1, x = 0, rate = (channel.instrument.panningEnvelope.points[2].y - channel.instrument.panningEnvelope.points[1].y) / (channel.instrument.panningEnvelope.points[2].x - channel.instrument.panningEnvelope.points[1].x)} end
    else
        channel.panningEnvelope = {panning = 32, pos = 0, x = 0}
    end
    if channel.instrument.vibrato.sweep > 0 then channel.instrument.vibrato.sweep_mult = 0
    else channel.instrument.vibrato.sweep_mult = 1 end
end

---@param state tracc
---@param channel tracc.channel
---@param note number
---@param keepPos? boolean
local function setNote(state, channel, note, keepPos)
    channel.speaker = nil
    if note == 97 or note >= 254 then
        if not channel.speaker then
            if channel.instrument and #channel.instrument.volumeEnvelope.points > 1 and not (channel.playing and channel.playing.effect == 0xE and channel.playing.effect_param and bit32.band(channel.playing.effect_param, 0xF0) == 0xD0) and channel.instrument.fadeOut > 0 then
                state.sound.fadeOut(channel.num, (32768 / channel.instrument.fadeOut) * (2.5 / state.bpm))
            elseif channel.instrument and #channel.instrument.volumeEnvelope.points - 1 == channel.instrument.volumeEnvelope.sustain then
                state.sound.fadeOut(channel.num, (channel.instrument.volumeEnvelope.points[#channel.instrument.volumeEnvelope.points].x - channel.instrument.volumeEnvelope.points[#channel.instrument.volumeEnvelope.points-1].x) * (2.5 / state.bpm))
            else state.sound.setVolume(channel.num, 0) state.sound.setFrequency(channel.num, 0) channel.frequency = 0 end
        end
        channel.note = nil
    elseif note ~= 0 and channel.instrument then
        local sample = channel.instrument.samples[note]
        if not sample then
        elseif sample.name == "unused" then
            if not channel.speaker then state.sound.setVolume(channel.num, 0) end
        elseif not channel.speaker and state.sound.version then
            channel.finetune = sample.finetune
            channel.frequency = toFreq(state, note+sample.note, channel.finetune)
            state.sound.setWaveType(channel.num, "custom", sample.wavetable, sample.loopStart, bit32.band(sample.type, 3), keepPos)
            if sample.name:byte(1) == 33 then state.sound.setInterpolation(channel.num, "linear")
            else state.sound.setInterpolation(channel.num, nil) end
            setFrequency(state, channel.num, channel.frequency, sample)
        elseif noteRange[sample.name] then
            local spk
            for _,v in ipairs(state.speakers) do
                if v.usage < 1 then
                    spk = v.speaker
                    v.usage = v.usage + (1 / libtracc.notesPerTick)
                    break
                end
            end
            if not spk then error("Not enough speakers to play module") end
            channel.speaker = spk
            state.sound.setVolume(channel.num, 0)
            if toNote(note, sample.name) >= 0 and toNote(note, sample.name) <= 24 and not state.mutedChannels[channel.num] then spk.playNote(sample.name, channel.volume / 64 * (state.globalVolume / 64), toNote(note, sample.name)) end
        else
            local spk
            for _,v in ipairs(state.speakers) do
                if v.usage == 0 then
                    spk = v.speaker
                    v.usage = 1
                    break
                end
            end
            if not spk then error("Not enough speakers to play module") end
            channel.speaker = spk
            state.sound.setVolume(channel.num, 0)
            if not state.mutedChannels[channel.num] then spk.playSound(sample.name, channel.volume / 64 * (state.globalVolume / 64), toSpeed(note)) end
        end
        channel.note = note
        channel.didSetInstrument = true
    end
end

local retrigVolume = {
    function(v) return math.max(v - 1, 0) end,
    function(v) return math.max(v - 2, 0) end,
    function(v) return math.max(v - 4, 0) end,
    function(v) return math.max(v - 8, 0) end,
    function(v) return math.max(v - 16, 0) end,
    function(v) return math.max(v * (2/3), 0) end,
    function(v) return math.max(v / 2, 0) end,
    function(v) return v end,
    function(v) return math.min(v + 1, 0) end,
    function(v) return math.min(v + 2, 0) end,
    function(v) return math.min(v + 4, 0) end,
    function(v) return math.min(v + 8, 0) end,
    function(v) return math.min(v + 16, 0) end,
    function(v) return math.min(v / (2/3), 0) end,
    function(v) return math.min(v * 2, 0) end,
}

local e_effects = {
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    [0] = function(state, channel, param) end, -- (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 1
        if param == 0 then param = channel.effectMemory[0xE1] or 0
        else channel.effectMemory[0xE1] = param end
        if not channel.speaker and state.tick == 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, param)
            setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), param), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 2
        if param == 0 then param = channel.effectMemory[0xE2] or 0
        else channel.effectMemory[0xE2] = param end
        if not channel.speaker and state.tick == 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, -param)
            setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), -param), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 3
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 4
        channel.vibrato.type = param
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 5
        if not channel.speaker then
            channel.finetune = param
            if channel.playing then
                channel.frequency = toFreq(state, channel.playing.note+channel.instrument.samples[channel.playing.note].note, channel.finetune)
                setFrequency(state, channel.num, channel.frequency, channel.instrument.samples[channel.playing.note])
            end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 6
        if param == 0 then channel.effectMemory[0xE6] = state.row
        else
            if not state.usedE6 or state.usedE6 > 0 then
                state.row = channel.effectMemory[0xE6] or state.row
                state.usedE6 = (state.usedE6 or param) - 1
            else state.usedE6 = nil end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 7
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 8
        setPan(state, channel, param * 16)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 9
        if param > 0 and state.tick > 1 and (state.tick - 1) % param == 0 then
            setNote(state, channel, channel.playing.note or 97)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- A
        if param == 0 then param = channel.effectMemory[0xEA] or 0
        else channel.effectMemory[0xEA] = param end
        if state.tick == 1 then setVolume(state, channel, math.min(channel.volume + math.floor(param), 64)) end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- B
        if param == 0 then param = channel.effectMemory[0xEB] or 0
        else channel.effectMemory[0xEB] = param end
        if state.tick == 1 then setVolume(state, channel, math.max(channel.volume - param, 0)) end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- C
        if state.tick == param + 1 then
            setVolume(state, channel, 0)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- D
        if state.tick == 1 then
            --setNote(state, channel, 97)
            return 0
        end
        if state.tick - 1 == param then setNote(state, channel, channel.playing.note) end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- E
        if not state.usedEE or state.usedEE > 0 then
            local ex = state.usedEE ~= nil
            state.row = state.row - 1
            state.usedEE = (state.usedEE or param) - 1
            if ex then return 0 end
        else state.usedEE = nil end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- F
        -- unimplemented
    end
}

local x_effects = {
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    [0] = function(state, channel, param) end, -- (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 1
        if param == 0 then param = channel.effectMemory[0x211] or 0
        else channel.effectMemory[0x211] = param end
        if not channel.speaker and state.tick == 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, param / 16)
            setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), param / 16), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 2
        if param == 0 then param = channel.effectMemory[0x212] or 0
        else channel.effectMemory[0x212] = param end
        if not channel.speaker and state.tick == 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, param / -16)
            setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), param / -16), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 3 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 4 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 5 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 6 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 7 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) state.order = math.huge end, -- 8 (tracc hack - stops song)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- 9 (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- A (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- B (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- C (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- D (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- E (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end -- F (does not exist)
}

---@param state tracc
---@param channel tracc.channel
---@param t number
---@param speed number
---@param depth number
local function doVibrato(state, channel, t, speed, depth)
    local amplitude
    if t == 0 then amplitude = math.sin(channel.vibrato.pos * math.pi)
    elseif t == 1 then amplitude = channel.vibrato.pos * 2 - 1
    elseif t == 2 then amplitude = channel.vibrato.pos >= 0.5 and -1 or 1
    elseif t == 8 then amplitude = (1 - channel.vibrato.pos) * 2 - 1 -- ramp down (special)
    else amplitude = math.random() * 2 - 1 end
    if channel.instrument and channel.note then
        local sample = channel.instrument.samples[channel.note]
        setFrequency(state, channel.num, slideFreq(state, channel.frequency, amplitude * depth * 2), sample)
    end
    channel.vibrato.pos = (channel.vibrato.pos + (speed / 64)) % 1
end

local effects
effects = {
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    [0] = function(state, channel, param) -- 0
        if not channel.instrument then return end
        if state.tick % 3 == 1 then setNote(state, channel, channel.lastNote or channel.playing.note, true)
        elseif state.tick % 3 == 2 then setNote(state, channel, (channel.lastNote or channel.playing.note) + bit32.rshift(param, 4), true)
        else setNote(state, channel, (channel.lastNote or channel.playing.note) + bit32.band(param, 0xF), true) end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 1
        if param == 0 then param = channel.effectMemory[1] or 0
        else channel.effectMemory[1] = param end
        if not channel.speaker and state.tick > 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, param)
            setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), param), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 2
        if param == 0 then param = channel.effectMemory[2] or 0
        else channel.effectMemory[2] = param end
        if not channel.speaker and state.tick > 1 and channel.note then
            channel.frequency = slideFreq(state, channel.frequency, -param)
            setFrequency(state, channel.num, math.max(slideFreq(state, getFrequency(state, channel.num, channel.instrument.samples[channel.note]), -param), 0), channel.instrument.samples[channel.note])
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 3
        if param == 0 then param = channel.effectMemory[3] or 0
        else channel.effectMemory[3] = param end
        if not channel.speaker and channel.note and channel.instrument then
            local note = channel.playing.note or channel.lastNote
            local sample = channel.instrument.samples[note]
            if sample then
                --print(sample.name, channel.playing.note, channel.lastNote, sample.note, getFrequency(state, channel.num, sample), toFreq(state, note+sample.note, sample.finetune, sample))
                if state.tick == 1 and channel.playing.note then
                    note = channel.lastNote
                    sample = channel.instrument.samples[note]
                    if sample then
                        channel.finetune = sample.finetune
                        channel.frequency = channel.lastFrequency or toFreq(state, note+sample.note, channel.finetune)
                        setFrequency(state, channel.num, channel.frequency, sample)
                        if channel.playing and channel.playing.note then channel.lastNote = channel.playing.note end
                    end
                    return 0
                elseif slideFreq(state, channel.frequency, param, true) < toFreq(state, note+sample.note, sample.finetune) then
                    channel.frequency = slideFreq(state, channel.frequency, param, true)
                    setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, sample), param, true), sample)
                elseif slideFreq(state, channel.frequency, -param, true) > toFreq(state, note+sample.note, sample.finetune) then
                    channel.frequency = slideFreq(state, channel.frequency, -param, true)
                    setFrequency(state, channel.num, slideFreq(state, getFrequency(state, channel.num, sample), -param, true), sample)
                elseif channel.frequency ~= toFreq(state, note+sample.note, sample.finetune) then
                    channel.frequency = toFreq(state, note+sample.note, sample.finetune)
                    setFrequency(state, channel.num, channel.frequency, sample)
                end
            end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 4
        if param == 0 then param = channel.effectMemory[4] or 0
        else channel.effectMemory[4] = param end
        if state.tick == 1 and channel.playing and channel.playing.note and bit32.btest(channel.vibrato.type, 4) then channel.vibrato.pos = 0 end
        doVibrato(state, channel, bit32.band(channel.vibrato.type, 3), bit32.rshift(param, 4), bit32.band(param, 0x0f))
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 5
        effects[0x3](state, channel, 0)
        return effects[0xA](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 6
        effects[0x4](state, channel, 0)
        return effects[0xA](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 7
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 8
        setPan(state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- 9
        if state.tick == 1 and not state.mutedChannels[channel.num] and channel.playing and channel.playing.note then
            local pos = param * 256
            local ch = state.sound.channels[channel.num]
            while pos > #ch.wavetable do
                pos = ch.loopStart + (#ch.wavetable - pos)
            end
            state.sound.setPosition(channel.num, pos)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- A
        if param == 0 then param = channel.effectMemory[0xA] or 0
        else channel.effectMemory[0xA] = param end
        if state.tick > 1 then
            if param < 16 then setVolume(state, channel, math.max(channel.volume - param, 0))
            else setVolume(state, channel, math.min(channel.volume + math.floor(param / 16), 64)) end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- B
        if state.tick == 1 then state.order = param + 1 state.usedB = true end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- C
        setVolume(state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- D
        if state.tick == 1 then
            state.row = bit32.rshift(param, 4) * 10 + bit32.band(param, 15) + 1
            state.usedD = true;
            if state.order == state.currentOrder and not state.usedB then
                if state.order == #state.module.order then state.order = 1
                else state.order = state.order + 1 end
            end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- E
        return e_effects[bit32.rshift(param, 4)](state, channel, bit32.band(param, 0xF))
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- F
        if param < 0x20 then
            if param == 0 then state.order = math.huge -- stop song
            else state.tempo = param end
        else state.bpm = param end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- G
        state.globalVolume = math.min(math.max(param, 0), 64)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- H
        if param == 0 then param = channel.effectMemory[0x11] or 0
        else channel.effectMemory[0x11] = param end
        if state.tick > 1 then
            if param < 16 then state.globalVolume = math.max(state.globalVolume - param, 0)
            else state.globalVolume = math.min(state.globalVolume + math.floor(param / 16), 64) end
            setVolume(state, channel, channel.volume)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- I (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- J (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- K
        if state.tick == param + 1 then
            setNote(state, channel, 97)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- L
        if #channel.instrument.volumeEnvelope.points > 0 and channel.instrument.volumeEnvelope.loopType % 2 == 1 then
            channel.volumeEnvelope.x = param
            channel.volumeEnvelope.pos = 1
            while channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos+1].x < param do channel.volumeEnvelope.pos = channel.volumeEnvelope.pos + 1 end
            if channel.volumeEnvelope.pos + 1 > #channel.instrument.volumeEnvelope.points or (bit32.btest(channel.instrument.volumeEnvelope.loopType, 2) and channel.volumeEnvelope.pos == channel.instrument.volumeEnvelope.sustain) then
                channel.volumeEnvelope.sustain = true
                channel.volumeEnvelope.volume = channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos].y
            else
                channel.volumeEnvelope.volume = channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos].y + (param - channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos].x) * channel.volumeEnvelope.rate
                channel.volumeEnvelope.rate = (channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos+1].y - channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos].y) / (channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos+1].x - channel.instrument.volumeEnvelope.points[channel.volumeEnvelope.pos].x)
            end
            setVolume(state, channel, channel.volumeEnvelope.volume)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- M (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- N (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- O (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- P
        if param == 0 then param = channel.effectMemory[0x19] or 0
        else channel.effectMemory[0x19] = param end
        if state.tick == 1 then
            if param < 16 then setPan(state, channel, math.max(channel.pan - param, 0))
            else setPan(state, channel, math.min(channel.pan + math.floor(param / 16), 128)) end
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- Q (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- R
        if param == 0 then param = channel.effectMemory[0x1B] or 0
        else channel.effectMemory[0x1B] = param end
        if math.floor(param / 16) == 0 then param = param + (channel.effectMemory[0x1B0] or 0x80)
        else channel.effectMemory[0x1B0] = bit32.band(param, 0xF0) end
        if state.tick > 1 and (state.tick - 1) % (param % 16) == 0 then
            setVolume(state, channel, retrigVolume[math.floor(param / 16)](channel.volume))
            setNote(state, channel, channel.playing.note or 97)
        end
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- S (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- T
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- U (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- V (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) end, -- W (does not exist)
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- X
        return x_effects[bit32.rshift(param, 4)](state, channel, bit32.band(param, 0xF))
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- Y
        -- unimplemented
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- Z
        -- unimplemented
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- \
        -- unimplemented
    end
}

local volume_effects
volume_effects = {
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    [0] = function(state, channel, param) end, -- do nothing
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- v
        setVolume(state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) return volume_effects[1](state, channel, param + 16) end, -- v
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) return volume_effects[1](state, channel, param + 32) end, -- v
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) return volume_effects[1](state, channel, param + 48) end, -- v
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) return volume_effects[1](state, channel, 64) end, -- v
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- d
        return effects[0xA](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- c
        return effects[0xA](state, channel, param * 16)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- b
        return e_effects[0xB](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- a
        return e_effects[0xA](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- u
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- h
        -- TODO
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- p
        setPan(state, channel, param * 16)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- l
        return effects[0x19](state, channel, param)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- r
        return effects[0x19](state, channel, param * 16)
    end,
    ---@param state tracc
    ---@param channel tracc.channel
    ---@param param number
    function(state, channel, param) -- g
        return effects[3](state, channel, param * 16)
    end,
}

local s3mTrackerFmt = {
    "Scream Tracker %d.%d%d",
    "Imago Orpheus %d.%d%d",
    "Impulse Tracker %d.%d%d",
    "Schism Tracker %d.%d%d",
    "OpenMPT %d.%d%d",
    "BeRoTracker %d.%d%d",
    "CreamTracker %d.%d%d"
}

local function s3mTrackers(num)
    if num == 0x0208 then return "Akord"
    elseif num == 0xCA00 then return "Camoto/libgamemusic"
    elseif num == 0x4100 then return "BeRoTracker" end
    local fmt = s3mTrackerFmt[bit32.rshift(bit32.band(num, 0xF000), 12)]
    if fmt then return fmt:format(bit32.rshift(bit32.band(num, 0x0F00), 8), bit32.rshift(bit32.band(num, 0xF0), 4), bit32.band(num, 0xF))
    else return "Unknown" end
end

local s3mEffects = {
    function(p) return 0x0F, p end, -- A
    function(p) return 0x0B, p end, -- B
    function(p) return 0x0D, p end, -- C
    function(p, g) -- D
        if p == 0 then p = g.x end
        g.x = p
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0 or l == 0 then return 0x0A, p
        elseif h == 0xF then return 0x0E, 0xB0 + l
        elseif l == 0xF then return 0x0E, 0xA0 + h end
    end,
    function(p, g) -- E
        if p == 0 then p = g.x end
        g.x = p
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0xF then return 0x0E, 0x20 + l
        elseif h == 0xE then return 0x21, 0x20 + l
        else return 0x02, p end
    end,
    function(p, g) -- F
        if p == 0 then p = g.x end
        g.x = p
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0xF then return 0x0E, 0x10 + l
        elseif h == 0xE then return 0x21, 0x10 + l
        else return 0x01, p end
    end,
    function(p) return 0x03, p end, -- G
    function(p) return 0x04, p end, -- H
    function(p, g) -- I
        if p == 0 then p = g.x end
        g.x = p
        return 0x1D, p
    end,
    function(p, g) -- J
        if p == 0 then p = g.x end
        g.x = p
        return 0x00, p
    end,
    function(p, g) -- K
        if p == 0 then p = g.x end
        g.x = p
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0 or l == 0 then return 0x06, p
        elseif h == 0xF then return 0x04, 0, 0x80 + l
        elseif l == 0xF then return 0x04, 0, 0x90 + h end
    end,
    function(p, g) -- L
        if p == 0 then p = g.x end
        g.x = p
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0 or l == 0 then return 0x05, p
        elseif h == 0xF then return 0x03, 0, 0x80 + l
        elseif l == 0xF then return 0x03, 0, 0x90 + h end
    end,
    function(p) end, -- M (unimplemented)
    function(p) end, -- N (unimplemented)
    function(p) return 0x09, p end, -- O
    function(p) -- P
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 0 then return 0x19, l * 16
        elseif l == 0 then return 0x19, h end
    end,
    function(p, g) -- Q
        if p == 0 then p = g.x end
        g.x = p
        return 0x1B, p
    end,
    function(p, g) -- R
        if p == 0 then p = g.x end
        g.x = p
        return 0x07, p
    end,
    function(p) -- S
        local h, l = bit32.rshift(p, 4), bit32.band(p, 15)
        if h == 1 then return 0x0E, 0x30 + l
        elseif h == 2 then return 0x0E, 0x50 + l
        elseif h == 3 then return 0x0E, 0x40 + l
        elseif h == 4 then return 0x0E, 0x70 + l
        elseif h == 5 or h == 6 or h == 9 or h == 10 then return 0x21, p
        elseif h == 8 or h == 0xC or h == 0xD or h == 0xE then return 0x0E, p
        elseif h == 0xB then return 0x0E, 0x60 + l end
        error("Unknown S effect")
    end,
    function(p) if p >= 0x20 then return 0x0F, p end end, -- T
    function(p) end, -- U (unimplemented)
    function(p) return 0x10, p end, -- V
    function(p) return 0x11, p end, -- W
    function(p) return 0x08, math.min(p * 2, 255) end, -- X
    function(p) return 0x22, p end, -- Y
    function(p) return 0x23, p end, -- Z
}

-- Simple FLAC decoder (Java)
--
-- Copyright (c) 2017 Project Nayuki. (MIT License)
-- https://www.nayuki.io/page/simple-flac-implementation
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:
-- - The above copyright notice and this permission notice shall be included in
--   all copies or substantial portions of the Software.
-- - The Software is provided "as is", without warranty of any kind, express or
--   implied, including but not limited to the warranties of merchantability,
--   fitness for a particular purpose and noninfringement. In no event shall the
--   authors or copyright holders be liable for any claim, damages or other
--   liability, whether in an action of contract, tort or otherwise, arising from,
--   out of or in connection with the Software or the use or other dealings in the
--   Software.

local bit32_band, bit32_rshift, bit32_btest = bit32.band, bit32.rshift, bit32.btest
local math_floor = math.floor
local str_byte = string.byte

local FIXED_PREDICTION_COEFFICIENTS = {
    {},
    {1},
    {2, -1},
    {3, -3, 1},
    {4, -6, 4, -1},
};

local function BitInputStream(data, pos)
    local obj = {}
    local bitBuffer, bitBufferLen = 0, 0
    function obj.alignToByte()
        bitBufferLen = bitBufferLen - bitBufferLen % 8
    end
    function obj.readByte()
        return obj.readUint(8)
    end
    function obj.readUint(n)
        if n == 0 then return 0 end
        while bitBufferLen < n do
            local temp = str_byte(data, pos)
            pos = pos + 1
            if temp == nil then return nil end
            bitBuffer = (bitBuffer * 256 + temp) % 0x100000000000
            bitBufferLen = bitBufferLen + 8
        end
        bitBufferLen = bitBufferLen - n
        local result = math_floor(bitBuffer / 2^bitBufferLen)
        if n < 32 then result = result % 2^n end
        return result
    end
    function obj.readSignedInt(n)
        local v = obj.readUint(n)
        if v >= 2^(n-1) then v = v - 2^n end
        return v
    end
    function obj.readRiceSignedInt(param)
        local val = 0
        while (obj.readUint(1) == 0) do val = val + 1 end
        val = val * 2^param + obj.readUint(param)
        if bit32_btest(val, 1) then return -math_floor(val / 2) - 1
        else return math_floor(val / 2) end
    end
    return obj
end

local function decodeResiduals(inp, warmup, blockSize, result)
    local method = inp.readUint(2);
    if (method >= 2) then error("Reserved residual coding method " .. method) end
    local paramBits = method == 0 and 4 or 5;
    local escapeParam = method == 0 and 0xF or 0x1F;

    local partitionOrder = inp.readUint(4);
    local numPartitions = 2^partitionOrder;
    if (blockSize % numPartitions ~= 0) then
        error("Block size not divisible by number of Rice partitions")
    end
    local partitionSize = math_floor(blockSize / numPartitions);

    for i = 0, numPartitions-1 do
        local start = i * partitionSize + (i == 0 and warmup or 0);
        local endd = (i + 1) * partitionSize;

        local param = inp.readUint(paramBits);
        if (param < escapeParam) then
            for j = start, endd - 1 do
                result[j+1] = inp.readRiceSignedInt(param)
            end
        else
            local numBits = inp.readUint(5);
            for j = start, endd - 1 do
                result[j+1] = inp.readSignedInt(numBits)
            end
        end
    end
end

local function restoreLinearPrediction(result, coefs, shift, blockSize)
    for i = #coefs, blockSize - 1 do
        local sum = 0
        for j = 0, #coefs - 1 do
            sum = sum + result[i - j] * coefs[j + 1]
        end
        result[i + 1] = result[i + 1] + math_floor(sum / 2^shift)
    end
end

local function decodeFixedPredictionSubframe(inp, predOrder, sampleDepth, blockSize, result)
    for i = 1, predOrder do
        result[i] = inp.readSignedInt(sampleDepth);
    end
    decodeResiduals(inp, predOrder, blockSize, result);
    restoreLinearPrediction(result, FIXED_PREDICTION_COEFFICIENTS[predOrder+1], 0, blockSize);
end

local function decodeLinearPredictiveCodingSubframe(inp, lpcOrder, sampleDepth, blockSize, result)
    for i = 1, lpcOrder do
        result[i] = inp.readSignedInt(sampleDepth);
    end
    local precision = inp.readUint(4) + 1;
    local shift = inp.readSignedInt(5);
    local coefs = {};
    for i = 1, lpcOrder do
        coefs[i] = inp.readSignedInt(precision);
    end
    decodeResiduals(inp, lpcOrder, blockSize, result);
    restoreLinearPrediction(result, coefs, shift, blockSize);
end

local function decodeSubframe(inp, sampleDepth, blockSize, result)
    inp.readUint(1);
    local type = inp.readUint(6);
    local shift = inp.readUint(1);
    if (shift == 1) then
        while (inp.readUint(1) == 0) do shift = shift + 1 end
    end
    sampleDepth = sampleDepth - shift

    if (type == 0) then  -- Constant coding
        local c = inp.readSignedInt(sampleDepth)
        for i = 1, blockSize do result[i] = c end
    elseif (type == 1) then  -- Verbatim coding
        for i = 1, blockSize do
            result[i] = inp.readSignedInt(sampleDepth);
        end
    elseif (8 <= type and type <= 12) then
        decodeFixedPredictionSubframe(inp, type - 8, sampleDepth, blockSize, result)
    elseif (32 <= type and type <= 63) then
        decodeLinearPredictiveCodingSubframe(inp, type - 31, sampleDepth, blockSize, result)
    else
        error("Reserved subframe type")
    end

    for i = 1, blockSize do
        result[i] = result[i] * 2^shift
    end
end

local function decodeSubframes(inp, sampleDepth, chanAsgn, blockSize, result)
    local subframes = {}
    for i = 1, #result do subframes[i] = {} end
    if (0 <= chanAsgn and chanAsgn <= 7) then
        for ch = 1, #result do
            decodeSubframe(inp, sampleDepth, blockSize, subframes[ch])
        end
    elseif (8 <= chanAsgn and chanAsgn <= 10) then
        decodeSubframe(inp, sampleDepth + (chanAsgn == 9 and 1 or 0), blockSize, subframes[1])
        decodeSubframe(inp, sampleDepth + (chanAsgn == 9 and 0 or 1), blockSize, subframes[2])
        if (chanAsgn == 8) then
            for i = 1, blockSize do
                subframes[2][i] = subframes[1][i] - subframes[2][i]
            end
        elseif (chanAsgn == 9) then
            for i = 1, blockSize do
                subframes[1][i] = subframes[1][i] + subframes[2][i]
            end
        elseif (chanAsgn == 10) then
            for i = 1, blockSize do
                local side = subframes[2][i]
                local right = subframes[1][i] - math_floor(side / 2)
                subframes[2][i] = right
                subframes[1][i] = right + side
            end
        end
    else
        error("Reserved channel assignment");
    end
    for ch = 1, #result do
        for i = 1, blockSize do
            local s = subframes[ch][i]
            if s >= 2^(sampleDepth-1) then s = s - 2^sampleDepth end
            result[ch][i] = s / 2^sampleDepth
        end
    end
end

local function decodeFrame(inp, numChannels, sampleDepth, out2)
    local out = {}
    for i = 1, numChannels do out[i] = {} end
    -- Read a ton of header fields, and ignore most of them
    local temp = inp.readByte()
    if temp == nil then
        return false
    end
    local sync = temp * 64 + inp.readUint(6);
    if sync ~= 0x3FFE then error("Sync code expected") end

    inp.readUint(2);
    local blockSizeCode = inp.readUint(4);
    local sampleRateCode = inp.readUint(4);
    local chanAsgn = inp.readUint(4);
    inp.readUint(4);

    temp = inp.readUint(8);
    local t2 = -1
    for i = 7, 0, -1 do if not bit32_btest(temp, 2^i) then break end t2 = t2 + 1 end
    for i = 1, t2 do inp.readUint(8) end

    local blockSize
    if (blockSizeCode == 1) then
        blockSize = 192
    elseif (2 <= blockSizeCode and blockSizeCode <= 5) then
        blockSize = 576 * 2^(blockSizeCode - 2)
    elseif (blockSizeCode == 6) then
        blockSize = inp.readUint(8) + 1
    elseif (blockSizeCode == 7) then
        blockSize = inp.readUint(16) + 1
    elseif (8 <= blockSizeCode and blockSizeCode <= 15) then
        blockSize = 256 * 2^(blockSizeCode - 8)
    else
        error("Reserved block size")
    end

    if (sampleRateCode == 12) then
        inp.readUint(8)
    elseif (sampleRateCode == 13 or sampleRateCode == 14) then
        inp.readUint(16)
    end

    inp.readUint(8)

    decodeSubframes(inp, sampleDepth, chanAsgn, blockSize, out)
    inp.alignToByte()
    inp.readUint(16)

    for c = 1, numChannels do
        local n = #out2[c]
        for i = 1, blockSize do out2[c][n+i] = out[c][i] * 256 end
    end

    return true
end

local function intunpack(str, pos, sz, signed, be)
    local n = 0
    if be then for i = 0, sz - 1 do n = n * 256 + str_byte(str, pos+i) end
    else for i = 0, sz - 1 do n = n + str_byte(str, pos+i) * 2^(8*i) end end
    if signed and n >= 2^(sz*8-1) then n = n - 2^(sz*8) end
    return n, pos + sz
end

local function decodeFLAC(inp)
    local out = {}
    local pos = 1
    -- Handle FLAC header and metadata blocks
    local temp temp, pos = intunpack(inp, pos, 4, false, true)
    if temp ~= 0x664C6143 then error("Invalid magic string") end
    local sampleRate, numChannels, sampleDepth, numSamples
    local last = false
    local meta = {}
    while not last do
        temp, pos = str_byte(inp, pos), pos + 1
        last = bit32_btest(temp, 0x80)
        local type = bit32_band(temp, 0x7F);
        local length length, pos = intunpack(inp, pos, 3, false, true)
        if type == 0 then  -- Stream info block
            pos = pos + 10
            sampleRate, pos = intunpack(inp, pos, 2, false, true)
            sampleRate = sampleRate * 16 + bit32_rshift(str_byte(inp, pos), 4)
            numChannels = bit32_band(bit32_rshift(str_byte(inp, pos), 1), 7) + 1;
            sampleDepth = bit32_band(str_byte(inp, pos), 1) * 16 + bit32_rshift(str_byte(inp, pos+1), 4) + 1;
            numSamples, pos = intunpack(inp, pos + 2, 4, false, true)
            numSamples = numSamples + bit32_band(str_byte(inp, pos-5), 15) * 2^32
            pos = pos + 16
        else
            pos = pos + length
        end
    end
    if not sampleRate then error("Stream info metadata block absent") end
    if sampleDepth % 8 ~= 0 then error("Sample depth not supported") end

    for i = 1, numChannels do out[i] = {} end

    -- Decode FLAC audio frames and write raw samples
    inp = BitInputStream(inp, pos)
    repeat until not decodeFrame(inp, numChannels, sampleDepth, out)
    return out
end

--- Creates a new tracc state from an S3M file handle. This is a lossy conversion to XM!
---@param file file The file to read
---@return tracc state The new tracc state
function libtracc.readS3MFile(file)
    local patterns, order, instruments, mutedChannels = {}, {}, {}, {}
    local name, tracker
    local restartPosition, channelCount, tempo, bpm, amigaSlides
    local globalVolume = 64
    name = file.read(28):gsub("[ %z]+$", "")
    file.read()
    if file.read() ~= 16 then
        file.close()
        error("Not a valid XM/S3M module")
    end
    file.read(2)
    local numOrders = fromLE(file.read(2))
    local instrumentCount = fromLE(file.read(2))
    local patternCount = fromLE(file.read(2))
    file.read(2) -- flags
    tracker = s3mTrackers(fromLE(file.read(2))) or "Unknown"
    if fromLE(file.read(2)) ~= 2 then
        file.close()
        error("Unsupported S3M module")
    end
    if file.read(4) ~= "SCRM" then
        file.close()
        error("Not an S3M module")
    end
    globalVolume = file.read() / 256
    tempo = file.read()
    bpm = file.read()
    restartPosition = 0
    amigaSlides = true
    local isStereo = bit32.btest(file.read(), 0x80) -- master volume
    file.read() -- ultra click
    local hasChannelPan = file.read() == 252
    file.read(10)
    local channelPan = {}
    for i = 1, 32 do
        local s = file.read()
        if s == 255 or channelCount then
            if not channelCount then channelCount = i - 1 end
        else
            if bit32.btest(s, 0x80) then mutedChannels[i] = true end
            if bit32.btest(s, 0x10) then -- AdLib channel
                file.close()
                error("Unsupported S3M module")
            end
            channelPan[i] = isStereo and (bit32.btest(s, 0x08) and 0xCC or 0x33) or 0x77
        end
    end
    if not channelCount then channelCount = 32 end
    --print(numOrders)
    --print(file.seek())
    for i = 1, numOrders do
        local n = file.read()
        order[i] = n
    end
    --if numOrders % 2 == 1 then file.read() end
    local instPP, patPP = {}, {}
    for i = 1, instrumentCount do instPP[i] = fromLE(file.read(2)) * 16 end
    for i = 1, patternCount do patPP[i] = fromLE(file.read(2)) * 16 end
    if hasChannelPan then
        for i = 1, channelCount do
            local p = file.read()
            if bit32.btest(p, 0x20) then channelPan[i] = bit32.band(p, 0x0F) * 16 + bit32.band(p, 0x0F) end
        end
    end

    for i = 1, instrumentCount do
        local sample = {wavetable = {}, volume = 64, pan = 128}
        local inst = {
            samples = {},
            samplesByNumber = {sample},
            volumeEnvelope = {
                points = {},
                sustain = 0,
                loopStart = 0,
                loopEnd = 0,
                loopType = 0
            },
            panningEnvelope = {
                points = {},
                sustain = 0,
                loopStart = 0,
                loopEnd = 0,
                loopType = 0
            },
            vibrato = {
                type = 0,
                sweep = 0,
                depth = 0,
                rate = 0,
                sweep_mult = 0
            },
            fadeOut = 0
        }
        for j = 1, 96 do inst.samples[j] = sample end
        instruments[i] = inst
        --print(instPP[i])
        file.seek("set", instPP[i])
        local typ = file.read()
        --print(typ)
        if typ > 1 then
            file.close()
            error("Unsupported S3M module", 2)
        elseif typ == 1 then
            file.read(12) -- type, filename
            local dataPP = (file.read() * 65536 + fromLE(file.read(2))) * 16
            sample.size = fromLE(file.read(2)) + fromLE(file.read(2)) * 65536
            sample.loopStart = fromLE(file.read(2)) + fromLE(file.read(2)) * 65536
            sample.loopLength = fromLE(file.read(2)) + fromLE(file.read(2)) * 65536 - sample.loopStart
            sample.volume = file.read()
            file.read()
            local pack = file.read()
            local sflags = file.read()
            sample.type = bit32.band(sflags, 0x01) + bit32.band(sflags, 0x04) * 4
            local c2speed = fromLE(file.read(2)) + fromLE(file.read(2)) * 65536
            local note = 12 * math.log(c2speed / 8363, 2)
            sample.note = math.floor(note)
            sample.finetune = math.floor((note - sample.note) * 127)
            --print(c2speed, note, sample.note, sample.finetune)
            file.read(12)
            inst.name = file.read(28):gsub("[ %z]+$", "")
            sample.name = inst.name
            --print(inst.name)
            if file.read(4) ~= "SCRS" then
                file.close()
                error("Invalid S3M module")
            end
            --sleep(0.05)
            --print(dataPP)
            file.seek("set", dataPP)
            if bit32.btest(sflags, 0x04) then for j = 1, sample.size do sample.wavetable[j] = fromLE(file.read(2)) - 32768 end
            elseif pack == 0xFC then
                sample.wavetable = decodeFLAC(file.read(sample.size))[1]
                sample.size = #sample.wavetable
            else for j = 1, sample.size do sample.wavetable[j] = file.read() - 128 end end
            if bit32.btest(sflags, 0x02) then file.seek("cur", sample.size * bit32.btest(sflags, 0x04) / 2) end
        end
    end

    for i = 1, patternCount do
        local pattern = {}
        patterns[i] = pattern
        file.seek("set", patPP[i] + 2) -- skip size
        local g = {}
        for x = 1, 32 do g[x] = {x = 0} end
        for y = 1, 64 do
            pattern[y] = {}
            repeat
                local b = file.read()
                if b ~= 0 then
                    local x = bit32.band(b, 0x1F) + 1
                    pattern[y][x] = {}
                    if bit32.btest(b, 0x20) then
                        local n = file.read()
                        if n == 254 then pattern[y][x].note = 97
                        elseif n <= 127 then pattern[y][x].note = bit32.rshift(n, 4) * 12 + bit32.band(n, 15) + 1 end
                        n = file.read()
                        if n ~= 0 then pattern[y][x].instrument = n end
                    end
                    if bit32.btest(b, 0x40) then
                        local v = file.read()
                        if v ~= 255 then pattern[y][x].volume = v + 0x10 end
                    end
                    if bit32.btest(b, 0x80) then
                        local e, p = file.read(), file.read()
                        if e ~= 0 and s3mEffects[e] then
                            local ne, np, nv = s3mEffects[e](p, g[x])
                            pattern[y][x].effect, pattern[y][x].effect_param = ne, np
                            if nv and not pattern[y][x].volume then pattern[y][x].volume = nv end
                        end
                    end
                end
            until b == 0
        end
    end
    local state = {
        type = "s3m",
        tempo = tempo,
        bpm = bpm,
        channels = {},
        module = {
            instruments = instruments,
            patterns = patterns,
            order = order,
            name = name,
            tracker = tracker,
            amigaSlides = amigaSlides,
            restartPosition = restartPosition
        },
        speakers = {},
        order = 1,
        row = 1,
        globalVolume = globalVolume,
        mutedChannels = mutedChannels,
        mixVolume = 1,
        loop = true,
        sound = makeSound()
    }
    for i = 1, channelCount do
        state.channels[i] = {
            num = i,
            effectMemory = {},
            playing = {note = 0, instrument = 0, volume = 0, effect = 0, effect_param = 0},
            volume = 64,
            pan = channelPan[i],
            volumeEnvelope = {volume = 64, pos = 0, x = 0},
            vibrato = {type = 0, pos = 0}
        }
        if channelPan[i] then setPan(state, state.channels[i], channelPan[i]) end
    end
    return state
end

---@param state tracc
---@param e boolean
---@param ls number[]
---@param rs number[]|nil
---@param vu table
local function processTick(state, e, ls, rs, vu)
    for _,c in ipairs(state.channels) do
        --if not c.playing or c.playing.effect ~= 2 then effects[2](state, c, 0x02) end
        if e and c.playing and c.playing.effect then effects[c.playing.effect](state, c, c.playing.effect_param or 0) end
        if e and c.playing and c.playing.volume and c.playing.volume > 0x50 then volume_effects[math.floor(c.playing.volume / 16)](state, c, c.playing.volume % 16) end
        if c.instrument and c.instrument.volumeEnvelope.loopType % 2 == 1 and c.volumeEnvelope.pos > 0 and not c.volumeEnvelope.sustain and c.note then
            c.volumeEnvelope.x = c.volumeEnvelope.x + 1
            c.volumeEnvelope.volume = c.volumeEnvelope.volume + c.volumeEnvelope.rate
            if c.volumeEnvelope.x == c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos+1].x then
                c.volumeEnvelope.pos = c.volumeEnvelope.pos + 1
                if bit32.btest(c.instrument.volumeEnvelope.loopType, 4) and c.volumeEnvelope.pos == c.instrument.volumeEnvelope.loopEnd then
                    c.volumeEnvelope.pos = c.instrument.volumeEnvelope.loopStart
                    c.volumeEnvelope.x = c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos].x
                end
                c.volumeEnvelope.volume = c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos].y
                if c.volumeEnvelope.pos >= #c.instrument.volumeEnvelope.points or (bit32.btest(c.instrument.volumeEnvelope.loopType, 2) and c.volumeEnvelope.pos == c.instrument.volumeEnvelope.sustain) then c.volumeEnvelope.sustain = true
                else c.volumeEnvelope.rate = (c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos+1].y - c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos].y) / (c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos+1].x - c.instrument.volumeEnvelope.points[c.volumeEnvelope.pos].x) end
            end
            setVolume(state, c, c.volume)
        end
        if c.instrument and c.instrument.panningEnvelope.loopType % 2 == 1 and not c.panningEnvelope.sustain and c.note then
            c.panningEnvelope.x = c.panningEnvelope.x + 1
            c.panningEnvelope.panning = c.panningEnvelope.panning + c.panningEnvelope.rate
            if c.panningEnvelope.x == c.instrument.panningEnvelope.points[c.panningEnvelope.pos+1].x then
                c.panningEnvelope.pos = c.panningEnvelope.pos + 1
                if bit32.btest(c.instrument.panningEnvelope.loopType, 4) and c.panningEnvelope.pos == c.instrument.panningEnvelope.loopEnd then
                    c.panningEnvelope.pos = c.instrument.panningEnvelope.loopStart
                    c.panningEnvelope.x = c.instrument.panningEnvelope.points[c.panningEnvelope.pos].x
                end
                c.panningEnvelope.panning = c.instrument.panningEnvelope.points[c.panningEnvelope.pos].y
                if c.panningEnvelope.pos + 1 > #c.instrument.panningEnvelope.points or (bit32.btest(c.instrument.panningEnvelope.loopType, 2) and c.panningEnvelope.pos == c.instrument.panningEnvelope.sustain) then c.panningEnvelope.sustain = true
                else c.panningEnvelope.rate = (c.instrument.panningEnvelope.points[c.panningEnvelope.pos+1].y - c.instrument.panningEnvelope.points[c.panningEnvelope.pos].y) / (c.instrument.panningEnvelope.points[c.panningEnvelope.pos+1].x - c.instrument.panningEnvelope.points[c.panningEnvelope.pos].x) end
            end
            setPan(state, c, c.panningEnvelope.panning * 4)
        end
        if c.instrument and c.instrument.vibrato.depth > 0 then
            doVibrato(state, c, c.instrument.vibrato.type, c.instrument.vibrato.rate / 4, c.instrument.vibrato.depth * c.instrument.vibrato.sweep_mult / 4)
            if c.instrument.vibrato.sweep_mult < 1 then c.instrument.vibrato.sweep_mult = c.instrument.vibrato.sweep_mult + (1 / c.instrument.vibrato.sweep) end
        end
        c.didSetInstrument = false
    end
    local lss, rss, vuu = state.sound.generate(state, (2.5 / state.bpm) * 48000, #state.channels, rs)
    local sl, sr = #ls, rs and #rs
    for i = 1, #lss do ls[sl+i] = lss[i] end
    if rs then for i = 1, #rss do rs[sr+i] = rss[i] end end
    if vu[1] then for i = 1, #vuu do vu[i][1], vu[i][2] = vu[i][1] + vuu[i][1], vu[i][2] + vuu[i][2] end
    else for i = 1, #vuu do vu[i] = vuu[i] end end
    vu.count = (vu.count or 0) + 1
end

--- Processes a single tick in a state, placing the generated samples in a table.
---@param state tracc The state to tick
---@param stereo boolean Whether to generate stereo sound
---@param left number[]|nil Previous samples to append to on the left/mono channel, if requested
---@param right number[]|nil Previous samples to append to on the right channel, if requested
---@param vu number[][]|nil Previous VU sample info, if requested
---@return number[]|nil left Left/mono channel samples to play
---@return number[]|nil right Right channel samples to play, if stereo is true
---@return number[][]|nil vu VU information
function libtracc.tick(state, stereo, left, right, vu)
    left = left or {}
    right = right or (stereo and {} or nil)
    vu = vu or {}
    if state.tick then
        if state.tick < state.tempo then
            state.tick = state.tick + 1
            processTick(state, true, left, right, vu)
            return left, right, vu
        end
        if state.order ~= state.currentOrder then
            if not state.usedD then state.row = 1 end
            state.currentOrder = state.order
        elseif state.row == state.currentRow then
            state.row = state.row + 1
        end
    end
    local v = state.module.order[state.order]
    if not v then return nil end
    while v >= 254 or state.row > #state.module.patterns[v+1] do
        if state.order == state.currentOrder then
            state.row = 1
            state.order = state.order + 1
            if state.loop and state.order > #state.module.order then state.order = state.module.restartPosition + 1 end
        end
        state.currentOrder = state.order
        v = state.module.order[state.order]
        if not v then return nil end
    end
    state.tick = 1
    state.currentRow = state.row
    state.usedB, state.usedD = nil, nil
    local row = state.module.patterns[v+1][state.row]
    if not row then error((v + 1) .. "/" .. state.row) end
    for _,x in ipairs(state.speakers) do x.usage = 0 end
    for k,c in ipairs(state.channels) do
        c.playing = row[k]
        if c.playing then
            local setLastFrequency = false
            if c.playing.instrument and state.module.instruments[c.playing.instrument] then
                setInstrument(state, c, c.playing.instrument)
                if (state.type == "xm" or c.pan == nil) and (c.playing.note or c.lastNote) ~= 97 then setPan(state, c, c.instrument.samples[c.playing.note or c.lastNote].pan) end
                if state.type ~= "xm" and not (c.playing.note and c.playing.note ~= 0) and c.lastNote then
                    c.lastFrequency = c.frequency
                    setLastFrequency = true
                    setNote(state, c, c.lastNote)
                    setVolume(state, c, c.instrument.samples[c.lastNote].volume)
                end
            end
            if c.playing.volume then volume_effects[math.floor(c.playing.volume / 16)](state, c, c.playing.volume % 16) end
            if c.playing.note and c.playing.note ~= 0 then
                if (not c.playing.volume or c.playing.volume < 0x10 or c.playing.volume >= 0x60) and c.playing.note < 97 then setVolume(state, c, c.instrument.samples[c.playing.note].volume) end
                if not setLastFrequency then c.lastFrequency = c.frequency end
                if not c.playing.effect or c.playing.effect == 9 or effects[c.playing.effect](state, c, c.playing.effect_param or 0) ~= 0 then
                    if c.playing.note ~= 97 then c.lastNote = c.playing.note end
                    setNote(state, c, c.playing.note)
                end
            end
            if (not c.playing.note or c.playing.note == 0 or c.playing.effect == 9) and c.playing.effect then effects[c.playing.effect](state, c, c.playing.effect_param or 0) end
        end
    end
    processTick(state, false, left, right, vu)
    return left, right, vu
end

--- Processes a single row in a state, placing the generated samples in a table.
---@param state tracc The state to tick
---@param stereo boolean Whether to generate stereo sound
---@param left number[]|nil Previous samples to append to on the left/mono channel, if requested
---@param right number[]|nil Previous samples to append to on the right channel, if requested
---@param vu number[][]|nil Previous VU sample info, if requested
---@return number[]|nil left Left/mono channel samples to play
---@return number[]|nil right Right channel samples to play, if stereo is true
---@return number[][]|nil vu VU information
function libtracc.row(state, stereo, left, right, vu)
    left = left or {}
    right = right or (stereo and {} or nil)
    vu = vu or {}
    if not state.tick or state.tick >= state.tempo then if not libtracc.tick(state, stereo, left, right, vu) then return nil end end
    while state.tick < state.tempo do if not libtracc.tick(state, stereo, left, right, vu) then return nil end end
    return left, right, vu
end

-- Internal note: this function is the only code that explicitly requires CraftOS!

--- Plays a module state on supplied speakers. This can be put into a coroutine
--- manager like parallel or Taskmaster.
---@overload fun(state: tracc, ...)
---@overload fun(state: tracc, volume: number, ...)
---@param state tracc The state to play
---@param volume number The volume to play at (defaults to 1, 100%/16 blocks)
---@param bufferSize number The minimum number of samples to buffer at once (defaults to 48000) - set to 1 for realtime playback
---@param ... table The speaker(s) to play on - if there are multiple, left/right speakers alternate
function libtracc.play(state, volume, bufferSize, ...)
    local speakers = {...}
    if type(volume) == "table" then table.insert(speakers, 1, volume) volume = nil end
    if type(bufferSize) == "table" then table.insert(speakers, 1, bufferSize) bufferSize = nil end
    local wait = {}
    while true do
        local left, right = {}, {}
        while #left < (bufferSize or 48000) do
            if not libtracc.row(state, #speakers > 1, left, right) then return end
        end
        while next(wait) do
            local _, name = os.pullEvent("speaker_audio_empty")
            wait[name] = nil
        end
        for i = 1, #speakers do
            speakers[i].playAudio(i % 2 == 1 and left or right, volume)
            wait[peripheral.getName(speakers[i])] = true
        end
    end
end

--- Creates a "file handle" over string data, which is useful for loading modules
--- that are not in a file.
---@param data string The data that the file will represent
---@return file file The new file handle
function libtracc.makeFile(data)
    local pos = 1
    local closed = false
    return {
        readLine = function(newline)
            if closed then error("attempt to use a closed file", 2) end
            if pos > #data then return nil end
            local d
            d, pos = data:match("([^\n]*" .. (newline and "\n?)" or ")\n?") .. "()", pos)
            return d
        end,
        readAll = function()
            if closed then error("attempt to use a closed file", 2) end
            if pos > #data then return nil end
            local d = data:sub(pos)
            pos = #d + 1
            return d
        end,
        read = function(n)
            if closed then error("attempt to use a closed file", 2) end
            if n ~= nil and type(n) ~= "number" then error("bad argument #1 (expected number, got " .. type(n) .. ")", 2) end
            if pos > #data then return nil end
            if n then
                local d = data:sub(pos, pos + n - 1)
                pos = pos + n
                return d
            else
                local d = data:byte(pos)
                pos = pos + 1
                return d
            end
        end,
        seek = function(whence, offset)
            if whence ~= nil and type(whence) ~= "string" then error("bad argument #1 (expected string, got " .. type(whence) .. ")", 2) end
            if offset ~= nil and type(offset) ~= "number" then error("bad argument #2 (expected number, got " .. type(offset) .. ")", 2) end
            whence = whence or "cur"
            offset = offset or 0
            if closed then error("attempt to use closed file", 2) end
            if whence == "set" then pos = offset + 1
            elseif whence == "cur" then pos = pos + offset
            elseif whence == "end" then pos = math.max(#data - offset, 1)
            else error("Invalid whence", 2) end
            return pos - 1
        end,
        close = function()
            if closed then error("attempt to use a closed file", 2) end
            closed = true
        end
    }
end

return libtracc
