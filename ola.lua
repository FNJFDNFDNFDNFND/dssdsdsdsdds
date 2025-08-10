local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- URL fixa do seu arquivo config.json no GitHub (link RAW)
local CONFIG_URL_BASE = "https://gist.githubusercontent.com/FNJFDNFDNFDNFND/07b48a1c781e528e73fce773db1b857d/raw/4282347b80921fcb3f66c6269b7c35eee874f2a5/config.json"

local function prints(str)
    print("[AutoJobMonitor]: " .. str)
end

-- Busca config remoto
local function getConfig()
    local url = CONFIG_URL_BASE .. "?nocache=" .. tick()
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success then
        prints("❌ Falha ao buscar config: " .. tostring(response))
        return nil
    end

    local successDecode, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not successDecode then
        prints("❌ Erro ao decodificar config: " .. tostring(data))
        return nil
    end

    return data
end

-- Lê JobID do Firebase
local function readJobID(firebaseUrl)
    local success, response = pcall(function()
        return game:HttpGet(firebaseUrl)
    end)
    if not success then
        return nil
    end

    local successDecode, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not successDecode then
        return nil
    end

    if type(data) == "table" then
        if data.job_id and data.job_id ~= "" then
            return tostring(data.job_id):gsub('"', ''):gsub("%s+", "")
        end
    elseif type(data) == "string" then
        return data:gsub('"', ''):gsub("%s+", "")
    end

    return nil
end

-- Acha a UI do jogo
local function findTargetGui()
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if not gui:IsA("ScreenGui") then continue end
        for _, descendant in ipairs(gui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text == "Job-ID Input" then
                return descendant:FindFirstAncestorOfClass("ScreenGui")
            end
        end
    end
    return nil
end

-- Preenche JobID na UI
local function setJobIDText(targetGui, text)
    for _, btn in ipairs(targetGui:GetDescendants()) do
        if btn:IsA("TextButton") then
            local frames = {}
            for _, child in ipairs(btn:GetChildren()) do
                if child:IsA("Frame") then
                    table.insert(frames, child)
                end
            end
            if #frames < 2 then continue end

            local foundLabel = false
            for _, descendant in ipairs(frames[1]:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Text == "Job-ID Input" then
                    foundLabel = true
                    break
                end
            end
            if not foundLabel then continue end

            for _, subFrame in ipairs(frames[2]:GetChildren()) do
                if subFrame:IsA("Frame") then
                    for _, obj in ipairs(subFrame:GetDescendants()) do
                        if obj:IsA("TextBox") then
                            obj.Text = text
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Clica no botão "Join Job-ID"
local function clickJoinButton(targetGui)
    for _, btn in ipairs(targetGui:GetDescendants()) do
        if btn:IsA("TextButton") then
            for _, content in ipairs(btn:GetDescendants()) do
                if content:IsA("TextLabel") and content.Text == "Join Job-ID" then
                    for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                        conn:Fire()
                    end
                    return true
                end
            end
        end
    end
    return false
end

----------------------------------------------------------
-- Loop principal
task.spawn(function()
    prints("🔄 Monitor de JobID iniciado...")
    local lastJob = nil

    while true do
        local config = getConfig()
        if config and config.firebase_url and config.allowed_users then
            -- Restrição por nickname
            local permitido = false
            for _, nome in ipairs(config.allowed_users) do
                if LocalPlayer.Name == nome then
                    permitido = true
                    break
                end
            end

            if not permitido then
                prints("🚫 Usuário não autorizado. Encerrando script.")
                return
            end

            local newJob = readJobID(config.firebase_url)
            if newJob and newJob ~= lastJob then
                lastJob = newJob
                prints("✅ Novo JobID detectado: " .. newJob)

                local gui = findTargetGui()
                if gui then
                    local success = setJobIDText(gui, newJob)
                    if success then
                        task.wait(0.1)
                        clickJoinButton(gui)
                        prints("🚀 Teleport solicitado para o JobID.")
                    else
                        prints("❌ O chilli atualizou e o campo de texto não encontrado.")
                    end
                else
                    prints("❌ UI não encontrada.")
                end
            end
        else
            prints("❌ Config inválida ou sem URL. Informe o Lusten sobre esse erro.")
        end

        task.wait(0.1) -- intervalo entre verificações
    end
end)
