local HttpService = game:GetService("HttpService")

-- URL fixa do seu arquivo config.json no GitHub (link RAW)
local CONFIG_URL = "https://gist.githubusercontent.com/SEU_USUARIO/ID_DO_GIST/raw/config.json"

local function prints(str)
    print("[AutoJobMonitor]: " .. str)
end

-- Função para obter URL do Firebase do config remoto
local function getFirebaseUrl()
    prints("🌐 Buscando config no GitHub...")
    local success, response = pcall(function()
        return game:HttpGet(CONFIG_URL)
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

    if data.firebase_url and data.firebase_url ~= "" then
        prints("✅ Firebase URL carregado do config.")
        return data.firebase_url
    end

    prints("❌ Chave 'firebase_url' não encontrada no config.")
    return nil
end

-- Busca a URL do Firebase
local FIREBASE_URL = getFirebaseUrl()
if not FIREBASE_URL then
    prints("🚫 Não foi possível iniciar por falta de URL do Firebase.")
    return
end

----------------------------------------------------------
-- Função para ler o JobID do Firebase
local function readJobID()
    prints("📡 Buscando JobID do Firebase...")

    local success, response = pcall(function()
        return game:HttpGet(FIREBASE_URL)
    end)

    if not success then
        prints("❌ Falha na requisição: " .. tostring(response))
        return nil
    end

    prints("📥 Resposta bruta do Firebase: " .. tostring(response))

    local successDecode, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not successDecode then
        prints("❌ Erro no JSONDecode: " .. tostring(data))
        return nil
    end

    prints("📦 Tipo de dado decodificado: " .. typeof(data))

    if type(data) == "table" then
        prints("📋 Chaves disponíveis: " .. table.concat((function()
            local keys = {}
            for k in pairs(data) do
                table.insert(keys, tostring(k))
            end
            return keys
        end)(), ", "))

        if data.job_id and data.job_id ~= "" then
            prints("✅ JobID encontrado na chave job_id: " .. tostring(data.job_id))
            return tostring(data.job_id):gsub("%s+", "")
        end

    elseif type(data) == "string" then
        prints("✅ JobID encontrado como string pura: " .. tostring(data))
        return data:gsub("%s+", "")
    end

    prints("❌ Nenhum JobID válido encontrado no retorno.")
    return nil
end

----------------------------------------------------------
-- Funções para achar e preencher o UI
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

local function clickJoinButton(targetGui)
    for _, btn in ipairs(targetGui:GetDescendants()) do
        if btn:IsA("TextButton") then
            for _, content in ipairs(btn:GetDescendants()) do
                if content:IsA("TextLabel") and content.Text == "Join Job-ID" then
                    for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                        conn:Fire()
                    end
                    prints("✅ Teleport solicitado para novo JobID.")
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
    local lastJob = readJobID()

    while true do
        local newJob = readJobID()

        if newJob and newJob ~= lastJob then
            lastJob = newJob

            local gui = findTargetGui()
            if gui then
                local success = setJobIDText(gui, newJob)
                if success then
                    wait(0.1)
                    clickJoinButton(gui)
                else
                    prints("❌ Campo de texto não encontrado.")
                end
            else
                prints("❌ UI não encontrada. Aguardando próxima tentativa...")
            end
        end

        wait(0.1)
    end
end)
