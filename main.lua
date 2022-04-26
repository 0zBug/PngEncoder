
local function BitmapToPng(Bitmap, ColorMode)
    local height, width = #Bitmap, #Bitmap[1]
    local ColorMode = ColorMode or "rgb"

    local bytesPerPixel, HeaderType = ColorMode == "rgb" and 3 or 4, ColorMode == "rgb" and 2 or 6

    local RowSize = width * bytesPerPixel + 1
    local Remain = RowSize * height
    local iDat = (math.ceil(Remain / 0xFFFF) * 5 + 6) + Remain

    local Header = {
        0x89, 0x50, 0x4E, 0x47, 
        0x0D, 0x0A, 0x1A, 0x0A, 
        0x00, 0x00, 0x00, 0x0D, 
        0x49, 0x48, 0x44, 0x52, 
        0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 
        0x08, HeaderType, 0x00, 
        0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x49, 0x44, 
        0x41, 0x54, 0x08, 0x1D
    }

    for i = 0, 3 do Header[17 + i] = bit32.band(bit32.rshift(width, (3 - i) * 8), 0xFF) end
    for i = 0, 3 do Header[21 + i] = bit32.band(bit32.rshift(height, (3 - i) * 8), 0xFF) end
    for i = 0, 3 do Header[34 + i] = bit32.band(bit32.rshift(iDat, (3 - i) * 8), 0xFF) end

    local CRC = 0xFFFFFFFF

    for i = 13, 29 do
        for j = 0, 7 do 
            CRC = bit32.bxor(bit32.rshift(CRC, 1), bit32.band((-bit32.band(bit32.bxor(CRC, bit32.rshift(Header[i], j)), 1)), 0xEDB88320))
        end
    end

    for i = 0, 3 do Header[30 + i] = bit32.band(bit32.rshift(bit32.bnot(CRC), (3 - i) * 8), 0xFF) end
    
    local PNG = string.char(unpack(Header))

    local X, Y = 0, 0
    local Adler = 0
    local Deflate = 0

    for y, Section in pairs(Bitmap) do
        for x, Pixel in pairs(Section) do
            local Count = #Pixel
            local Pointer = 1

            while Count > 0 do
                if Deflate == 0 then
                    local Size = 0xFFFF
                    if (Remain < Size) then
                        Size = Remain
                    end

                    local Header = {
                        bit32.band((Remain <= 0xFFFF and 1 or 0), 0xFF),
                        bit32.band(bit32.rshift(Size, 0), 0xFF),
                        bit32.band(bit32.rshift(Size, 8), 0xFF),
                        bit32.band(bit32.bxor(bit32.rshift(Size, 0), 0xFF), 0xFF),
                        bit32.band(bit32.bxor(bit32.rshift(Size, 8), 0xFF), 0xFF),
                    }

                    PNG = PNG .. string.char(unpack(Header))

                    CRC = bit32.bnot(CRC)
                    for i = 1, #Header do
                        for j = 0, 7 do 
                            CRC = bit32.bxor(bit32.rshift(CRC, 1), bit32.band((-bit32.band(bit32.bxor(CRC, bit32.rshift(Header[i], j)), 1)), 0xEDB88320))
                        end
                    end
                    CRC = bit32.bnot(CRC)
                end

                if (X == 0) then
                    PNG = PNG .. string.char(0)

                    CRC = bit32.bnot(CRC)

                    for j = 0, 7 do 
                        CRC = bit32.bxor(bit32.rshift(CRC, 1), bit32.band((-bit32.band(bit32.bxor(CRC, bit32.rshift(0, j)), 1)), 0xEDB88320))
                    end

                    CRC = bit32.bnot(CRC)

                    local s1 = bit32.band(Adler, 0xFFFF)
                    local s2 = bit32.rshift(Adler, 16)

                    Adler = bit32.bor(bit32.lshift((s2 + s1) % 65521, 16), s1 % 65521)

                    X = X + 1
                    Remain = Remain - 1
                    Deflate = Deflate + 1
                else
                    local n = 0xFFFF - Deflate;
                    if (RowSize - X < n) then
                        n = RowSize - X
                    end
                    if (Count < n) then
                        n = Count
                    end

                    for i = Pointer, Pointer + n - 1 do
                        PNG = PNG .. string.char(Pixel[i])
                    end

                    CRC = bit32.bnot(CRC)

                    for i = Pointer, Pointer + n - 1 do
                        for j = 0, 7 do 
                            CRC = bit32.bxor(bit32.rshift(CRC, 1), bit32.band((-bit32.band(bit32.bxor(CRC, bit32.rshift(Pixel[i], j)), 1)), 0xEDB88320));
                        end
                    end
                    
                    CRC = bit32.bnot(CRC)

                    local s1 = bit32.band(Adler, 0xFFFF)
                    local s2 = bit32.rshift(Adler, 16)

                    for i = Pointer, Pointer + n - 1 do
                        s1 = (s1 + Pixel[i]) % 65521
                        s2 = (s2 + s1) % 65521
                    end

                    Adler = bit32.bor(bit32.lshift(s2, 16), s1)

                    Count = Count - n
                    Pointer = Pointer + n
                    X = X + n
                    Remain = Remain - n
                    Deflate = Deflate + n
                end

                if (Deflate >= 0xFFFF) then
                    Deflate = 0;
                end

                if (X == RowSize) then
                    X = 0
                    if (Y == #Bitmap) then
                        local Footer = { 
                            0x00, 0x00, 0x00, 0x00,
                            0x00, 0x00, 0x00, 0x00,
                            0x00, 0x00, 0x00, 0x00,
                            0x49, 0x45, 0x4E, 0x44,
                            0xAE, 0x42, 0x60, 0x82,
                        }

                        for i = 0, 3 do Footer[1 + i] = bit32.band(bit32.rshift(Adler, (3 - i) * 8), 0xFF) end

                        for i = 1, 4 do
                            for j = 0, 7 do 
                                CRC = bit32.bxor(bit32.rshift(CRC, 1), bit32.band((-bit32.band(bit32.bxor(CRC, bit32.rshift(Footer[i], j)), 1)), 0xEDB88320))
                            end
                        end

                        for i = 0, 3 do Footer[5 + i] = bit32.band(bit32.rshift(bit32.bnot(CRC), (3 - i) * 8), 0xFF) end

                        PNG = PNG .. string.char(unpack(Footer))
                    end

                    Y = Y + 1
                end
            end
        end
    end

    return PNG
end
