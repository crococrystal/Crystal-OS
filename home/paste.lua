-- тест пасты
local term = require("term")
local fs = require("filesystem")
local shell = require("shell")
local serialization = require("serialization")
local component = require("component")
package.path = package.path .. ";/home/lib-paste/?.lua" -- добавляем путь для поиска библиотек
local header = require("header")
local gpu = component.gpu

local configDir = "/home/config"
local logFile = configDir .. "/paste-data.json"
local lastUpdateFile = configDir .. "/paste-last-update.json"
local screenWidth, screenHeight = gpu.getResolution()

local function ensureConfigDir()
    if not fs.exists(configDir) then
        fs.makeDirectory(configDir)
    end
end

local function clearScreen()
    gpu.setBackground(0x000000) -- Черный фон
    term.clear()
    term.setCursor(1, 1)
end

local function printColored(y, text, color)
    term.setCursor(1, y)
    gpu.setForeground(color)
    print(text)
    gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
end

local function writeFile(filePath, data)
    ensureConfigDir()
    local file, err = io.open(filePath, "w")
    if not file then
        error("Ошибка открытия файла для записи: " .. err)
    end
    file:write(serialization.serialize(data))
    file:close()
end

local function readFile(filePath)
    if fs.exists(filePath) then
        local file, err = io.open(filePath, "r")
        if not file then
            error("Ошибка открытия файла для чтения: " .. err)
        end
        local data = file:read("*a")
        file:close()
        return serialization.unserialize(data)
    else
        return nil
    end
end

local function saveLog(data)
    writeFile(logFile, data)
end

local function saveLastUpdate(data)
    writeFile(lastUpdateFile, data)
end

local function loadLog()
    return readFile(logFile) or {programs = {}, last = nil}
end

local function loadLastUpdate()
    return readFile(lastUpdateFile)
end

local function pastebinGet(code, filename)
    shell.execute("pastebin get -f " .. code .. " " .. filename .. " > /dev/null 2>&1")
end

local function pastebinPut(filePath)
    local handle = io.popen("pastebin put " .. filePath)
    local result = handle:read("*a")
    handle:close()
    return result:match("pastebin.com/(%w+)")
end

local function setLastProgram(log, entry)
    log.last = entry
    saveLog(log)
    saveLastUpdate(entry)
end

local function addProgramToList(entry)
    local log = loadLog()
    for i, e in ipairs(log.programs) do
        if e.filename == entry.filename then
            log.programs[i] = entry
            saveLog(log)
            return
        end
    end
    table.insert(log.programs, entry)
    saveLog(log)
end

local function removeProgramFromList(entry)
    local log = loadLog()
    for i, e in ipairs(log.programs) do
        if e.filename == entry.filename then
            table.remove(log.programs, i)
            break
        end
    end
    saveLog(log)
end

local function ensureDirectoryForFile(filePath)
    local dir = fs.path(filePath)
    if not fs.exists(dir) then
        fs.makeDirectory(dir)
    end
end

local function downloadProgram()
    clearScreen()
    header.setHeader{
        LeftText = "PastebinDownloader",
        CenterText = "",
        Color = 0x8000FF,
        ResolutionWidth = screenWidth
    }
    printColored(5, "Отправьте адрес:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 7)
    local address = term.read():gsub("\n", "")
    if #address ~= 8 then
        printColored(9, "Неверно указан адрес программы", 0xFD8777) -- Красный цвет
        print()
        printColored(11, "Введите Enter чтобы вернуться в главное меню", 0x808080) -- Серый цвет
        term.setCursor(1, 7)
        term.read()
        return
    end

    header.setHeader{
        LeftText = "PastebinDownloader",
        CenterText = "",
        Color = 0x8000FF,
        ResolutionWidth = screenWidth
    }
    printColored(5, "Отправьте название программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 6)
    printColored(7, "Например 3d.lua:", 0x808080) -- Серый цвет
    term.setCursor(1, 8)
    local name = term.read():gsub("\n", "")
    if name == "" then return end

    printColored(10, "Отправьте описание программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 12)
    local description = term.read():gsub("\n", "")
    if description == "" then return end

    printColored(15, "Укажите полный путь программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 16)
    printColored(16, "Например: /home/3d-models/crystal.3d", 0x808080) -- Серый цвет
    printColored(18, "Нажмите Enter чтобы сохранить в /home", 0x808080) -- Серый цвет
    term.setCursor(1, 19)
    local filePath = term.read():gsub("\n", "")
    if filePath == "" then
        filePath = "/home/" .. name
    end

    ensureDirectoryForFile(filePath)
    pastebinGet(address, filePath)
    local log = loadLog()
    local entry = {address = address, filename = filePath, description = description}
    setLastProgram(log, entry)
    addProgramToList(entry)

    print()
    printColored(23, "Программа скачана и сохранена как " .. filePath, 0x00FF00) -- Зеленый текст
    print()
    printColored(23, "1. Открыть программу", 0xFFFF00) -- Желтый цвет
    printColored(24, "2. Удалить программу", 0xFFFFFF) -- Белый цвет
    print()
    printColored(26, "Введите Enter чтобы вернуться в главное меню", 0x808080) -- Серый цвет

    term.setCursor(1, 27)
    local choice = term.read():gsub("\n", "")
    if choice == "1" then
        shell.execute(filePath)
    elseif choice == "2" then
        fs.remove(filePath)
        printColored(29, "Программа удалена.", 0xFFA9DD) -- Красный текст
    end
end

local function createProgram()
    clearScreen()
    header.setHeader{
        LeftText = "Создание программы",
        CenterText = "",
        Color = 0x8000FF,
        ResolutionWidth = screenWidth
    }
    printColored(1, "Введите название программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 2)
    local name = term.read():gsub("\n", "")
    if name == "" then return end

    printColored(4, "Введите описание программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 5)
    local description = term.read():gsub("\n", "")
    if description == "" then return end

    printColored(7, "Введите полный путь к программе с именем:", 0xFFFF00) -- Желтый цвет
    printColored(8, "Например: /home/3d/model.3d", 0x808080) -- Серый цвет
    term.setCursor(1, 9)
    local filePath = term.read():gsub("\n", "")
    if filePath == "" then return end

    ensureDirectoryForFile(filePath)
    local file = io.open(filePath, "w")
    file:close()

    local log = loadLog()
    local entry = {address = "", filename = filePath, description = description}
    setLastProgram(log, entry)
    addProgramToList(entry)

    printColored(11, "Программа создана и сохранена как " .. filePath, 0x00FF00) -- Зеленый текст
    os.sleep(2)
    shell.execute("edit " .. filePath) -- Открываем редактор для новой программы
end

local function editProgram(entry)
    local installed = fs.exists(entry.filename)
    clearScreen()
    header.setHeader{
        LeftText = "Настройка программы",
        CenterText = "Crystal-OS",
        Color = 0xFF00B8,
        ResolutionWidth = screenWidth
    }
    printColored(1, "Настройка программы: ", 0xFFFFFF)
    term.setCursor(22, 1)
    gpu.setForeground(0x56AF60) -- Зеленый цвет для названия программы
    print(fs.name(entry.filename))
    gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
    print()
    printColored(3, "Адресс: ", 0xFFFFFF)
    gpu.setForeground(0x74BCEF) -- Голубой цвет
    term.setCursor(9, 3)
    print(entry.address)
    gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
    print()
    printColored(5, "1. Открыть программу", 0xFFFF00) -- Желтый цвет
    printColored(6, "2. Обновить программу", 0xFFFF00) -- Белый цвет
    printColored(7, "3. Удалить программу", 0xFFFFFF) -- Белый цвет
    printColored(8, "4. Редактировать адрес pastebin", 0xFFFFFF) -- Белый цвет
    printColored(9, "5. Редактировать описание программы", 0xFFFFFF) -- Белый цвет
    printColored(10, "6. Редактировать путь файла", 0xFFFFFF) -- Белый цвет
    printColored(11, "7. Удалить из истории загрузок", 0xFFFFFF) -- Белый цвет
    printColored(12, "8. Открыть код программы", 0xFFFFFF) -- Белый цвет
    print()
    printColored(13, "Введите номер для редактирования или Enter чтобы вернуться в главное меню", 0x808080) -- Серый цвет

    term.setCursor(1, 14)
    local choice = term.read():gsub("\n", "")
    if choice == "1" then
        if installed then
            shell.execute(entry.filename)
        else
            printColored(15, "Программа не установлена, начинаю загрузку...", 0xFF7F7F) -- Красный цвет
            pastebinGet(entry.address, entry.filename)
            setLastProgram(loadLog(), entry)
            addProgramToList(entry)
        end
    elseif choice == "2" then
        printColored(15, "Выполняю обновление программы по пути " .. entry.filename, 0xFDFFA9) -- Желтый цвет
        pastebinGet(entry.address, entry.filename)
        setLastProgram(loadLog(), entry)
        addProgramToList(entry)
        printColored(17, "Программа обновлена.", 0x45B77B) -- Зеленый текст
    elseif choice == "3" then
        if installed then
            fs.remove(entry.filename)
            printColored(15, "Программа удалена.", 0xFF7F7F) -- Красный текст
        end
        os.sleep(2)
        return true
    elseif choice == "4" then
        printColored(15, "Текущий адрес: ", 0xFFFFFF)
        term.setCursor(16, 15)
        gpu.setForeground(0x74BCEF) -- Голубой цвет
        print(entry.address)
        gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
        print()
        printColored(17, "Отправьте новый адрес pastebin:", 0xFF7F7F) -- Желтый цвет
        term.setCursor(1, 18)
        local newAddress = term.read():gsub("\n", "")
        if newAddress ~= "" then
            entry.address = newAddress
            addProgramToList(entry)
        end
    elseif choice == "5" then
        printColored(15, "Текущее описание: ", 0xFFFFFF)
        term.setCursor(18, 15)
        gpu.setForeground(0x808080) -- Серый цвет
        print(entry.description)
        gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
        print()
        printColored(17, "Отправьте новое описание программы:", 0xFF7F7F) -- Желтый цвет
        term.setCursor(1, 18)
        local newDescription = term.read():gsub("\n", "")
        if newDescription ~= "" then
            entry.description = newDescription
            addProgramToList(entry)
        end
    elseif choice == "6" then
        printColored(15, "Текущий путь файла: ", 0xFFFFFF)
        term.setCursor(20, 15)
        gpu.setForeground(0x808080) -- Серый цвет
        print(entry.filename)
        gpu.setForeground(0xFFFFFF) -- Белый цвет по умолчанию
        print()
        printColored(17, "Отправьте новый путь файла:", 0xFFFF00) -- Желтый цвет
        term.setCursor(1, 18)
        local newFilename = term.read():gsub("\n", "")
        if newFilename ~= "" then
            ensureDirectoryForFile(newFilename)
            fs.rename(entry.filename, newFilename)
            entry.filename = newFilename
            addProgramToList(entry)
        end
    elseif choice == "7" then
        removeProgramFromList(entry)
        printColored(15, "Программа удалена из истории загрузок.", 0xFFA9DD) -- Красный текст
        os.sleep(2)
        return true
    elseif choice == "8" then
        shell.execute("edit " .. entry.filename)
    end
    return false
end

local function addLocalProgramToCollection()
    clearScreen()
    header.setHeader{
        LeftText = "Добавление локальной программы",
        CenterText = "Crystal-OS",
        Color = 0xFF00B8,
        ResolutionWidth = screenWidth
    }
    printColored(1, "Содержимое директории /home:", 0xFDFFA9) -- Желтый цвет
    term.setCursor(1, 3)
    shell.execute("ls /home")

    print()
    printColored(4, "Укажите полный путь программы. Например: /home/model.3d", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 5)
    local filePath = term.read():gsub("\n", "")
    if filePath == "" or not fs.exists(filePath) then
        print()
        printColored(6, "Неверный путь или файл не существует.", 0xFF0000) -- Красный цвет
        os.sleep(2)
        return
    end

    local address = pastebinPut(filePath)
    if not address then
        printColored(6, "Ошибка загрузки на Pastebin.", 0xFF0000) -- Красный цвет
        os.sleep(2)
        return
    end

    printColored(7, "Введите описание программы:", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 8)
    local description = term.read():gsub("\n", "")
    if description == "" then return end

    printColored(9, "Введите полный путь программы с указанием имени файла. Например: /home/3d/model.3d", 0xFFFF00) -- Желтый цвет
    term.setCursor(1, 10)
    local newFilePath = term.read():gsub("\n", "")
    if newFilePath == "" then return end

    local log = loadLog()
    local entry = {address = address, filename = newFilePath, description = description}
    setLastProgram(log, entry)
    addProgramToList(entry)

    printColored(11, "Программа добавлена в коллекцию с адресом Pastebin: " .. address, 0x00FF00) -- Зеленый текст
    os.sleep(2)
end

local function showDownloadHistory()
    local log = loadLog()
    if #log.programs == 0 then
        clearScreen()
        header.setHeader{
            LeftText = "История загрузок",
            CenterText = "Crystal-OS",
            Color = 0xFF00B8,
            ResolutionWidth = screenWidth
        }
        printColored(1, "История загрузок пуста.", 0xFFFFFF)
        os.sleep(2)
        return
    end

    local page = 1
    local itemsPerPage = 5

    while true do
        clearScreen()
        header.setHeader{
            LeftText = "Список всех программ",
            CenterText = "Crystal-OS",
            Color = 0xFF00B8,
            ResolutionWidth = screenWidth
        }

        -- Печатаем пустые строки для создания промежутка
        term.setCursor(1, 4)
        print(string.rep(" ", screenWidth))
        term.setCursor(1, 5)
        print(string.rep(" ", screenWidth))
        term.setCursor(1, 6)
        print(string.rep(" ", screenWidth))

        -- Устанавливаем начальную позицию для вывода списка программ после пустых строк
        local y = 7
        local startIndex = (page - 1) * itemsPerPage + 1
        local endIndex = math.min(startIndex + itemsPerPage - 1, #log.programs)

        for i = startIndex, endIndex do
            local entry = log.programs[i]
            -- Печатаем номер и название программы на одной строке
            local color = fs.exists(entry.filename) and 0x56AF60 or 0xFFFFFF -- Зеленый цвет для существующих файлов
            term.setCursor(1, y)
            printColored(y, tostring(i) .. ". " .. fs.name(entry.filename), 0xFFFFFF)

            -- Печатаем описание программы
            y = y + 1
            term.setCursor(1, y)
            printColored(y, "INFO: " .. entry.description, 0x808080)

            -- Печатаем статус программы
            y = y + 1
            term.setCursor(1, y)
            if fs.exists(entry.filename) then
                printColored(y, "[Установлено]", 0x56AF60)
            else
                printColored(y, "[Не найдено]", 0xFF7F7F)
            end

            -- Печатаем разделительную линию
            y = y + 1
            term.setCursor(1, y)
            print(string.rep("-", screenWidth))

            -- Переход к следующей позиции для следующей программы
            y = y + 1
        end

        -- Сообщение для пользователя
        term.setCursor(1, y)
        printColored(y, "Введите номер для редактирования программы или Enter чтобы вернуться в главное меню", 0x808080)

        term.setCursor(1, y + 1)
        printColored(y + 1, "Страница " .. page .. " из " .. math.ceil(#log.programs / itemsPerPage), 0x808080)
        printColored(y + 2, "Введите < или > для перемещения по страницам", 0x808080)

        term.setCursor(1, y + 3)
        local choice = term.read():gsub("\n", "")
        if choice == "" then
            return
        elseif choice == "<" and page > 1 then
            page = page - 1
        elseif choice == ">" and page < math.ceil(#log.programs / itemsPerPage) then
            page = page + 1
        else
            local index = tonumber(choice)
            if index and log.programs[index] then
                local entry = log.programs[index]
                if editProgram(entry) then
                    showDownloadHistory()
                    return
                end
            end
        end
    end
end

local function main()
    while true do
        clearScreen()
        header.setHeader{
            LeftText = "Главное меню PasteCloud",
            CenterText = "",
            Color = 0x8000FF,
            ResolutionWidth = screenWidth
        }
        printColored(4, "1. Обновить последнюю программу", 0x00FFFF) -- Голубой цвет
        printColored(5, "2. Загрузить с pastebin", 0xFFFFFF) -- Белый цвет
        printColored(6, "3. Создать новую программу", 0xFFFFFF) -- Белый цвет
        printColored(7, "4. Добавить локальную программу в коллекцию", 0xFFFFFF) -- Белый цвет
        print()
        printColored(8, "5. Редактировать последнюю программу", 0xFFFFFF) -- Белый цвет
        printColored(9, "6. Открыть последнюю программу", 0xFFFFFF) -- Белый цвет
        printColored(10, "7. Коллекция программ", 0xFFFFFF) -- Белый цвет
        print()
        printColored(11, "Введите Enter чтобы выйти из программы", 0x808080) -- Серый цвет

        term.setCursor(1, 12)
        local choice = term.read():gsub("\n", "")

        if choice == "1" then
            local log = loadLog()
            if log.last then
                local lastEntry = log.last
                clearScreen()
                header.setHeader{
                    LeftText = "Обновление программы",
                    CenterText = "",
                    Color = 0x8000FF,
                    ResolutionWidth = screenWidth
                }
                printColored(1, "Обновление программы " .. lastEntry.filename, 0xFFFFFF)
                pastebinGet(lastEntry.address, lastEntry.filename)
                printColored(3, "Программа обновлена.", 0x00FF00) -- Зеленый текст
                os.sleep(2)
                shell.execute(lastEntry.filename) -- Автоматически запускаем программу после обновления
            else
                clearScreen()
                header.setHeader{
                    LeftText = "Ошибка",
                    CenterText = "",
                    Color = 0x8000FF,
                    ResolutionWidth = screenWidth
                }
                printColored(1, "Нет информации о последней скачанной программе.", 0xFF0000) -- Красный текст
                os.sleep(2)
            end

        elseif choice == "2" then
            downloadProgram()

        elseif choice == "3" then
            createProgram()

        elseif choice == "4" then
            addLocalProgramToCollection()

        elseif choice == "5" then
            local lastEntry = loadLastUpdate()
            if lastEntry then
                editProgram(lastEntry)
            else
                clearScreen()
                header.setHeader{
                    LeftText = "Ошибка",
                    CenterText = "",
                    Color = 0x8000FF,
                    ResolutionWidth = screenWidth
                }
                printColored(1, "Нет последней программы для редактирования.", 0xFF0000) -- Красный текст
                os.sleep(2)
            end

        elseif choice == "6" then
            local lastEntry = loadLastUpdate()
            if lastEntry then
                shell.execute(lastEntry.filename)
            else
                clearScreen()
                header.setHeader{
                    LeftText = "Ошибка",
                    CenterText = "",
                    Color = 0x8000FF,
                    ResolutionWidth = screenWidth
                }
                printColored(1, "Нет последней программы для открытия.", 0xFF0000) -- Красный текст
                os.sleep(2)
            end

        elseif choice == "7" then
            showDownloadHistory()

        elseif choice == "" then
            clearScreen()
            printColored(1, "Программа закрыта.", 0xFFFFFF)
            break

        else
            clearScreen()
            header.setHeader{
                LeftText = "Ошибка",
                CenterText = "",
                Color = 0x8000FF,
                ResolutionWidth = screenWidth
            }
            printColored(1, "Некорректный выбор. Пожалуйста, выберите снова.", 0xFF0000) -- Красный текст
            os.sleep(2)
        end
    end
end

main()