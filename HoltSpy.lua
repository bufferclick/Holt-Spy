--[[
    Holt Spy - Advanced Remote Spy
    Made by BufferClick
    Discord: https://discord.gg/E7Tfjgruck
    
    Usage: Paste Part 1, then on a new line paste Part 2.
]]

if getgenv().HoltSpyExecuted and type(getgenv().HoltSpyShutdown) == "function" then
    getgenv().HoltSpyShutdown()
end

-- ============================================================
-- CORE UTILITIES AND ENVIRONMENT SETUP
-- ============================================================

local realconfigs = {
    logcheckcaller = false,
    autoblock = false,
    funcEnabled = true,
    advancedinfo = false,
    supersecretdevtoggle = false
}

local configs = newproxy(true)
local configsmetatable = getmetatable(configs)

configsmetatable.__index = function(self, index)
    return realconfigs[index]
end

local oth = syn and syn.oth
local unhook = oth and oth.unhook
local hook = oth and oth.hook

local lower = string.lower
local byte = string.byte
local round = math.round
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local yield = coroutine.yield
local create = coroutine.create
local close = coroutine.close
local OldDebugId = game.GetDebugId
local info = debug.info

local IsA = game.IsA
local tostring = tostring
local tonumber = tonumber
local delay = task.delay
local spawn = task.spawn
local clear = table.clear
local clone = table.clone

local function blankfunction(...)
    return ...
end

local get_thread_identity = (syn and syn.get_thread_identity) or getidentity or getthreadidentity
local set_thread_identity = (syn and syn.set_thread_identity) or setidentity
local islclosure = islclosure or is_l_closure
local threadfuncs = (get_thread_identity and set_thread_identity and true) or false

local getinfo = getinfo or blankfunction
local getupvalues = getupvalues or debug.getupvalues or blankfunction
local getconstants = getconstants or debug.getconstants or blankfunction

local getcustomasset = getsynasset or getcustomasset
local getcallingscript = getcallingscript or blankfunction
local newcclosure = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local cloneref = cloneref or blankfunction
local request = request or syn and syn.request
local makewritable = makewriteable or function(tbl)
    setreadonly(tbl, false)
end
local makereadonly = makereadonly or function(tbl)
    setreadonly(tbl, true)
end
local isreadonly = isreadonly or table.isfrozen

local setclipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set) or function(...)
    return ErrorPrompt("Attempted to set clipboard: " .. (...), true)
end

local hookmetamethod = hookmetamethod or (makewriteable and makereadonly and getrawmetatable) and function(obj, metamethod, func)
    local old = getrawmetatable(obj)
    if hookfunction then
        return hookfunction(old[metamethod], func)
    else
        local oldmetamethod = old[metamethod]
        makewriteable(old)
        old[metamethod] = func
        makereadonly(old)
        return oldmetamethod
    end
end

local function Create(instance, properties, children)
    local obj = Instance.new(instance)
    for i, v in next, properties or {} do
        obj[i] = v
    end
    for _, child in next, children or {} do
        child.Parent = obj
    end
    return obj
end

local function SafeGetService(service)
    return cloneref(game:GetService(service))
end

local function IsCyclicTable(tbl)
    local checkedtables = {}
    local function SearchTable(t)
        table.insert(checkedtables, t)
        for i, v in next, t do
            if type(v) == "table" then
                return table.find(checkedtables, v) and true or SearchTable(v)
            end
        end
    end
    return SearchTable(tbl)
end

local function deepclone(args, copies)
    local copy = nil
    copies = copies or {}
    if type(args) == "table" then
        if copies[args] then
            copy = copies[args]
        else
            copy = {}
            copies[args] = copy
            for i, v in next, args do
                copy[deepclone(i, copies)] = deepclone(v, copies)
            end
        end
    elseif typeof(args) == "Instance" then
        copy = cloneref(args)
    else
        copy = args
    end
    return copy
end

local function rawtostring(userdata)
    if type(userdata) == "table" or typeof(userdata) == "userdata" then
        local rawmetatable = getrawmetatable(userdata)
        local cachedstring = rawmetatable and rawget(rawmetatable, "__tostring")
        if cachedstring then
            local wasreadonly = isreadonly(rawmetatable)
            if wasreadonly then
                makewritable(rawmetatable)
            end
            rawset(rawmetatable, "__tostring", nil)
            local safestring = tostring(userdata)
            rawset(rawmetatable, "__tostring", cachedstring)
            if wasreadonly then
                makereadonly(rawmetatable)
            end
            return safestring
        end
    end
    return tostring(userdata)
end

local CoreGui = SafeGetService("CoreGui")
local Players = SafeGetService("Players")
local RunService = SafeGetService("RunService")
local UserInputService = SafeGetService("UserInputService")
local TweenService = SafeGetService("TweenService")
local ContentProvider = SafeGetService("ContentProvider")
local TextService = SafeGetService("TextService")
local http = SafeGetService("HttpService")
local GuiInset = game:GetService("GuiService"):GetGuiInset()

local function jsone(str) return http:JSONEncode(str) end
local function jsond(str)
    local suc, err = pcall(http.JSONDecode, http, str)
    return suc and err or suc
end

function ErrorPrompt(Message, state)
    if getrenv then
        local ErrorPromptModule = getrenv().require(CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt"))
        local prompt = ErrorPromptModule.new("Default", { HideErrorCode = true })
        local ErrorStorage = Create("ScreenGui", { Parent = CoreGui, ResetOnSpawn = false })
        local thread = state and running()
        prompt:setParent(ErrorStorage)
        prompt:setErrorTitle("Holt Spy Error")
        prompt:updateButtons({ {
            Text = "Proceed",
            Callback = function()
                prompt:_close()
                ErrorStorage:Destroy()
                if thread then
                    resume(thread)
                end
            end,
            Primary = true
        } }, "Default")
        prompt:_open(Message)
        if thread then
            yield(thread)
        end
    else
        warn(Message)
    end
end

local Highlight = (isfile and loadfile and isfile("Highlight.lua") and loadfile("Highlight.lua")()) or loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()
local LazyFix = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"))()

-- ============================================================
-- CONFIG PERSISTENCE
-- ============================================================

local synv3 = false
if syn and identifyexecutor then
    local _, version = identifyexecutor()
    if version and version:sub(1, 2) == "v3" then
        synv3 = true
    end
end

xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cachedconfigs = isfile("HoltSpy//Settings.json") and jsond(readfile("HoltSpy//Settings.json"))
        if cachedconfigs then
            for i, v in next, realconfigs do
                if cachedconfigs[i] == nil then
                    cachedconfigs[i] = v
                end
            end
            realconfigs = cachedconfigs
        end
        if not isfolder("HoltSpy") then
            makefolder("HoltSpy")
        end
        if not isfolder("HoltSpy//Assets") then
            makefolder("HoltSpy//Assets")
        end
        if not isfile("HoltSpy//Settings.json") then
            writefile("HoltSpy//Settings.json", jsone(realconfigs))
        end
        configsmetatable.__newindex = function(self, index, newindex)
            realconfigs[index] = newindex
            writefile("HoltSpy//Settings.json", jsone(realconfigs))
        end
    else
        configsmetatable.__newindex = function(self, index, newindex)
            realconfigs[index] = newindex
        end
    end
end, function(err)
    ErrorPrompt(("An error has occured: (%s)"):format(err))
end)

-- ============================================================
-- THEME AND COLORS
-- ============================================================

local Theme = {
    Background = Color3.fromRGB(18, 18, 22),
    Surface = Color3.fromRGB(24, 24, 30),
    SurfaceLight = Color3.fromRGB(32, 32, 40),
    SurfaceLighter = Color3.fromRGB(42, 42, 52),
    TopBar = Color3.fromRGB(14, 14, 18),
    Accent = Color3.fromRGB(100, 80, 220),
    AccentLight = Color3.fromRGB(130, 110, 255),
    AccentDark = Color3.fromRGB(70, 55, 170),
    Text = Color3.fromRGB(220, 220, 230),
    TextDim = Color3.fromRGB(140, 140, 160),
    TextMuted = Color3.fromRGB(90, 90, 110),
    EventColor = Color3.fromRGB(255, 200, 50),
    FunctionColor = Color3.fromRGB(100, 140, 255),
    Error = Color3.fromRGB(220, 60, 60),
    Success = Color3.fromRGB(60, 200, 100),
    Warning = Color3.fromRGB(255, 180, 40),
    Border = Color3.fromRGB(50, 50, 65),
    ScrollBar = Color3.fromRGB(60, 60, 80),
    ButtonHover = Color3.fromRGB(50, 50, 65),
    ContextMenu = Color3.fromRGB(28, 28, 36),
    ContextMenuHover = Color3.fromRGB(45, 45, 60),
    ContextMenuBorder = Color3.fromRGB(55, 55, 70),
}

-- ============================================================
-- LOADING SCREEN
-- ============================================================

local function ShowLoadingScreen()
    local LoadingGui = Create("ScreenGui", {
        Name = "HoltSpyLoading",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    })

    local LoadingFrame = Create("Frame", {
        Parent = LoadingGui,
        BackgroundColor3 = Color3.fromRGB(8, 8, 12),
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
    })

    Create("UICorner", { Parent = LoadingFrame, CornerRadius = UDim.new(0, 0) })

    local CenterFrame = Create("Frame", {
        Parent = LoadingFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 400, 0, 300),
    })

    local TitleLabel = Create("TextLabel", {
        Parent = CenterFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 60),
        Font = Enum.Font.GothamBold,
        Text = "HOLT SPY",
        TextColor3 = Theme.AccentLight,
        TextSize = 48,
        TextTransparency = 1,
    })

    local SubtitleLabel = Create("TextLabel", {
        Parent = CenterFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 85),
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.Gotham,
        Text = "Advanced Remote Intelligence",
        TextColor3 = Theme.TextDim,
        TextSize = 16,
        TextTransparency = 1,
    })

    local ByLabel = Create("TextLabel", {
        Parent = CenterFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 130),
        Size = UDim2.new(1, 0, 0, 20),
        Font = Enum.Font.Gotham,
        Text = "made by BufferClick",
        TextColor3 = Theme.TextMuted,
        TextSize = 14,
        TextTransparency = 1,
    })

    local BarBackground = Create("Frame", {
        Parent = CenterFrame,
        BackgroundColor3 = Theme.SurfaceLight,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 180),
        Size = UDim2.new(0.7, 0, 0, 4),
        BorderSizePixel = 0,
    })
    Create("UICorner", { Parent = BarBackground, CornerRadius = UDim.new(0, 2) })

    local BarFill = Create("Frame", {
        Parent = BarBackground,
        BackgroundColor3 = Theme.AccentLight,
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
    })
    Create("UICorner", { Parent = BarFill, CornerRadius = UDim.new(0, 2) })

    local StatusLabel = Create("TextLabel", {
        Parent = CenterFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 195),
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "Initializing...",
        TextColor3 = Theme.TextMuted,
        TextSize = 12,
        TextTransparency = 1,
    })

    local DiscordLabel = Create("TextLabel", {
        Parent = CenterFrame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.new(1, 0, 0, 16),
        Font = Enum.Font.Gotham,
        Text = "discord.gg/E7Tfjgruck",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        TextTransparency = 1,
    })

    LoadingGui.Parent = (gethui and gethui()) or CoreGui

    -- Animate in
    local fadeTime = 0.6
    TweenService:Create(TitleLabel, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    task.wait(0.15)
    TweenService:Create(SubtitleLabel, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    task.wait(0.1)
    TweenService:Create(ByLabel, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    task.wait(0.1)
    TweenService:Create(StatusLabel, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    TweenService:Create(DiscordLabel, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()

    local loadSteps = {
        { progress = 0.15, text = "Loading modules..." },
        { progress = 0.35, text = "Building interface..." },
        { progress = 0.55, text = "Setting up hooks..." },
        { progress = 0.75, text = "Configuring handlers..." },
        { progress = 0.90, text = "Finalizing..." },
        { progress = 1.00, text = "Ready." },
    }

    for _, step in ipairs(loadSteps) do
        TweenService:Create(BarFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(step.progress, 0, 1, 0) }):Play()
        StatusLabel.Text = step.text
        task.wait(0.3)
    end

    task.wait(0.5)

    -- Fade out
    TweenService:Create(LoadingFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
    for _, desc in ipairs(CenterFrame:GetDescendants()) do
        if desc:IsA("TextLabel") then
            TweenService:Create(desc, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        elseif desc:IsA("Frame") then
            TweenService:Create(desc, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        end
    end
    TweenService:Create(BarBackground, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    task.wait(0.5)
    LoadingGui:Destroy()
end

-- ============================================================
-- MAIN GUI CONSTRUCTION
-- ============================================================

local Storage = Create("Folder", {})

local HoltSpyGui = Create("ScreenGui", {
    Name = "HoltSpy",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled = false,
})

-- Responsive sizing
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = (viewportSize.X < 800 or UserInputService.TouchEnabled)
local guiWidth = isMobile and math.clamp(viewportSize.X - 40, 320, 500) or 560
local guiHeight = isMobile and math.clamp(viewportSize.Y - 100, 280, 420) or 380
local leftPanelWidth = isMobile and 110 or 160
local topBarHeight = isMobile and 28 or 32

local Background = Create("Frame", {
    Parent = HoltSpyGui,
    Name = "Background",
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0,
    Position = UDim2.new(0.5, -guiWidth / 2, 0.5, -guiHeight / 2),
    Size = UDim2.new(0, guiWidth, 0, guiHeight),
    BorderSizePixel = 0,
    ClipsDescendants = true,
})
Create("UICorner", { Parent = Background, CornerRadius = UDim.new(0, 8) })
Create("UIStroke", { Parent = Background, Color = Theme.Border, Thickness = 1, Transparency = 0.5 })

-- Top Bar
local TopBar = Create("Frame", {
    Parent = Background,
    Name = "TopBar",
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, topBarHeight),
    ZIndex = 5,
})
Create("UICorner", { Parent = TopBar, CornerRadius = UDim.new(0, 8) })
-- Mask bottom corners of topbar
local TopBarMask = Create("Frame", {
    Parent = TopBar,
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -8),
    Size = UDim2.new(1, 0, 0, 8),
    ZIndex = 5,
})

local TitleButton = Create("TextButton", {
    Parent = TopBar,
    Name = "TitleButton",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(0, 100, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Holt Spy",
    TextColor3 = Theme.AccentLight,
    TextSize = isMobile and 14 or 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    AutoButtonColor = false,
    ZIndex = 6,
})

local VersionLabel = Create("TextLabel", {
    Parent = TopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 115, 0, 0),
    Size = UDim2.new(0, 30, 1, 0),
    Font = Enum.Font.Gotham,
    Text = "v1",
    TextColor3 = Theme.TextMuted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
})

-- Window control buttons
local function CreateWindowButton(name, icon, position, hoverColor)
    local btn = Create("TextButton", {
        Parent = TopBar,
        Name = name,
        BackgroundColor3 = Theme.TopBar,
        BackgroundTransparency = 1,
        Position = position,
        Size = UDim2.new(0, topBarHeight, 0, topBarHeight),
        Font = Enum.Font.GothamBold,
        Text = icon,
        TextColor3 = Theme.TextDim,
        TextSize = isMobile and 14 or 16,
        AutoButtonColor = false,
        ZIndex = 6,
    })
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0, BackgroundColor3 = hoverColor or Theme.ButtonHover }):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = Theme.Text }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = Theme.TextDim }):Play()
    end)
    return btn
end

local CloseButton = CreateWindowButton("Close", "X", UDim2.new(1, -topBarHeight, 0, 0), Theme.Error)
local MaximizeButton = CreateWindowButton("Maximize", "+", UDim2.new(1, -topBarHeight * 2, 0, 0))
local MinimizeButton = CreateWindowButton("Minimize", "-", UDim2.new(1, -topBarHeight * 3, 0, 0))

-- Left Panel (Remote List)
local LeftPanel = Create("Frame", {
    Parent = Background,
    Name = "LeftPanel",
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, topBarHeight),
    Size = UDim2.new(0, leftPanelWidth, 1, -topBarHeight),
    ClipsDescendants = true,
})

local LeftPanelDivider = Create("Frame", {
    Parent = LeftPanel,
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    ZIndex = 3,
})

local SearchBar = Create("TextBox", {
    Parent = LeftPanel,
    Name = "SearchBar",
    BackgroundColor3 = Theme.SurfaceLighter,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 6, 0, 6),
    Size = UDim2.new(1, -13, 0, isMobile and 24 or 26),
    Font = Enum.Font.Gotham,
    PlaceholderText = "Search remotes...",
    PlaceholderColor3 = Theme.TextMuted,
    Text = "",
    TextColor3 = Theme.Text,
    TextSize = isMobile and 11 or 12,
    ClearTextOnFocus = false,
    ClipsDescendants = true,
})
Create("UICorner", { Parent = SearchBar, CornerRadius = UDim.new(0, 4) })
Create("UIPadding", { Parent = SearchBar, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

local LogList = Create("ScrollingFrame", {
    Parent = LeftPanel,
    Name = "LogList",
    Active = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, (isMobile and 36 or 38)),
    Size = UDim2.new(1, 0, 1, -(isMobile and 36 or 38)),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.ScrollBar,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local UIListLayout = Create("UIListLayout", {
    Parent = LogList,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
})

-- Right Panel
local RightPanel = Create("Frame", {
    Parent = Background,
    Name = "RightPanel",
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    Position = UDim2.new(0, leftPanelWidth, 0, topBarHeight),
    Size = UDim2.new(1, -leftPanelWidth, 1, -topBarHeight),
    ClipsDescendants = true,
})

-- Code Box
local CodeBox = Create("Frame", {
    Parent = RightPanel,
    Name = "CodeBox",
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0.55, 0),
    ClipsDescendants = true,
})
Create("UICorner", { Parent = CodeBox, CornerRadius = UDim.new(0, 0) })

-- Divider between code box and button area
local CodeDivider = Create("Frame", {
    Parent = RightPanel,
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0.55, 0),
    Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 3,
})

-- Button Grid Area
local ButtonArea = Create("Frame", {
    Parent = RightPanel,
    Name = "ButtonArea",
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0.55, 1),
    Size = UDim2.new(1, 0, 0.45, -1),
    ClipsDescendants = true,
})

local ScrollingFrame = Create("ScrollingFrame", {
    Parent = ButtonArea,
    Active = true,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 4, 0, 4),
    Size = UDim2.new(1, -8, 1, -8),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.ScrollBar,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
local UIGridLayout = Create("UIGridLayout", {
    Parent = ScrollingFrame,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder = Enum.SortOrder.LayoutOrder,
    CellPadding = UDim2.new(0, 4, 0, 4),
    CellSize = UDim2.new(0, isMobile and 80 or 100, 0, isMobile and 26 or 28),
    FillDirection = Enum.FillDirection.Horizontal,
})

-- ToolTip
local ToolTip = Create("Frame", {
    Parent = HoltSpyGui,
    Name = "ToolTip",
    BackgroundColor3 = Theme.ContextMenu,
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 200, 0, 50),
    ZIndex = 100,
    Visible = false,
})
Create("UICorner", { Parent = ToolTip, CornerRadius = UDim.new(0, 4) })
Create("UIStroke", { Parent = ToolTip, Color = Theme.ContextMenuBorder, Thickness = 1 })

local ToolTipText = Create("TextLabel", {
    Parent = ToolTip,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 6, 0, 4),
    Size = UDim2.new(1, -12, 1, -8),
    ZIndex = 101,
    Font = Enum.Font.Gotham,
    Text = "",
    TextColor3 = Theme.Text,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
})

-- ============================================================
-- CONTEXT MENU (shown when clicking a remote in the log list)
-- ============================================================

local ContextMenu = Create("Frame", {
    Parent = HoltSpyGui,
    Name = "ContextMenu",
    BackgroundColor3 = Theme.ContextMenu,
    BorderSizePixel = 0,
    Size = UDim2.new(0, isMobile and 180 or 220, 0, 10),
    Visible = false,
    ZIndex = 200,
    ClipsDescendants = true,
})
Create("UICorner", { Parent = ContextMenu, CornerRadius = UDim.new(0, 6) })
Create("UIStroke", { Parent = ContextMenu, Color = Theme.ContextMenuBorder, Thickness = 1 })

local ContextMenuList = Create("ScrollingFrame", {
    Parent = ContextMenu,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.ScrollBar,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BorderSizePixel = 0,
    ZIndex = 201,
})
local ContextMenuLayout = Create("UIListLayout", {
    Parent = ContextMenuList,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 1),
})
Create("UIPadding", { Parent = ContextMenuList, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })

-- Edit Code Panel (shown when "Edit Code" is selected)
local EditCodePanel = Create("Frame", {
    Parent = HoltSpyGui,
    Name = "EditCodePanel",
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, isMobile and (guiWidth - 20) or 500, 0, isMobile and 300 or 350),
    Visible = false,
    ZIndex = 300,
})
Create("UICorner", { Parent = EditCodePanel, CornerRadius = UDim.new(0, 8) })
Create("UIStroke", { Parent = EditCodePanel, Color = Theme.Border, Thickness = 1 })

local EditCodeTopBar = Create("Frame", {
    Parent = EditCodePanel,
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 30),
    ZIndex = 301,
})
Create("UICorner", { Parent = EditCodeTopBar, CornerRadius = UDim.new(0, 8) })
local EditCodeTopBarMask = Create("Frame", {
    Parent = EditCodeTopBar,
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -8),
    Size = UDim2.new(1, 0, 0, 8),
    ZIndex = 301,
})

Create("TextLabel", {
    Parent = EditCodeTopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 0),
    Size = UDim2.new(0.7, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Edit Code",
    TextColor3 = Theme.AccentLight,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 302,
})

local EditCodeCloseBtn = Create("TextButton", {
    Parent = EditCodeTopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -30, 0, 0),
    Size = UDim2.new(0, 30, 0, 30),
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Theme.TextDim,
    TextSize = 14,
    AutoButtonColor = false,
    ZIndex = 302,
})

local EditCodeInput = Create("TextBox", {
    Parent = EditCodePanel,
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 6, 0, 36),
    Size = UDim2.new(1, -12, 1, -80),
    Font = Enum.Font.Code,
    Text = "",
    TextColor3 = Theme.Text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false,
    MultiLine = true,
    TextWrapped = true,
    ZIndex = 302,
    ClipsDescendants = true,
})
Create("UICorner", { Parent = EditCodeInput, CornerRadius = UDim.new(0, 4) })
Create("UIPadding", { Parent = EditCodeInput, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })

local EditCodeSaveBtn = Create("TextButton", {
    Parent = EditCodePanel,
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -8),
    Size = UDim2.new(0, 120, 0, 30),
    Font = Enum.Font.GothamBold,
    Text = "Save to Modified",
    TextColor3 = Theme.Text,
    TextSize = 13,
    AutoButtonColor = false,
    ZIndex = 302,
})
Create("UICorner", { Parent = EditCodeSaveBtn, CornerRadius = UDim.new(0, 4) })

-- Modified Code Panel (shows all modified scripts)
local ModifiedPanel = Create("Frame", {
    Parent = HoltSpyGui,
    Name = "ModifiedPanel",
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, isMobile and (guiWidth - 20) or 500, 0, isMobile and 300 or 380),
    Visible = false,
    ZIndex = 300,
})
Create("UICorner", { Parent = ModifiedPanel, CornerRadius = UDim.new(0, 8) })
Create("UIStroke", { Parent = ModifiedPanel, Color = Theme.Border, Thickness = 1 })

local ModifiedTopBar = Create("Frame", {
    Parent = ModifiedPanel,
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 30),
    ZIndex = 301,
})
Create("UICorner", { Parent = ModifiedTopBar, CornerRadius = UDim.new(0, 8) })
Create("Frame", {
    Parent = ModifiedTopBar,
    BackgroundColor3 = Theme.TopBar,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -8),
    Size = UDim2.new(1, 0, 0, 8),
    ZIndex = 301,
})

Create("TextLabel", {
    Parent = ModifiedTopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 0),
    Size = UDim2.new(0.7, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Modified Code",
    TextColor3 = Theme.AccentLight,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 302,
})

local ModifiedCloseBtn = Create("TextButton", {
    Parent = ModifiedTopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -30, 0, 0),
    Size = UDim2.new(0, 30, 0, 30),
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Theme.TextDim,
    TextSize = 14,
    AutoButtonColor = false,
    ZIndex = 302,
})

local ModifiedList = Create("ScrollingFrame", {
    Parent = ModifiedPanel,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 6, 0, 36),
    Size = UDim2.new(1, -12, 1, -42),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.ScrollBar,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BorderSizePixel = 0,
    ZIndex = 302,
})
local ModifiedListLayout = Create("UIListLayout", {
    Parent = ModifiedList,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
})

-- Overlay for dimming background when panels are open
local Overlay = Create("TextButton", {
    Parent = HoltSpyGui,
    Name = "Overlay",
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 199,
    BorderSizePixel = 0,
})

-- ============================================================
-- STATE VARIABLES
-- ============================================================

local selectedColor = Theme.AccentLight
local deselectedColor = Theme.TextDim
local layoutOrderNum = 999999999
local mainClosing = false
local closed = false
local sideClosing = false
local sideClosed = false
local maximized = false
local logs = {}
local selected = nil
local blacklist = {}
local blocklist = {}
local getNil = false
local connectedRemotes = {}
local toggle = false
local prevTables = {}
local remoteLogs = {}
getgenv().HOLTSPYCONFIG_MaxRemotes = 500
local indent = 4
local scheduled = {}
local schedulerconnect
local HoltSpy = {}
local topstr = ""
local bottomstr = ""
local remotesFadeIn
local rightFadeIn
local codebox
local p
local getnilrequired = false

local history = {}
local excluding = {}
local mouseInGui = false
local connections = {}
local DecompiledScripts = {}
local generation = {}
local running_threads = {}
local originalnamecall

local modifiedCodes = {} -- stores all modified code entries
local activeLoops = {} -- stores active looped remote calls
local contextMenuVisible = false

local remoteEvent = Instance.new("RemoteEvent", Storage)
local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
local remoteFunction = Instance.new("RemoteFunction", Storage)
local NamecallHandler = Instance.new("BindableEvent", Storage)
local IndexHandler = Instance.new("BindableEvent", Storage)
local GetDebugIdHandler = Instance.new("BindableFunction", Storage)

local originalEvent = remoteEvent.FireServer
local originalUnreliableEvent = unreliableRemoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
local GetDebugIDInvoke = GetDebugIdHandler.Invoke

function GetDebugIdHandler.OnInvoke(obj)
    return OldDebugId(obj)
end

local function ThreadGetDebugId(obj)
    return GetDebugIDInvoke(GetDebugIdHandler, obj)
end

local function ThreadIsNotDead(thread)
    return not (status(thread) == "dead")
end

local function logthread(thread)
    table.insert(running_threads, thread)
end

-- ============================================================
-- CONTEXT MENU SYSTEM
-- ============================================================

local function HideContextMenu()
    contextMenuVisible = false
    ContextMenu.Visible = false
    for _, child in ipairs(ContextMenuList:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function CreateContextMenuItem(text, order, callback)
    local btn = Create("TextButton", {
        Parent = ContextMenuList,
        BackgroundColor3 = Theme.ContextMenu,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, isMobile and 28 or 26),
        Font = Enum.Font.Gotham,
        Text = "  " .. text,
        TextColor3 = Theme.Text,
        TextSize = isMobile and 12 or 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 202,
    })
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.ContextMenuHover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.ContextMenu }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        HideContextMenu()
        if callback then
            callback()
        end
    end)
    return btn
end

local function CreateContextMenuSeparator(order)
    local sep = Create("Frame", {
        Parent = ContextMenuList,
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -12, 0, 1),
        LayoutOrder = order,
        ZIndex = 202,
    })
    return sep
end

local function CreateContextMenuToggle(text, order, initialState, callback)
    local state = initialState
    local btn = Create("TextButton", {
        Parent = ContextMenuList,
        BackgroundColor3 = Theme.ContextMenu,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, isMobile and 28 or 26),
        Font = Enum.Font.Gotham,
        Text = "  " .. text .. (state and " [ON]" or " [OFF]"),
        TextColor3 = state and Theme.Success or Theme.TextDim,
        TextSize = isMobile and 12 or 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 202,
    })
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.ContextMenuHover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.ContextMenu }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = "  " .. text .. (state and " [ON]" or " [OFF]")
        btn.TextColor3 = state and Theme.Success or Theme.TextDim
        if callback then
            callback(state)
        end
    end)
    return btn, function() return state end
end

local function ShowContextMenu(log, mousePos)
    HideContextMenu()
    
    if not log or not log.Remote then return end
    
    local remote = log.Remote
    local remoteId = log.DebugId
    local order = 0
    
    local function nextOrder()
        order = order + 1
        return order
    end
    
    -- Copy Code
    CreateContextMenuItem("Copy Code", nextOrder(), function()
        if log.GenScript then
            setclipboard(log.GenScript)
        end
    end)
    
    -- Run Code
    CreateContextMenuItem("Run Code", nextOrder(), function()
        if remote and log.args then
            xpcall(function()
                if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                    remote:FireServer(unpack(log.args))
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(unpack(log.args))
                end
            end, function(err)
                warn("[Holt Spy] Execution error: " .. tostring(err))
            end)
        end
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    -- Copy Looped Code
    CreateContextMenuItem("Copy Looped Code", nextOrder(), function()
        if log.GenScript then
            local loopedCode = "-- Looped Code generated by Holt Spy\nwhile true do\n    task.wait(0.1)\n    " .. log.GenScript:gsub("\n", "\n    ") .. "\nend"
            setclipboard(loopedCode)
        end
    end)
    
    -- Run Looped Code
    CreateContextMenuItem("Run Looped Code", nextOrder(), function()
        if remote and log.args then
            local loopId = remoteId .. "_loop_" .. tostring(tick())
            activeLoops[loopId] = true
            logthread(spawn(function()
                while activeLoops[loopId] do
                    xpcall(function()
                        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                            remote:FireServer(unpack(log.args))
                        elseif remote:IsA("RemoteFunction") then
                            remote:InvokeServer(unpack(log.args))
                        end
                    end, function() end)
                    task.wait(0.1)
                end
            end))
        end
    end)
    
    -- Stop All Loops
    CreateContextMenuItem("Stop All Loops", nextOrder(), function()
        for k in pairs(activeLoops) do
            activeLoops[k] = false
        end
        activeLoops = {}
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    -- Copy Toggled Loop Code
    CreateContextMenuItem("Copy Toggled Loop Code", nextOrder(), function()
        if log.GenScript then
            local toggledCode = "-- Toggled Loop Code generated by Holt Spy\n"
            toggledCode = toggledCode .. "local _loopActive = false\n\n"
            toggledCode = toggledCode .. "local function toggleLoop()\n"
            toggledCode = toggledCode .. "    _loopActive = not _loopActive\n"
            toggledCode = toggledCode .. "    while _loopActive do\n"
            toggledCode = toggledCode .. "        task.wait(0.1)\n"
            toggledCode = toggledCode .. "        " .. log.GenScript:gsub("\n", "\n        ") .. "\n"
            toggledCode = toggledCode .. "    end\n"
            toggledCode = toggledCode .. "end\n\n"
            toggledCode = toggledCode .. "toggleLoop() -- Call again to stop"
            setclipboard(toggledCode)
        end
    end)
    
    -- Toggle Loop (in menu with ON/OFF)
    local loopKey = remoteId .. "_toggle"
    local isLooping = activeLoops[loopKey] and true or false
    CreateContextMenuToggle("Toggle Loop", nextOrder(), isLooping, function(state)
        if state then
            activeLoops[loopKey] = true
            logthread(spawn(function()
                while activeLoops[loopKey] do
                    xpcall(function()
                        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                            remote:FireServer(unpack(log.args))
                        elseif remote:IsA("RemoteFunction") then
                            remote:InvokeServer(unpack(log.args))
                        end
                    end, function() end)
                    task.wait(0.1)
                end
            end))
        else
            activeLoops[loopKey] = false
        end
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    -- Edit Code
    CreateContextMenuItem("Edit Code", nextOrder(), function()
        EditCodeInput.Text = log.GenScript or ""
        EditCodePanel.Visible = true
        Overlay.Visible = true
        TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
        
        -- Disconnect old connections if any
        local saveConn
        local closeConn
        local overlayConn
        
        local function closeEdit()
            EditCodePanel.Visible = false
            TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            task.delay(0.2, function() Overlay.Visible = false end)
            if saveConn then saveConn:Disconnect() end
            if closeConn then closeConn:Disconnect() end
            if overlayConn then overlayConn:Disconnect() end
        end
        
        saveConn = EditCodeSaveBtn.MouseButton1Click:Connect(function()
            local modifiedCode = EditCodeInput.Text
            table.insert(modifiedCodes, {
                Name = log.Name or "Unknown",
                Code = modifiedCode,
                Time = os.date("%H:%M:%S"),
                OriginalLog = log,
            })
            closeEdit()
        end)
        
        closeConn = EditCodeCloseBtn.MouseButton1Click:Connect(function()
            closeEdit()
        end)
        
        overlayConn = Overlay.MouseButton1Click:Connect(function()
            closeEdit()
        end)
    end)
    
    -- Exclude (Instance)
    CreateContextMenuItem("Exclude (Instance)", nextOrder(), function()
        if remoteId then
            blacklist[remoteId] = true
        end
    end)
    
    -- Exclude (Name)
    CreateContextMenuItem("Exclude (Name)", nextOrder(), function()
        if log.Name then
            blacklist[log.Name] = true
        end
    end)
    
    -- Block (Instance)
    CreateContextMenuItem("Block (Instance)", nextOrder(), function()
        if remoteId then
            blocklist[remoteId] = true
        end
    end)
    
    -- Block (Name)
    CreateContextMenuItem("Block (Name)", nextOrder(), function()
        if log.Name then
            blocklist[log.Name] = true
        end
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    -- Copy Remote Path
    CreateContextMenuItem("Copy Remote Path", nextOrder(), function()
        if log.Remote then
            setclipboard(log.Remote:GetFullName())
        end
    end)
    
    -- Get Calling Script
    CreateContextMenuItem("Get Calling Script", nextOrder(), function()
        if log.Source then
            setclipboard(tostring(log.Source:GetFullName()))
        end
    end)
    
    -- Position context menu
    local menuItemCount = order
    local itemHeight = isMobile and 28 or 26
    local separatorCount = 0
    for _, child in ipairs(ContextMenuList:GetChildren()) do
        if child:IsA("Frame") and child.Size.Y.Offset == 1 then
            separatorCount = separatorCount + 1
        end
    end
    local totalHeight = (menuItemCount - separatorCount) * (itemHeight + 1) + separatorCount * 2 + 8
    totalHeight = math.min(totalHeight, isMobile and 320 or 400)
    
    local contextWidth = isMobile and 180 or 220
    local posX = mousePos.X
    local posY = mousePos.Y - GuiInset.Y
    local vpSize = workspace.CurrentCamera.ViewportSize
    
    if posX + contextWidth > vpSize.X then
        posX = vpSize.X - contextWidth - 5
    end
    if posY + totalHeight > vpSize.Y - GuiInset.Y then
        posY = vpSize.Y - GuiInset.Y - totalHeight - 5
    end
    if posX < 0 then posX = 5 end
    if posY < 0 then posY = 5 end
    
    ContextMenu.Position = UDim2.new(0, posX, 0, posY)
    ContextMenu.Size = UDim2.new(0, contextWidth, 0, totalHeight)
    ContextMenu.Visible = true
    contextMenuVisible = true
end

-- Close context menu when clicking elsewhere
UserInputService.InputBegan:Connect(function(input)
    if contextMenuVisible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = UserInputService:GetMouseLocation()
        local cmPos = ContextMenu.AbsolutePosition
        local cmSize = ContextMenu.AbsoluteSize
        if mousePos.X < cmPos.X or mousePos.X > cmPos.X + cmSize.X or mousePos.Y - GuiInset.Y < cmPos.Y or mousePos.Y - GuiInset.Y > cmPos.Y + cmSize.Y then
            task.defer(function()
                HideContextMenu()
            end)
        end
    end
end)

-- ============================================================
-- MODIFIED CODE PANEL LOGIC
-- ============================================================

local function ShowModifiedCodeContextMenu(entry, mousePos)
    HideContextMenu()
    local order = 0
    local function nextOrder()
        order = order + 1
        return order
    end
    
    CreateContextMenuItem("Copy Code", nextOrder(), function()
        setclipboard(entry.Code)
    end)
    
    CreateContextMenuItem("Run Code", nextOrder(), function()
        xpcall(function()
            loadstring(entry.Code)()
        end, function(err)
            warn("[Holt Spy] Modified code execution error: " .. tostring(err))
        end)
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    CreateContextMenuItem("Copy Looped Code", nextOrder(), function()
        local looped = "while true do\n    task.wait(0.1)\n    " .. entry.Code:gsub("\n", "\n    ") .. "\nend"
        setclipboard(looped)
    end)
    
    CreateContextMenuItem("Run Looped Code", nextOrder(), function()
        local loopId = "modified_" .. tostring(tick())
        activeLoops[loopId] = true
        logthread(spawn(function()
            while activeLoops[loopId] do
                xpcall(function()
                    loadstring(entry.Code)()
                end, function() end)
                task.wait(0.1)
            end
        end))
    end)
    
    CreateContextMenuItem("Stop All Loops", nextOrder(), function()
        for k in pairs(activeLoops) do
            activeLoops[k] = false
        end
        activeLoops = {}
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    CreateContextMenuItem("Copy Toggled Loop Code", nextOrder(), function()
        local toggledCode = "local _loopActive = false\nlocal function toggleLoop()\n    _loopActive = not _loopActive\n    while _loopActive do\n        task.wait(0.1)\n        " .. entry.Code:gsub("\n", "\n        ") .. "\n    end\nend\ntoggleLoop()"
        setclipboard(toggledCode)
    end)
    
    local loopKey = "modified_toggle_" .. tostring(entry)
    local isLooping = activeLoops[loopKey] and true or false
    CreateContextMenuToggle("Toggle Loop", nextOrder(), isLooping, function(state)
        if state then
            activeLoops[loopKey] = true
            logthread(spawn(function()
                while activeLoops[loopKey] do
                    xpcall(function()
                        loadstring(entry.Code)()
                    end, function() end)
                    task.wait(0.1)
                end
            end))
        else
            activeLoops[loopKey] = false
        end
    end)
    
    CreateContextMenuSeparator(nextOrder())
    
    CreateContextMenuItem("Edit Code", nextOrder(), function()
        EditCodeInput.Text = entry.Code
        EditCodePanel.Visible = true
        Overlay.Visible = true
        TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
        
        local saveConn, closeConn, overlayConn
        local function closeEdit()
            EditCodePanel.Visible = false
            TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            task.delay(0.2, function() Overlay.Visible = false end)
            if saveConn then saveConn:Disconnect() end
            if closeConn then closeConn:Disconnect() end
            if overlayConn then overlayConn:Disconnect() end
        end
        saveConn = EditCodeSaveBtn.MouseButton1Click:Connect(function()
            entry.Code = EditCodeInput.Text
            closeEdit()
        end)
        closeConn = EditCodeCloseBtn.MouseButton1Click:Connect(function()
            closeEdit()
        end)
        overlayConn = Overlay.MouseButton1Click:Connect(function()
            closeEdit()
        end)
    end)
    
    CreateContextMenuItem("Delete", nextOrder(), function()
        for i, e in ipairs(modifiedCodes) do
            if e == entry then
                table.remove(modifiedCodes, i)
                break
            end
        end
        -- Refresh the modified list UI
        RefreshModifiedList()
    end)
    
    local menuItemCount = order
    local itemHeight = isMobile and 28 or 26
    local totalHeight = math.min(menuItemCount * (itemHeight + 1) + 8, isMobile and 320 or 400)
    local contextWidth = isMobile and 180 or 220
    local posX = mousePos.X
    local posY = mousePos.Y - GuiInset.Y
    local vpSize = workspace.CurrentCamera.ViewportSize
    if posX + contextWidth > vpSize.X then posX = vpSize.X - contextWidth - 5 end
    if posY + totalHeight > vpSize.Y - GuiInset.Y then posY = vpSize.Y - GuiInset.Y - totalHeight - 5 end
    if posX < 0 then posX = 5 end
    if posY < 0 then posY = 5 end
    
    ContextMenu.Position = UDim2.new(0, posX, 0, posY)
    ContextMenu.Size = UDim2.new(0, contextWidth, 0, totalHeight)
    ContextMenu.Visible = true
    contextMenuVisible = true
end

function RefreshModifiedList()
    for _, child in ipairs(ModifiedList:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    for i, entry in ipairs(modifiedCodes) do
        local entryFrame = Create("TextButton", {
            Parent = ModifiedList,
            BackgroundColor3 = Theme.SurfaceLight,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, isMobile and 32 or 28),
            Font = Enum.Font.Gotham,
            Text = "  [" .. entry.Time .. "] " .. entry.Name,
            TextColor3 = Theme.Text,
            TextSize = isMobile and 12 or 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 303,
        })
        Create("UICorner", { Parent = entryFrame, CornerRadius = UDim.new(0, 4) })
        
        entryFrame.MouseEnter:Connect(function()
            TweenService:Create(entryFrame, TweenInfo.new(0.1), { BackgroundColor3 = Theme.SurfaceLighter }):Play()
        end)
        entryFrame.MouseLeave:Connect(function()
            TweenService:Create(entryFrame, TweenInfo.new(0.1), { BackgroundColor3 = Theme.SurfaceLight }):Play()
        end)
        entryFrame.MouseButton1Click:Connect(function()
            ModifiedPanel.Visible = false
            TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            task.delay(0.2, function() Overlay.Visible = false end)
            local mPos = UserInputService:GetMouseLocation()
            ShowModifiedCodeContextMenu(entry, mPos)
        end)
    end
end

ModifiedCloseBtn.MouseButton1Click:Connect(function()
    ModifiedPanel.Visible = false
    TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
    task.delay(0.2, function() Overlay.Visible = false end)
end)

-- ============================================================
-- CORE FUNCTIONS
-- ============================================================

function clean()
    local max = getgenv().HOLTSPYCONFIG_MaxRemotes or 500
    if not (typeof(max) == "number" and math.floor(max) == max) then
        max = 500
    end
    if #remoteLogs > max then
        for i = 100, #remoteLogs do
            local v = remoteLogs[i]
            if typeof(v[1]) == "RBXScriptConnection" then
                v[1]:Disconnect()
            end
            if typeof(v[2]) == "Instance" then
                v[2]:Destroy()
            end
        end
        local newLogs = {}
        for i = 1, 100 do
            table.insert(newLogs, remoteLogs[i])
        end
        remoteLogs = newLogs
    end
end

function scaleToolTip()
    local size = TextService:GetTextSize(ToolTipText.Text, ToolTipText.TextSize, ToolTipText.Font, Vector2.new(196, math.huge))
    ToolTipText.Size = UDim2.new(0, size.X, 0, size.Y)
    ToolTip.Size = UDim2.new(0, size.X + 12, 0, size.Y + 8)
end

function onToggleButtonHover()
    if not toggle then
        TweenService:Create(TitleButton, TweenInfo.new(0.3), { TextColor3 = Theme.Error }):Play()
    else
        TweenService:Create(TitleButton, TweenInfo.new(0.3), { TextColor3 = Theme.Success }):Play()
    end
end

function onToggleButtonUnhover()
    TweenService:Create(TitleButton, TweenInfo.new(0.3), { TextColor3 = Theme.AccentLight }):Play()
end

function onToggleButtonClick()
    if toggle then
        TweenService:Create(TitleButton, TweenInfo.new(0.3), { TextColor3 = Theme.Error }):Play()
    else
        TweenService:Create(TitleButton, TweenInfo.new(0.3), { TextColor3 = Theme.Success }):Play()
    end
    toggleSpyMethod()
end

function connectResize()
    if not workspace.CurrentCamera then
        workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
    end
    local lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        lastCam:Disconnect()
        lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    end)
end

function bringBackOnResize()
    local currentX = Background.AbsolutePosition.X
    local currentY = Background.AbsolutePosition.Y
    local vpSize = workspace.CurrentCamera.ViewportSize
    local bgSize = Background.AbsoluteSize
    
    if currentX < 0 then currentX = 0 end
    if currentX > vpSize.X - bgSize.X then currentX = vpSize.X - bgSize.X end
    if currentY < 0 then currentY = 0 end
    if currentY > vpSize.Y - bgSize.Y - GuiInset.Y then currentY = vpSize.Y - bgSize.Y - GuiInset.Y end
    
    TweenService:Create(Background, TweenInfo.new(0.1), { Position = UDim2.new(0, currentX, 0, currentY) }):Play()
end

function onBarInput(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local lastPos = UserInputService:GetMouseLocation()
        local mainPos = Background.AbsolutePosition
        local offset = mainPos - lastPos
        local currentPos = offset + lastPos
        if not connections["drag"] then
            connections["drag"] = RunService.RenderStepped:Connect(function()
                local newPos = UserInputService:GetMouseLocation()
                if newPos ~= lastPos then
                    local currentX = (offset + newPos).X
                    local currentY = (offset + newPos).Y
                    local vpSize = workspace.CurrentCamera.ViewportSize
                    if currentX < 0 then currentX = 0 end
                    if currentX > vpSize.X - Background.AbsoluteSize.X then currentX = vpSize.X - Background.AbsoluteSize.X end
                    if currentY < 0 then currentY = 0 end
                    if currentY > vpSize.Y - Background.AbsoluteSize.Y - GuiInset.Y then currentY = vpSize.Y - Background.AbsoluteSize.Y - GuiInset.Y end
                    currentPos = Vector2.new(currentX, currentY)
                    lastPos = newPos
                    Background.Position = UDim2.new(0, currentPos.X, 0, currentPos.Y)
                end
            end)
        end
        table.insert(connections, UserInputService.InputEnded:Connect(function(inputE)
            if input == inputE then
                if connections["drag"] then
                    connections["drag"]:Disconnect()
                    connections["drag"] = nil
                end
            end
        end))
    end
end

function toggleMinimize(override)
    if mainClosing and not override then return end
    mainClosing = true
    closed = not closed
    if closed then
        TweenService:Create(Background, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, Background.AbsoluteSize.X, 0, topBarHeight)
        }):Play()
        LeftPanel.Visible = false
        RightPanel.Visible = false
    else
        LeftPanel.Visible = true
        RightPanel.Visible = not sideClosed
        TweenService:Create(Background, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, guiWidth, 0, guiHeight)
        }):Play()
        task.delay(0.3, function()
            bringBackOnResize()
        end)
    end
    task.delay(0.3, function()
        mainClosing = false
    end)
end

function toggleSideTray(override)
    if sideClosing and not override then return end
    sideClosing = true
    sideClosed = not sideClosed
    if sideClosed then
        TweenService:Create(RightPanel, TweenInfo.new(0.3), { Size = UDim2.new(0, 0, 1, -topBarHeight) }):Play()
        TweenService:Create(LeftPanel, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 1, -topBarHeight) }):Play()
        task.delay(0.3, function()
            RightPanel.Visible = false
        end)
    else
        if closed then
            toggleMinimize(true)
        end
        RightPanel.Visible = true
        TweenService:Create(LeftPanel, TweenInfo.new(0.3), { Size = UDim2.new(0, leftPanelWidth, 1, -topBarHeight) }):Play()
        TweenService:Create(RightPanel, TweenInfo.new(0.3), { Size = UDim2.new(1, -leftPanelWidth, 1, -topBarHeight) }):Play()
    end
    task.delay(0.3, function()
        sideClosing = false
        bringBackOnResize()
    end)
end

function makeToolTip(enable, text)
    if enable and text then
        if ToolTip.Visible then
            ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then tooltip:Disconnect() end
        end
        local first = true
        connections["ToolTip"] = RunService.RenderStepped:Connect(function()
            local MousePos = UserInputService:GetMouseLocation()
            local topLeft = MousePos + Vector2.new(20, -15)
            local bottomRight = topLeft + ToolTip.AbsoluteSize
            local ViewportSize = workspace.CurrentCamera.ViewportSize
            
            if topLeft.X < 0 then topLeft = Vector2.new(0, topLeft.Y) end
            if bottomRight.X > ViewportSize.X then topLeft = Vector2.new(ViewportSize.X - ToolTip.AbsoluteSize.X, topLeft.Y) end
            if topLeft.Y < 0 then topLeft = Vector2.new(topLeft.X, 0) end
            if bottomRight.Y > ViewportSize.Y - 35 then topLeft = Vector2.new(topLeft.X, ViewportSize.Y - ToolTip.AbsoluteSize.Y - 35) end
            
            if first then
                ToolTip.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
                first = false
            else
                ToolTip:TweenPosition(UDim2.fromOffset(topLeft.X, topLeft.Y), "Out", "Linear", 0.1)
            end
        end)
        ToolTipText.Text = text
        ToolTip.Visible = true
    else
        if ToolTip.Visible then
            ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then tooltip:Disconnect() end
        end
    end
end

function backgroundUserInput(input)
    local mousePos = UserInputService:GetMouseLocation() - GuiInset
    local topBarPos = TopBar.AbsolutePosition
    local topBarSize = TopBar.AbsoluteSize
    
    if mousePos.X >= topBarPos.X and mousePos.X <= topBarPos.X + topBarSize.X - topBarHeight * 3
        and mousePos.Y >= topBarPos.Y and mousePos.Y <= topBarPos.Y + topBarSize.Y then
        onBarInput(input)
    end
end

-- ============================================================
-- BUTTON CREATION
-- ============================================================

function newButton(name, description, onClick)
    local BtnFrame = Create("Frame", {
        Name = "BtnFrame",
        Parent = ScrollingFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, isMobile and 80 or 100, 0, isMobile and 26 or 28),
    })
    
    local Btn = Create("TextButton", {
        Name = "Btn",
        Parent = BtnFrame,
        BackgroundColor3 = Theme.SurfaceLighter,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.Gotham,
        Text = name,
        TextColor3 = Theme.Text,
        TextSize = isMobile and 10 or 11,
        AutoButtonColor = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    Create("UICorner", { Parent = Btn, CornerRadius = UDim.new(0, 4) })
    
    local AccentBar = Create("Frame", {
        Parent = Btn,
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 2),
    })
    Create("UICorner", { Parent = AccentBar, CornerRadius = UDim.new(0, 1) })
    
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.ButtonHover }):Play()
        makeToolTip(true, description())
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.SurfaceLighter }):Play()
        makeToolTip(false)
    end)
    BtnFrame.AncestryChanged:Connect(function()
        makeToolTip(false)
    end)
    Btn.MouseButton1Click:Connect(function(...)
        logthread(running())
        onClick(BtnFrame, ...)
    end)
end

-- ============================================================
-- REMOTE LOGGING
-- ============================================================

function eventSelect(frame)
    if selected and selected.Log then
        if selected.Button then
            spawn(function()
                TweenService:Create(selected.Button, TweenInfo.new(0.3), { BackgroundColor3 = Color3.new(0, 0, 0) }):Play()
                TweenService:Create(selected.Button, TweenInfo.new(0.3), { BackgroundTransparency = 0.85 }):Play()
            end)
        end
        selected = nil
    end
    for _, v in next, logs do
        if frame == v.Log then
            selected = v
        end
    end
    if selected and selected.Log then
        spawn(function()
            TweenService:Create(frame.Button, TweenInfo.new(0.3), { BackgroundColor3 = Theme.Accent }):Play()
            TweenService:Create(frame.Button, TweenInfo.new(0.3), { BackgroundTransparency = 0.4 }):Play()
        end)
        codebox:setRaw(selected.GenScript)
    end
    if sideClosed then
        toggleSideTray()
    end
end

function updateRemoteCanvas()
    LogList.CanvasSize = UDim2.fromOffset(UIListLayout.AbsoluteContentSize.X, UIListLayout.AbsoluteContentSize.Y)
end

function newRemote(remoteType, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote
    
    local RemoteTemplate = Create("Frame", {
        LayoutOrder = layoutOrderNum,
        Name = "RemoteTemplate",
        Parent = LogList,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, isMobile and 28 or 24),
    })
    
    local ColorBar = Create("Frame", {
        Name = "ColorBar",
        Parent = RemoteTemplate,
        BackgroundColor3 = (remoteType == "event" and Theme.EventColor) or Theme.FunctionColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 3, 0, 2),
        Size = UDim2.new(0, 3, 1, -4),
        ZIndex = 2,
    })
    Create("UICorner", { Parent = ColorBar, CornerRadius = UDim.new(0, 2) })
    
    local Text = Create("TextLabel", {
        TextTruncate = Enum.TextTruncate.AtEnd,
        Name = "Text",
        Parent = RemoteTemplate,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -14, 1, 0),
        ZIndex = 2,
        Font = Enum.Font.Gotham,
        Text = remote.Name,
        TextColor3 = Theme.Text,
        TextSize = isMobile and 11 or 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local Button = Create("TextButton", {
        Name = "Button",
        Parent = RemoteTemplate,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = "",
        TextSize = 14,
    })
    Create("UICorner", { Parent = Button, CornerRadius = UDim.new(0, 4) })
    
    Button.MouseEnter:Connect(function()
        if not (selected and selected.Log == RemoteTemplate) then
            TweenService:Create(Button, TweenInfo.new(0.15), { BackgroundTransparency = 0.7 }):Play()
        end
    end)
    Button.MouseLeave:Connect(function()
        if not (selected and selected.Log == RemoteTemplate) then
            TweenService:Create(Button, TweenInfo.new(0.15), { BackgroundTransparency = 0.85 }):Play()
        end
    end)
    
    local log = {
        Name = remote.Name,
        Function = data.infofunc or "--Function Info is disabled",
        Remote = remote,
        DebugId = data.id,
        metamethod = data.metamethod,
        args = data.args,
        Log = RemoteTemplate,
        Button = Button,
        Blocked = data.blocked,
        Source = data.callingscript,
        returnvalue = data.returnvalue,
        GenScript = "-- Generating, please wait...\n-- (If this message persists, the remote args are likely extremely long)"
    }
    
    logs[#logs + 1] = log
    
    -- Left click: select and show code
    local leftClickConn = Button.MouseButton1Click:Connect(function()
        logthread(running())
        eventSelect(RemoteTemplate)
        log.GenScript = genScript(log.Remote, log.args)
        if data.blocked then
            log.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER\n\n" .. log.GenScript
        end
        if selected == log and RemoteTemplate then
            eventSelect(RemoteTemplate)
        end
    end)
    
    -- Right click: show context menu
    local rightClickConn = Button.MouseButton2Click:Connect(function()
        log.GenScript = genScript(log.Remote, log.args)
        if data.blocked then
            log.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER\n\n" .. log.GenScript
        end
        selected = log
        local mousePos = UserInputService:GetMouseLocation()
        ShowContextMenu(log, mousePos)
    end)
    
    -- Long press for mobile
    if isMobile then
        local pressStart = 0
        Button.MouseButton1Down:Connect(function()
            pressStart = tick()
        end)
        Button.MouseButton1Up:Connect(function()
            if tick() - pressStart > 0.5 then
                log.GenScript = genScript(log.Remote, log.args)
                selected = log
                local mousePos = UserInputService:GetMouseLocation()
                ShowContextMenu(log, mousePos)
            end
        end)
    end
    
    layoutOrderNum -= 1
    table.insert(remoteLogs, 1, { leftClickConn, RemoteTemplate })
    clean()
    updateRemoteCanvas()
end

-- ============================================================
-- SEARCH FILTER
-- ============================================================

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchBar.Text:lower()
    for _, child in ipairs(LogList:GetChildren()) do
        if child:IsA("Frame") and child.Name == "RemoteTemplate" then
            local textLabel = child:FindFirstChild("Text")
            if textLabel then
                if query == "" or textLabel.Text:lower():find(query, 1, true) then
                    child.Visible = true
                else
                    child.Visible = false
                end
            end
        end
    end
end)

-- This is the end of part 1
