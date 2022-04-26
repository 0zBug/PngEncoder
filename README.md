# PngEncoder
A module that turns a Bitmap into a raw png file.
Supports rgb and rgba png formats.

# Example
```lua
local Bitmap = {}

for y = 1, 255 do
    Bitmap[y] = {}
    for x = 1, 255 do
        Bitmap[y][x] = {x, y, math.sqrt(x * y)}
    end
end

writefile("example.png", BitmapToPng(Bitmap, "rgb"))
```

# Output
![](https://raw.githubusercontent.com/0zBug/PngEncoder/main/example.png)
