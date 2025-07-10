local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local soundsPath = "sounds/"

if not fs.exists(soundsPath) then
  fs.makeDir(soundsPath)
end

local function syncSounds()
  local response = http.get("https://raw.githubusercontent.com/KylomaskGamer/CC-Soundboard/main/sounds/filelist.txt")
  if response then
    local filelist = response.readAll()
    response.close()

    for line in filelist:gmatch("[^\r\n]+") do
      local filepath = soundsPath .. line
      if not fs.exists(filepath) then
        print("downloading: " .. line)
        local fileResponse = http.get("https://raw.githubusercontent.com/KylomaskGamer/CC-Soundboard/main/sounds/" .. line)
        if fileResponse then
          local f = fs.open(filepath, "wb")
          f.write(fileResponse.readAll())
          f.close()
          fileResponse.close()
        else
          print("failed to get " .. line)
        end
      end
    end
  else
    print("failed to fetch filelist.txt from github")
  end
end

syncSounds()

local colorsCycle = {
  colors.red, colors.orange, colors.yellow, colors.lime, colors.lightBlue,
  colors.blue, colors.purple, colors.magenta, colors.pink
}

local function getSoundFiles()
  local list = fs.list(soundsPath)
  local sounds = {}
  for _, file in ipairs(list) do
    if file:match("%.dfpwm$") then
      table.insert(sounds, file)
    end
  end
  return sounds
end

local function drawButton(x, y, w, h, text, highlight, colorIndex)
  local bgColor
  local textColor

  if highlight then
    bgColor = colors.white
    textColor = colors.black
  else
    bgColor = colorsCycle[((colorIndex - 1) % #colorsCycle) + 1]
    textColor = colors.black
  end

  paintutils.drawFilledBox(x, y, x + w - 1, y + h - 1, bgColor)
  term.setCursorPos(x + 1, y + 1)
  term.setTextColor(textColor)
  term.write(text)
end

local function drawWarning()
  term.setBackgroundColor(colors.red)
  term.setTextColor(colors.white)
  term.setCursorPos(1, 1)
  term.clearLine()
  term.write(" ⚠️  WARNING: no speaker found! ⚠️ ")
end

local function drawGrid(sounds, page, highlightIndex, navClick)
  term.setBackgroundColor(colors.black)
  term.clear()

  local buttons = {}
  local cols = 2
  local rows = 4
  local perPage = cols * rows

  local paddingX = 2
  local paddingY = 1

  local screenW, screenH = term.getSize()
  local btnW = math.floor((screenW - paddingX * 2) / 2)
  local btnH = 3

  if not speaker then drawWarning() end

  local startIndex = (page - 1) * perPage + 1
  local endIndex = math.min(startIndex + perPage - 1, #sounds)

  for i = startIndex, endIndex do
    local indexOnPage = i - startIndex + 1
    local row = math.floor((indexOnPage - 1) / cols)
    local col = (indexOnPage - 1) % cols

    local x = paddingX + col * (btnW + 1)
    local y = 2 + row * (btnH + paddingY)

    local label = sounds[i]:gsub("%.dfpwm$", "")
    local isHighlight = (highlightIndex == i)
    local colorIndex = col + row + 4 * (page - 1) + 1

    drawButton(x, y, btnW, btnH, label, isHighlight, colorIndex)

    table.insert(buttons, {
      x = x, y = y, w = btnW, h = btnH,
      file = sounds[i], label = label, index = i
    })
  end

  -- nav + page display
  local navY = screenH - 1

  -- left button
  term.setCursorPos(2, navY)
  term.setBackgroundColor(navClick == "prev" and colors.lightGray or colors.gray)
  term.setTextColor(colors.white)
  term.write("< Prev")

  -- page count in middle
  local pageText = " Pg. " .. page .. " / " .. maxPage
  local pageX = math.floor((screenW - #pageText) / 2)
  term.setCursorPos(pageX, navY)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.write(pageText)

  -- right button
  term.setCursorPos(screenW - 7, navY)
  term.setBackgroundColor(navClick == "next" and colors.lightGray or colors.gray)
  term.setTextColor(colors.white)
  term.write("Next >")

  return buttons
end

local function isClicked(btn, cx, cy)
  return cx >= btn.x and cx <= btn.x + btn.w - 1
     and cy >= btn.y and cy <= btn.y + btn.h - 1
end

local function playDFPWM(filePath)
  if not speaker then
    print("NO SPEAKER BRO 😭 can't play: " .. filePath)
    return
  end

  local decoder = dfpwm.make_decoder()
  for chunk in io.lines(soundsPath .. filePath, 16 * 1024) do
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
      os.pullEvent("speaker_audio_empty")
    end
  end
end

-- main
local sounds = getSoundFiles()
local page = 1
local perPage = 8
maxPage = math.max(1, math.ceil(#sounds / perPage))

local buttons = drawGrid(sounds, page, nil)

while true do
  local event, button, x, y = os.pullEvent("mouse_click")

  local screenW, screenH = term.getSize()
  if y == screenH - 1 then
    if x >= 2 and x <= 7 and page > 1 then
      drawGrid(sounds, page, nil, "prev")
      sleep(0.1)
      page = page - 1
      buttons = drawGrid(sounds, page, nil)
    elseif x >= screenW - 7 and x <= screenW - 1 and page < maxPage then
      drawGrid(sounds, page, nil, "next")
      sleep(0.1)
      page = page + 1
      buttons = drawGrid(sounds, page, nil)
    end
  end

  for _, btn in ipairs(buttons) do
    if isClicked(btn, x, y) then
      buttons = drawGrid(sounds, page, btn.index)
      sleep(0.15)
      buttons = drawGrid(sounds, page, nil)
      playDFPWM(btn.file)
    end
  end
end
