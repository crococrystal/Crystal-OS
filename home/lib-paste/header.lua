local component = require("component")
local term = require("term")
local fs = require("filesystem")
local gpu = component.gpu

local header = {}

-- Функция для чтения текста правого заголовка из файла name-header.json
local function readRightHeaderText()
    local filePath = "/home/lib-paste/name-header.json"
    if fs.exists(filePath) then
        local file = io.open(filePath, "r")
        if file then
            local content = file:read("*a")
            file:close()
            return content:match('"rightText"%s*:%s*"(.-)"') or "Right-Header"
        end
    end
    return "Right-Header"
end

-- Функция для вычисления текущего разрешения экрана
function header.getCurrentResolution()
    return gpu.getResolution()
end

-- Основная функция установки заголовка
function header.setHeader(settings)
    local width, height = header.getCurrentResolution()
    height = 3 -- Высота заголовка фиксирована

    -- Чтение правого текста из файла, если он не указан в настройках
    local rightText = settings.RightText or readRightHeaderText()
    local leftText = settings.LeftText or "Left-Header"
    local centerText = settings.CenterText or "Center-Header"

    -- Установка цветов
    gpu.setBackground(settings.Color or 0x8000FF)
    gpu.setForeground(0xFFFFFF)

    -- Очистка пространства для заголовка и установка пробелов с фоном
    for y = 1, height do
        term.setCursor(1, y)
        gpu.fill(1, y, width, 1, " ")
    end

    -- Установка текста по левому краю
    gpu.setForeground(settings.ColorLeftText or 0xFFFFFF)
    term.setCursor(1, 2)
    io.write(leftText)

    -- Установка текста по правому краю
    gpu.setForeground(settings.ColorRightText or 0xFFFFFF)
    local rightX = width - string.len(rightText)
    term.setCursor(rightX, 2)
    io.write(rightText)

    -- Установка текста по центру
    gpu.setForeground(settings.ColorCenterText or 0xFFFFFF)
    local centerX = math.floor((width - string.len(centerText)) / 2)
    term.setCursor(centerX, 2)
    io.write(centerText)

    -- Возвращаем цвет фона на черный и цвет текста на белый
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function header.setCursor(x, y)
    term.setCursor(x, y)
end

function header.printColored(text, color)
    gpu.setForeground(color or 0xFFFFFF)
    io.write(text)
    gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
end

return header
