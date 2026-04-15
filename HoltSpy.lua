--[[
    Holt Spy - Advanced Remote Spy
    Made by BufferClick
    Discord: https://discord.gg/E7Tfjgruck
]]

if getgenv().HoltSpyExecuted and type(getgenv().HoltSpyShutdown) == "function" then
    getgenv().HoltSpyShutdown()
end

-- ============================================================
-- SERVICES AND UTILITIES
-- ============================================================

local function blankfunction(...) return ... end

local cloneref = cloneref or blankfunction
local newcclosure = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local getcallingscript = getcallingscript or blankfunction
local makewritable = makewriteable or (setreadonly and function(t) setreadonly(t, false) end) or blankfunction
local makereadonly = makereadonly or (setreadonly and function(t) setreadonly(t, true) end) or blankfunction
local isreadonly = isreadonly or table.isfrozen or blankfunction
local hookmetamethod = hookmetamethod or blankfunction
local hookfunction = hookfunction or blankfunction
local getnamecallmethod = getnamecallmethod or blankfunction
local checkcaller = checkcaller or function() return false end
local islclosure = islclosure or is_l_closure or blankfunction
local getupvalues = getupvalues or (debug and debug.getupvalues) or blankfunction
local getconstants = getconstants or (debug and debug.getconstants) or blankfunction
local getinfo = getinfo or blankfunction
local decompile = decompile or nil
local getnilinstances = getnilinstances or function() return {} end

local setclipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set) or function()
    warn("[Holt Spy] Clipboard not supported on this executor")
end

local function SafeGetService(s)
    return cloneref(game:GetService(s))
end

local RunService    = SafeGetService("RunService")
local Players       = SafeGetService("Players")
local UserInputService = SafeGetService("UserInputService")
local TweenService  = SafeGetService("TweenService")
local TextService   = SafeGetService("TextService")
local CoreGui       = SafeGetService("CoreGui")
local HttpService   = SafeGetService("HttpService")
local GuiService    = SafeGetService("GuiService")
local GuiInset      = GuiService:GetGuiInset()

local OldDebugId    = game.GetDebugId
local info          = debug.info
local lower         = string.lower
local running       = coroutine.running
local resume        = coroutine.resume
local cstatus       = coroutine.status
local yield         = coroutine.yield
local ccreate       = coroutine.create
local cclose        = coroutine.close
local spawn         = task.spawn
local delay         = task.delay
local tclear        = table.clear
local tclone        = table.clone

local function deepclone(args, copies)
    copies = copies or {}
    if type(args) == "table" then
        if copies[args] then return copies[args] end
        local copy = {}
        copies[args] = copy
        for k, v in next, args do
            copy[deepclone(k, copies)] = deepclone(v, copies)
        end
        return copy
    elseif typeof(args) == "Instance" then
        local ok, ref = pcall(cloneref, args)
        return ok and ref or args
    end
    return args
end

local function rawtostring(v)
    if type(v) == "table" or typeof(v) == "userdata" then
        local mt = getrawmetatable(v)
        local ts = mt and rawget(mt, "__tostring")
        if ts then
            local wasro = isreadonly(mt)
            if wasro then makewritable(mt) end
            rawset(mt, "__tostring", nil)
            local s = tostring(v)
            rawset(mt, "__tostring", ts)
            if wasro then makereadonly(mt) end
            return s
        end
    end
    return tostring(v)
end

local function IsCyclicTable(tbl, visited)
    visited = visited or {}
    if visited[tbl] then return true end
    visited[tbl] = true
    for _, v in next, tbl do
        if type(v) == "table" and IsCyclicTable(v, visited) then return true end
    end
    return false
end

-- ============================================================
-- HIGHLIGHT AND DATATOCODE (external)
-- ============================================================

local Highlight = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()
local LazyFix   = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"))()

-- ============================================================
-- CONFIG
-- ============================================================

local realconfigs = {
    logcheckcaller = false,
    autoblock      = false,
    funcEnabled    = true,
    advancedinfo   = false,
}

local configs = newproxy(true)
local configmt = getmetatable(configs)
configmt.__index    = function(_, k) return realconfigs[k] end
configmt.__newindex = function(_, k, v) realconfigs[k] = v end

-- ============================================================
-- THEME
-- ============================================================

local T = {
    BG          = Color3.fromRGB(15, 15, 20),
    Surface     = Color3.fromRGB(22, 22, 28),
    SurfaceL    = Color3.fromRGB(30, 30, 38),
    SurfaceLL   = Color3.fromRGB(40, 40, 50),
    TopBar      = Color3.fromRGB(10, 10, 15),
    Accent      = Color3.fromRGB(90, 70, 200),
    AccentL     = Color3.fromRGB(120, 100, 240),
    Text        = Color3.fromRGB(215, 215, 225),
    TextDim     = Color3.fromRGB(130, 130, 150),
    TextMuted   = Color3.fromRGB(80, 80, 100),
    EventCol    = Color3.fromRGB(255, 200, 50),
    FuncCol     = Color3.fromRGB(100, 140, 255),
    Error       = Color3.fromRGB(220, 60, 60),
    Success     = Color3.fromRGB(60, 200, 100),
    Border      = Color3.fromRGB(45, 45, 60),
    Scroll      = Color3.fromRGB(55, 55, 75),
    CtxBG       = Color3.fromRGB(20, 20, 28),
    CtxHov      = Color3.fromRGB(38, 38, 52),
}

-- ============================================================
-- DETECT MOBILE
-- ============================================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- CREATE HELPERS
-- ============================================================

local function New(cls, props, children)
    local obj = Instance.new(cls)
    for k, v in next, props or {} do
        obj[k] = v
    end
    for _, c in next, children or {} do
        c.Parent = obj
    end
    return obj
end

local function Corner(r, parent)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = parent })
end

local function Stroke(color, thick, parent)
    return New("UIStroke", { Color = color, Thickness = thick or 1, Parent = parent })
end

local function Pad(l, r, t, b, parent)
    return New("UIPadding", {
        PaddingLeft   = UDim.new(0, l or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingTop    = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent        = parent
    })
end

-- ============================================================
-- GUI ROOT
-- ============================================================

local Screen = New("ScreenGui", {
    Name           = "HoltSpy",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder   = 999,
    Enabled        = false,
})

-- ============================================================
-- LOADING SCREEN (small corner notification style)
-- ============================================================

local LoadFrame = New("Frame", {
    Parent              = Screen,
    BackgroundColor3    = T.BG,
    Size                = UDim2.new(0, 200, 0, 70),
    Position            = UDim2.new(1, -210, 1, -80),
    BorderSizePixel     = 0,
    ZIndex              = 9999,
})
Corner(8, LoadFrame)
Stroke(T.Border, 1, LoadFrame)

New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 8),
    Size                = UDim2.new(1, -20, 0, 22),
    Font                = Enum.Font.GothamBold,
    Text                = "Holt Spy",
    TextColor3          = T.AccentL,
    TextSize            = 16,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 10000,
})

New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 30),
    Size                = UDim2.new(1, -20, 0, 14),
    Font                = Enum.Font.Gotham,
    Text                = "by BufferClick",
    TextColor3          = T.TextMuted,
    TextSize            = 11,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 10000,
})

local LoadBar = New("Frame", {
    Parent           = LoadFrame,
    BackgroundColor3 = T.SurfaceLL,
    Position         = UDim2.new(0, 10, 1, -12),
    Size             = UDim2.new(1, -20, 0, 4),
    BorderSizePixel  = 0,
    ZIndex           = 10000,
})
Corner(2, LoadBar)

local LoadFill = New("Frame", {
    Parent           = LoadBar,
    BackgroundColor3 = T.AccentL,
    Size             = UDim2.new(0, 0, 1, 0),
    BorderSizePixel  = 0,
    ZIndex           = 10001,
})
Corner(2, LoadFill)

local LoadStatus = New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 1, -26),
    Size                = UDim2.new(1, -20, 0, 12),
    Font                = Enum.Font.Gotham,
    Text                = "Loading...",
    TextColor3          = T.TextMuted,
    TextSize            = 10,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 10000,
})

local function ShowLoadingScreen()
    local steps = {
        {0.2, "Loading modules..."},
        {0.4, "Building UI..."},
        {0.6, "Hooking remotes..."},
        {0.8, "Finalizing..."},
        {1.0, "Ready!"},
    }
    for _, step in ipairs(steps) do
        TweenService:Create(LoadFill, TweenInfo.new(0.25), {Size = UDim2.new(step[1], 0, 1, 0)}):Play()
        LoadStatus.Text = step[2]
        task.wait(0.2)
    end
    task.wait(0.4)
    TweenService:Create(LoadFrame, TweenInfo.new(0.4), {Position = UDim2.new(1, 10, 1, -80)}):Play()
    task.wait(0.5)
    LoadFrame:Destroy()
end

-- ============================================================
-- MINIMIZED ICON
-- ============================================================

local MinIcon = New("TextButton", {
    Parent              = Screen,
    BackgroundColor3    = T.Accent,
    Size                = UDim2.new(0, 48, 0, 48),
    Position            = UDim2.new(0, 10, 0.5, -24),
    BorderSizePixel     = 0,
    Font                = Enum.Font.GothamBold,
    Text                = "HS",
    TextColor3          = T.Text,
    TextSize            = 14,
    AutoButtonColor     = false,
    ZIndex              = 500,
    Visible             = false,
})
Corner(24, MinIcon)
Stroke(T.AccentL, 1.5, MinIcon)

MinIcon.MouseEnter:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.15), {BackgroundColor3 = T.AccentL}):Play()
end)
MinIcon.MouseLeave:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.15), {BackgroundColor3 = T.Accent}):Play()
end)

-- ============================================================
-- MAIN WINDOW SIZING
-- ============================================================

local vpSize       = workspace.CurrentCamera.ViewportSize
local WIN_W        = isMobile and math.clamp(vpSize.X - 20, 260, 340) or 520
local WIN_H        = isMobile and math.clamp(vpSize.Y * 0.5, 200, 320) or 340
local LEFT_W       = isMobile and 90 or 140
local TOPBAR_H     = isMobile and 26 or 28
local BTN_H        = isMobile and 22 or 24
local BTN_W        = isMobile and 72 or 92
local FONT_SM      = isMobile and 10 or 11
local FONT_MD      = isMobile and 11 or 12
local FONT_LG      = isMobile and 13 or 14

-- ============================================================
-- MAIN WINDOW
-- ============================================================

local Background = New("Frame", {
    Parent           = Screen,
    Name             = "Background",
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
    Size             = UDim2.new(0, WIN_W, 0, WIN_H),
    ClipsDescendants = true,
    ZIndex           = 10,
})
Corner(8, Background)
Stroke(T.Border, 1, Background)

-- TopBar
local TopBar = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, TOPBAR_H),
    ZIndex           = 20,
})
Corner(8, TopBar)
New("Frame", {
    Parent           = TopBar,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -8),
    Size             = UDim2.new(1, 0, 0, 8),
    ZIndex           = 20,
})

local TitleBtn = New("TextButton", {
    Parent              = TopBar,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 8, 0, 0),
    Size                = UDim2.new(0, 80, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Holt Spy",
    TextColor3          = T.AccentL,
    TextSize            = FONT_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    AutoButtonColor     = false,
    ZIndex              = 21,
})

local function WinBtn(icon, xOffset, hoverCol)
    local b = New("TextButton", {
        Parent              = TopBar,
        BackgroundTransparency = 1,
        AnchorPoint         = Vector2.new(1, 0),
        Position            = UDim2.new(1, xOffset, 0, 0),
        Size                = UDim2.new(0, TOPBAR_H, 1, 0),
        Font                = Enum.Font.GothamBold,
        Text                = icon,
        TextColor3          = T.TextDim,
        TextSize            = FONT_MD,
        AutoButtonColor     = false,
        ZIndex              = 21,
    })
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = hoverCol or T.Text}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = T.TextDim}):Play()
    end)
    return b
end

local CloseBtn    = WinBtn("X",  0,           T.Error)
local SideBtn     = WinBtn("+",  -TOPBAR_H,   T.AccentL)
local MinimizeBtn = WinBtn("-",  -TOPBAR_H*2, T.TextDim)

-- Left Panel
local LeftPanel = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.Surface,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0, TOPBAR_H),
    Size             = UDim2.new(0, LEFT_W, 1, -TOPBAR_H),
    ClipsDescendants = true,
    ZIndex           = 10,
})
New("Frame", {
    Parent           = LeftPanel,
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
    Position         = UDim2.new(1, -1, 0, 0),
    Size             = UDim2.new(0, 1, 1, 0),
    ZIndex           = 11,
})

local SearchBar = New("TextBox", {
    Parent              = LeftPanel,
    BackgroundColor3    = T.SurfaceLL,
    BorderSizePixel     = 0,
    Position            = UDim2.new(0, 4, 0, 4),
    Size                = UDim2.new(1, -8, 0, isMobile and 20 or 22),
    Font                = Enum.Font.Gotham,
    PlaceholderText     = "Search...",
    PlaceholderColor3   = T.TextMuted,
    Text                = "",
    TextColor3          = T.Text,
    TextSize            = FONT_SM,
    ClearTextOnFocus    = false,
    ZIndex              = 12,
})
Corner(4, SearchBar)
Pad(5, 5, 0, 0, SearchBar)

local LogList = New("ScrollingFrame", {
    Parent                = LeftPanel,
    BackgroundTransparency = 1,
    BorderSizePixel       = 0,
    Position              = UDim2.new(0, 0, 0, isMobile and 28 or 30),
    Size                  = UDim2.new(1, 0, 1, -(isMobile and 28 or 30)),
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness    = 2,
    ScrollBarImageColor3  = T.Scroll,
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    ScrollingDirection    = Enum.ScrollingDirection.Y,
    ZIndex                = 12,
})
New("UIListLayout", {
    Parent             = LogList,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder          = Enum.SortOrder.LayoutOrder,
    Padding            = UDim.new(0, 2),
})
Pad(2, 2, 2, 2, LogList)

-- Right Panel
local RightPanel = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, LEFT_W, 0, TOPBAR_H),
    Size             = UDim2.new(1, -LEFT_W, 1, -TOPBAR_H),
    ClipsDescendants = true,
    ZIndex           = 10,
    Visible          = false,
})

-- Code display area (top 60%)
local CodeFrame = New("Frame", {
    Parent           = RightPanel,
    BackgroundColor3 = T.Surface,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0, 0),
    Size             = UDim2.new(1, 0, 0.58, 0),
    ClipsDescendants = true,
    ZIndex           = 11,
})

New("Frame", {
    Parent           = RightPanel,
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0.58, 0),
    Size             = UDim2.new(1, 0, 0, 1),
    ZIndex           = 12,
})

-- Button grid (bottom 42%)
local BtnScroll = New("ScrollingFrame", {
    Parent               = RightPanel,
    BackgroundTransparency = 1,
    BorderSizePixel      = 0,
    Position             = UDim2.new(0, 3, 0.58, 4),
    Size                 = UDim2.new(1, -6, 0.42, -8),
    CanvasSize           = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness   = 2,
    ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize  = Enum.AutomaticSize.Y,
    ZIndex               = 12,
})
local BtnGrid = New("UIGridLayout", {
    Parent             = BtnScroll,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder          = Enum.SortOrder.LayoutOrder,
    CellPadding        = UDim2.new(0, 3, 0, 3),
    CellSize           = UDim2.new(0, BTN_W, 0, BTN_H),
    FillDirection      = Enum.FillDirection.Horizontal,
})
Pad(2, 2, 2, 2, BtnScroll)

-- Tooltip
local ToolTip = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.CtxBG,
    BorderSizePixel  = 0,
    Size             = UDim2.new(0, 180, 0, 30),
    ZIndex           = 800,
    Visible          = false,
})
Corner(4, ToolTip)
Stroke(T.Border, 1, ToolTip)
local ToolTipLabel = New("TextLabel", {
    Parent              = ToolTip,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 6, 0, 4),
    Size                = UDim2.new(1, -12, 1, -8),
    Font                = Enum.Font.Gotham,
    Text                = "",
    TextColor3          = T.Text,
    TextSize            = 11,
    TextWrapped         = true,
    TextXAlignment      = Enum.TextXAlignment.Left,
    TextYAlignment      = Enum.TextYAlignment.Top,
    ZIndex              = 801,
})

-- Context Menu
local CtxMenu = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.CtxBG,
    BorderSizePixel  = 0,
    Size             = UDim2.new(0, isMobile and 170 or 200, 0, 10),
    Visible          = false,
    ZIndex           = 600,
    ClipsDescendants = true,
})
Corner(6, CtxMenu)
Stroke(T.Border, 1, CtxMenu)

local CtxList = New("ScrollingFrame", {
    Parent               = CtxMenu,
    BackgroundTransparency = 1,
    BorderSizePixel      = 0,
    Size                 = UDim2.new(1, 0, 1, 0),
    CanvasSize           = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness   = 2,
    ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize  = Enum.AutomaticSize.Y,
    ZIndex               = 601,
})
New("UIListLayout", {Parent = CtxList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)})
Pad(0, 0, 3, 3, CtxList)

-- Edit Code Panel
local EditPanel = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    AnchorPoint      = Vector2.new(0.5, 0.5),
    Position         = UDim2.new(0.5, 0, 0.5, 0),
    Size             = UDim2.new(0, isMobile and 290 or 420, 0, isMobile and 250 or 300),
    Visible          = false,
    ZIndex           = 700,
})
Corner(8, EditPanel)
Stroke(T.Border, 1, EditPanel)

local EditTopBar = New("Frame", {
    Parent           = EditPanel,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, 28),
    ZIndex           = 701,
})
Corner(8, EditTopBar)
New("Frame", {
    Parent           = EditTopBar,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -6),
    Size             = UDim2.new(1, 0, 0, 6),
    ZIndex           = 701,
})
New("TextLabel", {
    Parent              = EditTopBar,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 0),
    Size                = UDim2.new(0.7, 0, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Edit Code",
    TextColor3          = T.AccentL,
    TextSize            = FONT_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 702,
})
local EditCloseBtn = New("TextButton", {
    Parent              = EditTopBar,
    BackgroundTransparency = 1,
    AnchorPoint         = Vector2.new(1, 0),
    Position            = UDim2.new(1, 0, 0, 0),
    Size                = UDim2.new(0, 28, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "X",
    TextColor3          = T.TextDim,
    TextSize            = FONT_MD,
    AutoButtonColor     = false,
    ZIndex              = 702,
})

local EditInput = New("TextBox", {
    Parent              = EditPanel,
    BackgroundColor3    = T.Surface,
    BorderSizePixel     = 0,
    Position            = UDim2.new(0, 6, 0, 34),
    Size                = UDim2.new(1, -12, 1, -74),
    Font                = Enum.Font.Code,
    Text                = "",
    TextColor3          = T.Text,
    TextSize            = FONT_SM,
    TextXAlignment      = Enum.TextXAlignment.Left,
    TextYAlignment      = Enum.TextYAlignment.Top,
    ClearTextOnFocus    = false,
    MultiLine           = true,
    TextWrapped         = true,
    ZIndex              = 702,
    ClipsDescendants    = true,
})
Corner(4, EditInput)
Pad(6, 6, 4, 4, EditInput)

local EditSaveBtn = New("TextButton", {
    Parent              = EditPanel,
    BackgroundColor3    = T.Accent,
    BorderSizePixel     = 0,
    AnchorPoint         = Vector2.new(0.5, 1),
    Position            = UDim2.new(0.5, 0, 1, -8),
    Size                = UDim2.new(0, 110, 0, 26),
    Font                = Enum.Font.GothamBold,
    Text                = "Save to Modified",
    TextColor3          = T.Text,
    TextSize            = FONT_SM,
    AutoButtonColor     = false,
    ZIndex              = 702,
})
Corner(4, EditSaveBtn)

-- Modified Panel
local ModPanel = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    AnchorPoint      = Vector2.new(0.5, 0.5),
    Position         = UDim2.new(0.5, 0, 0.5, 0),
    Size             = UDim2.new(0, isMobile and 290 or 420, 0, isMobile and 250 or 300),
    Visible          = false,
    ZIndex           = 700,
})
Corner(8, ModPanel)
Stroke(T.Border, 1, ModPanel)

local ModTopBar = New("Frame", {
    Parent           = ModPanel,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, 28),
    ZIndex           = 701,
})
Corner(8, ModTopBar)
New("Frame", {
    Parent           = ModTopBar,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -6),
    Size             = UDim2.new(1, 0, 0, 6),
    ZIndex           = 701,
})
New("TextLabel", {
    Parent              = ModTopBar,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 0),
    Size                = UDim2.new(0.7, 0, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Modified Code",
    TextColor3          = T.AccentL,
    TextSize            = FONT_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 702,
})
local ModCloseBtn = New("TextButton", {
    Parent              = ModTopBar,
    BackgroundTransparency = 1,
    AnchorPoint         = Vector2.new(1, 0),
    Position            = UDim2.new(1, 0, 0, 0),
    Size                = UDim2.new(0, 28, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "X",
    TextColor3          = T.TextDim,
    TextSize            = FONT_MD,
    AutoButtonColor     = false,
    ZIndex              = 702,
})
local ModList = New("ScrollingFrame", {
    Parent               = ModPanel,
    BackgroundTransparency = 1,
    BorderSizePixel      = 0,
    Position             = UDim2.new(0, 6, 0, 34),
    Size                 = UDim2.new(1, -12, 1, -40),
    CanvasSize           = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness   = 2,
    ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize  = Enum.AutomaticSize.Y,
    BorderSizePixel      = 0,
    ZIndex               = 702,
})
New("UIListLayout", {Parent = ModList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})

-- Dim overlay for panels
local Overlay = New("TextButton", {
    Parent              = Screen,
    BackgroundColor3    = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    Size                = UDim2.new(1, 0, 1, 0),
    Text                = "",
    AutoButtonColor     = false,
    Visible             = false,
    ZIndex              = 599,
    BorderSizePixel     = 0,
})

-- ============================================================
-- STATE
-- ============================================================

local layoutOrder    = 999999999
local logs           = {}
local selected       = nil
local blacklist      = {}
local blocklist      = {}
local remoteLogs     = {}
local scheduled      = {}
local schedulerConn  = nil
local connections    = {}
local running_threads = {}
local activeLoops    = {}
local modifiedCodes  = {}
local history        = {}
local excluding      = {}
local ctxVisible     = false
local sideClosed     = true
local minimized      = false
local codebox        = nil

local DecompiledScripts = {}
local generation        = {}
local getnilrequired    = false
local topstr            = ""
local bottomstr         = ""
local indent            = 4

getgenv().HOLTSPY_MaxRemotes = 500

-- Original references (filled after hooks set up)
local Storage              = New("Folder", {})
local _remoteEvent         = New("RemoteEvent",        {Parent = Storage})
local _unreliableEvent     = New("UnreliableRemoteEvent", {})
local _remoteFunction      = New("RemoteFunction",     {Parent = Storage})
local GetDebugIdBF         = New("BindableFunction",   {Parent = Storage})
local originalEvent        = _remoteEvent.FireServer
local originalUnreliable   = _unreliableEvent.FireServer
local originalFunction     = _remoteFunction.InvokeServer
local originalNamecall     = nil
local toggle               = false

GetDebugIdBF.OnInvoke = function(obj)
    return OldDebugId(obj)
end

local function SafeDebugId(obj)
    local ok, id = pcall(function()
        return GetDebugIdBF:Invoke(obj)
    end)
    if ok and id then return id end
    local ok2, id2 = pcall(OldDebugId, obj)
    if ok2 then return id2 end
    return tostring(obj)
end

local function logThread(t)
    table.insert(running_threads, t)
end

-- ============================================================
-- TOOLTIP
-- ============================================================

local tipConn = nil

local function ShowTip(text)
    if tipConn then tipConn:Disconnect() tipConn = nil end
    ToolTipLabel.Text = text
    local textSize = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(168, math.huge))
    ToolTip.Size = UDim2.new(0, textSize.X + 14, 0, textSize.Y + 10)
    ToolTip.Visible = true
    tipConn = RunService.RenderStepped:Connect(function()
        local mp = UserInputService:GetMouseLocation()
        local tp = mp + Vector2.new(14, -ToolTip.AbsoluteSize.Y - 4)
        local vp = workspace.CurrentCamera.ViewportSize
        if tp.X + ToolTip.AbsoluteSize.X > vp.X then tp = Vector2.new(vp.X - ToolTip.AbsoluteSize.X - 4, tp.Y) end
        if tp.Y < 0 then tp = Vector2.new(tp.X, mp.Y + 16) end
        ToolTip.Position = UDim2.fromOffset(tp.X, tp.Y)
    end)
end

local function HideTip()
    if tipConn then tipConn:Disconnect() tipConn = nil end
    ToolTip.Visible = false
end

-- ============================================================
-- OVERLAY HELPERS
-- ============================================================

local function ShowOverlay()
    Overlay.Visible = true
    TweenService:Create(Overlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.55}):Play()
end

local function HideOverlay()
    TweenService:Create(Overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    task.delay(0.2, function() Overlay.Visible = false end)
end

-- ============================================================
-- CONTEXT MENU
-- ============================================================

local function HideCtx()
    ctxVisible = false
    CtxMenu.Visible = false
    for _, c in ipairs(CtxList:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end
end

local function CtxItem(label, order, cb, color)
    local btn = New("TextButton", {
        Parent              = CtxList,
        BackgroundColor3    = T.CtxBG,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 0, isMobile and 26 or 24),
        Font                = Enum.Font.Gotham,
        Text                = "   " .. label,
        TextColor3          = color or T.Text,
        TextSize            = FONT_SM,
        TextXAlignment      = Enum.TextXAlignment.Left,
        AutoButtonColor     = false,
        LayoutOrder         = order,
        ZIndex              = 602,
    })
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxHov}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxBG}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        HideCtx()
        if cb then task.defer(cb) end
    end)
    return btn
end

local function CtxSep(order)
    New("Frame", {
        Parent           = CtxList,
        BackgroundColor3 = T.Border,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, -8, 0, 1),
        LayoutOrder      = order,
        ZIndex           = 602,
    })
end

local function CtxToggle(label, order, initState, cb)
    local state = initState
    local btn
    local function UpdateText()
        btn.Text = "   " .. label .. (state and "  [ON]" or "  [OFF]")
        btn.TextColor3 = state and T.Success or T.TextDim
    end
    btn = New("TextButton", {
        Parent              = CtxList,
        BackgroundColor3    = T.CtxBG,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 0, isMobile and 26 or 24),
        Font                = Enum.Font.Gotham,
        Text                = "",
        TextSize            = FONT_SM,
        TextXAlignment      = Enum.TextXAlignment.Left,
        AutoButtonColor     = false,
        LayoutOrder         = order,
        ZIndex              = 602,
    })
    UpdateText()
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxHov}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxBG}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        UpdateText()
        if cb then cb(state) end
    end)
    return btn
end

local function PositionCtx(mousePos, itemCount)
    local iH = isMobile and 26 or 24
    local totalH = math.min(itemCount * (iH + 1) + 8, 300)
    local ctxW = isMobile and 170 or 200
    local vp = workspace.CurrentCamera.ViewportSize
    local px = mousePos.X
    local py = mousePos.Y - GuiInset.Y

    if px + ctxW > vp.X then px = vp.X - ctxW - 4 end
    if py + totalH > vp.Y - GuiInset.Y then py = (vp.Y - GuiInset.Y) - totalH - 4 end
    if px < 2 then px = 2 end
    if py < 2 then py = 2 end

    CtxMenu.Position = UDim2.new(0, px, 0, py)
    CtxMenu.Size = UDim2.new(0, ctxW, 0, totalH)
    CtxMenu.Visible = true
    ctxVisible = true
end

-- ============================================================
-- SCRIPT GENERATION
-- ============================================================

local function i2p(inst)
    if not inst then return "nil" end
    if not inst.Parent and inst ~= game then
        getnilrequired = true
        return ('getNil("' .. inst.Name .. '", "' .. inst.ClassName .. '")')
    end

    local ok, path = pcall(function()
        local lp = Players.LocalPlayer
        if lp and (inst == lp or inst:IsDescendantOf(lp)) then
            local rel = inst:GetFullName():sub(#lp:GetFullName() + 2)
            return 'game:GetService("Players").LocalPlayer' .. (rel ~= "" and ("." .. rel) or "")
        end

        local svc = nil
        local obj = inst
        while obj.Parent and obj.Parent ~= game do
            obj = obj.Parent
        end
        if obj.Parent == game then
            local ok2, s = pcall(function() return game:GetService(obj.ClassName) end)
            if ok2 and s then
                if obj.ClassName == "Workspace" then
                    local rel2 = inst:GetFullName():sub(#obj:GetFullName() + 2)
                    return "workspace" .. (rel2 ~= "" and ("." .. rel2) or "")
                end
                local rel2 = inst:GetFullName():sub(#obj:GetFullName() + 2)
                return 'game:GetService("' .. obj.ClassName .. '")' .. (rel2 ~= "" and ("." .. rel2) or "")
            end
        end

        return "game." .. inst:GetFullName():sub(6)
    end)

    if ok and path then return path end
    return 'game:GetService("' .. inst.ClassName .. '")'
end

local function v2s(v)
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then
        if v == math.huge then return "math.huge"
        elseif v == -math.huge then return "-math.huge"
        elseif v ~= v then return "0/0"
        else return tostring(v) end
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "Instance" then
        return i2p(v)
    elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local c = {v:GetComponents()}
        return ("CFrame.new(%s)"):format(table.concat(c, ", "))
    elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(v.R, v.G, v.B)
    elseif t == "UDim2" then return ("UDim2.new(%s, %s, %s, %s)"):format(v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then return ("UDim.new(%s, %s)"):format(v.Scale, v.Offset)
    elseif t == "BrickColor" then return ("BrickColor.new(%q)"):format(v.Name)
    elseif t == "EnumItem" then return tostring(v)
    elseif t == "TweenInfo" then
        return ("TweenInfo.new(%s, %s, %s, %s, %s, %s)"):format(
            v.Time, tostring(v.EasingStyle), tostring(v.EasingDirection),
            v.RepeatCount, tostring(v.Reverses), v.DelayTime)
    elseif t == "table" then
        local parts = {}
        for k, val in next, v do
            local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. v2s(k) .. "]")
            table.insert(parts, ks .. " = " .. v2s(val))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(v)
    end
end

local function genScript(remote, args)
    getnilrequired = false
    local prefix = ""
    local remotePath = i2p(remote)

    local argsStr = ""
    if args and #args > 0 then
        local ok, result = pcall(LazyFix.Convert, args, true)
        if ok and result then
            argsStr = "local args = " .. result .. "\n"
        else
            local parts = {}
            for _, v in ipairs(args) do
                table.insert(parts, v2s(v))
            end
            argsStr = "local args = {" .. table.concat(parts, ", ") .. "}\n"
        end
    end

    if getnilrequired then
        prefix = 'local function getNil(name, class)\n    for _, v in next, getnilinstances() do\n        if v.ClassName == class and v.Name == name then return v end\n    end\nend\n\n'
    end

    local callStr = ""
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        if args and #args > 0 then
            callStr = remotePath .. ":FireServer(table.unpack(args))"
        else
            callStr = remotePath .. ":FireServer()"
        end
    elseif remote:IsA("RemoteFunction") then
        if args and #args > 0 then
            callStr = "local result = " .. remotePath .. ":InvokeServer(table.unpack(args))\nprint(result)"
        else
            callStr = "local result = " .. remotePath .. ":InvokeServer()\nprint(result)"
        end
    end

    return prefix .. argsStr .. callStr
end

-- ============================================================
-- MODIFIED CODE PANEL
-- ============================================================

local function RefreshModPanel()
    for _, c in ipairs(ModList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for i, entry in ipairs(modifiedCodes) do
        local row = New("TextButton", {
            Parent           = ModList,
            BackgroundColor3 = T.SurfaceL,
            BorderSizePixel  = 0,
            Size             = UDim2.new(1, -2, 0, isMobile and 28 or 24),
            Font             = Enum.Font.Gotham,
            Text             = "  [" .. entry.Time .. "]  " .. entry.Name,
            TextColor3       = T.Text,
            TextSize         = FONT_SM,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextTruncate     = Enum.TextTruncate.AtEnd,
            AutoButtonColor  = false,
            LayoutOrder      = i,
            ZIndex           = 703,
        })
        Corner(4, row)
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfaceLL}):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfaceL}):Play()
        end)
        row.MouseButton1Click:Connect(function()
            -- show context menu for this modified entry
            local mp = UserInputService:GetMouseLocation()
            HideCtx()
            local o = 0
            local function no() o += 1; return o end

            CtxItem("Copy Code", no(), function() setclipboard(entry.Code) end)
            CtxItem("Run Code", no(), function()
                xpcall(loadstring(entry.Code), function(e) warn("[Holt Spy] " .. e) end)
            end)
            CtxSep(no())
            CtxItem("Copy Looped Code", no(), function()
                local lc = "while task.wait(0.1) do\n    " .. entry.Code:gsub("\n", "\n    ") .. "\nend"
                setclipboard(lc)
            end)
            CtxItem("Run Looped Code", no(), function()
                local lid = "mod_loop_" .. tostring(entry) .. tostring(tick())
                activeLoops[lid] = true
                logThread(spawn(function()
                    while activeLoops[lid] do
                        xpcall(loadstring(entry.Code), function() end)
                        task.wait(0.1)
                    end
                end))
            end)
            CtxItem("Stop All Loops", no(), function()
                for k in pairs(activeLoops) do activeLoops[k] = false end
                table.clear(activeLoops)
            end)
            CtxSep(no())
            CtxItem("Copy Toggled Code", no(), function()
                local tc = "_G._holtLoop = not _G._holtLoop\nif _G._holtLoop then\n    task.spawn(function()\n        while _G._holtLoop do\n            task.wait(0.1)\n            " .. entry.Code:gsub("\n", "\n            ") .. "\n        end\n    end)\nend"
                setclipboard(tc)
            end)
            local lk = "mod_toggle_" .. tostring(entry)
            CtxToggle("Toggle Loop", no(), activeLoops[lk] and true or false, function(state)
                if state then
                    activeLoops[lk] = true
                    logThread(spawn(function()
                        while activeLoops[lk] do
                            xpcall(loadstring(entry.Code), function() end)
                            task.wait(0.1)
                        end
                    end))
                else
                    activeLoops[lk] = false
                end
            end)
            CtxSep(no())
            CtxItem("Edit Code", no(), function()
                EditInput.Text = entry.Code
                EditPanel.Visible = true
                ShowOverlay()
                local sc, cc, oc
                sc = EditSaveBtn.MouseButton1Click:Connect(function()
                    entry.Code = EditInput.Text
                    HideOverlay()
                    EditPanel.Visible = false
                    RefreshModPanel()
                    sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
                end)
                cc = EditCloseBtn.MouseButton1Click:Connect(function()
                    HideOverlay(); EditPanel.Visible = false
                    sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
                end)
                oc = Overlay.MouseButton1Click:Connect(function()
                    HideOverlay(); EditPanel.Visible = false
                    sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
                end)
            end)
            CtxItem("Delete", no(), function()
                for idx, e in ipairs(modifiedCodes) do
                    if e == entry then table.remove(modifiedCodes, idx); break end
                end
                RefreshModPanel()
            end, T.Error)

            PositionCtx(mp, o)
        end)
    end
end

ModCloseBtn.MouseButton1Click:Connect(function()
    ModPanel.Visible = false
    HideOverlay()
end)
Overlay.MouseButton1Click:Connect(function()
    if EditPanel.Visible then EditPanel.Visible = false end
    if ModPanel.Visible then ModPanel.Visible = false end
    HideOverlay()
end)

-- ============================================================
-- SHOW CONTEXT MENU FOR A LOG ENTRY
-- ============================================================

local function ShowCtxForLog(log)
    if not log or not log.Remote then return end
    HideCtx()

    local remote  = log.Remote
    local remId   = log.DebugId
    local o = 0
    local function no() o += 1; return o end

    CtxItem("Copy Code", no(), function()
        if log.GenScript then setclipboard(log.GenScript) end
    end)

    CtxItem("Run Code", no(), function()
        if not remote or not log.args then return end
        xpcall(function()
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                remote:FireServer(table.unpack(log.args))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(table.unpack(log.args))
            end
        end, function(e) warn("[Holt Spy] Run error: " .. e) end)
    end)

    CtxSep(no())

    CtxItem("Copy Looped Code", no(), function()
        if not log.GenScript then return end
        local lc = "while task.wait(0.1) do\n    " .. log.GenScript:gsub("\n", "\n    ") .. "\nend"
        setclipboard(lc)
    end)

    CtxItem("Run Looped Code", no(), function()
        if not remote or not log.args then return end
        local lid = (remId or tostring(remote)) .. "_loop_" .. tostring(tick())
        activeLoops[lid] = true
        logThread(spawn(function()
            while activeLoops[lid] do
                xpcall(function()
                    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                        remote:FireServer(table.unpack(log.args))
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(table.unpack(log.args))
                    end
                end, function() end)
                task.wait(0.1)
            end
        end))
    end)

    CtxItem("Stop All Loops", no(), function()
        for k in pairs(activeLoops) do activeLoops[k] = false end
        table.clear(activeLoops)
    end)

    CtxSep(no())

    CtxItem("Copy Toggled Code", no(), function()
        if not log.GenScript then return end
        local inner = log.GenScript:gsub("\n", "\n            ")
        local tc = "_G._holtLoop = not _G._holtLoop\nif _G._holtLoop then\n    task.spawn(function()\n        while _G._holtLoop do\n            task.wait(0.1)\n            " .. inner .. "\n        end\n    end)\nend"
        setclipboard(tc)
    end)

    local lk = (remId or tostring(remote)) .. "_toggle"
    CtxToggle("Toggle Loop", no(), activeLoops[lk] and true or false, function(state)
        if state then
            activeLoops[lk] = true
            logThread(spawn(function()
                while activeLoops[lk] do
                    xpcall(function()
                        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                            remote:FireServer(table.unpack(log.args))
                        elseif remote:IsA("RemoteFunction") then
                            remote:InvokeServer(table.unpack(log.args))
                        end
                    end, function() end)
                    task.wait(0.1)
                end
            end))
        else
            activeLoops[lk] = false
        end
    end)

    CtxSep(no())

    CtxItem("Edit Code", no(), function()
        EditInput.Text = log.GenScript or ""
        EditPanel.Visible = true
        ShowOverlay()
        local sc, cc, oc
        sc = EditSaveBtn.MouseButton1Click:Connect(function()
            local saved = {
                Name = log.Name or "Unknown",
                Code = EditInput.Text,
                Time = os.date("%H:%M:%S"),
            }
            table.insert(modifiedCodes, saved)
            HideOverlay()
            EditPanel.Visible = false
            sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
        end)
        cc = EditCloseBtn.MouseButton1Click:Connect(function()
            HideOverlay(); EditPanel.Visible = false
            sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
        end)
        oc = Overlay.MouseButton1Click:Connect(function()
            HideOverlay(); EditPanel.Visible = false
            sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
        end)
    end)

    CtxSep(no())

    CtxItem("Exclude (Instance)", no(), function()
        if remId then blacklist[remId] = true end
    end)
    CtxItem("Exclude (Name)", no(), function()
        if log.Name then blacklist[log.Name] = true end
    end)
    CtxItem("Block (Instance)", no(), function()
        if remId then blocklist[remId] = true end
    end)
    CtxItem("Block (Name)", no(), function()
        if log.Name then blocklist[log.Name] = true end
    end)

    CtxSep(no())

    CtxItem("Copy Remote Path", no(), function()
        if log.Remote then setclipboard(log.Remote:GetFullName()) end
    end)

    local mp = UserInputService:GetMouseLocation()
    PositionCtx(mp, o)
end

-- Close ctx on outside click
UserInputService.InputBegan:Connect(function(input)
    if not ctxVisible then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        local mp = UserInputService:GetMouseLocation()
        local cp = CtxMenu.AbsolutePosition
        local cs = CtxMenu.AbsoluteSize
        if mp.X < cp.X or mp.X > cp.X + cs.X
        or mp.Y - GuiInset.Y < cp.Y or mp.Y - GuiInset.Y > cp.Y + cs.Y then
            task.defer(HideCtx)
        end
    end
end)

-- ============================================================
-- WINDOW: DRAGGING
-- ============================================================

local function setupDrag()
    local dragging = false
    local dragStart, startPos

    local function inputBegan(input)
        local mp = UserInputService:GetMouseLocation() - GuiInset
        local tbPos = TopBar.AbsolutePosition
        local tbSize = TopBar.AbsoluteSize
        if mp.X < tbPos.X or mp.X > tbPos.X + tbSize.X - TOPBAR_H * 3 then return end
        if mp.Y < tbPos.Y or mp.Y > tbPos.Y + tbSize.Y then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = UserInputService:GetMouseLocation()
            startPos = Background.Position
        end
    end

    local function inputChanged(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = UserInputService:GetMouseLocation() - dragStart
            local vp = workspace.CurrentCamera.ViewportSize
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y

            -- clamp so window cant go fully offscreen
            newX = math.clamp(newX, -(WIN_W - 60), vp.X - 60)
            newY = math.clamp(newY, 0, vp.Y - TOPBAR_H - GuiInset.Y)

            Background.Position = UDim2.new(0, newX, 0, newY)
        end
    end

    local function inputEnded(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end

    TopBar.InputBegan:Connect(inputBegan)
    UserInputService.InputChanged:Connect(inputChanged)
    UserInputService.InputEnded:Connect(inputEnded)
end

-- ============================================================
-- WINDOW: MINIMIZE / SIDE TRAY
-- ============================================================

local function SetMinimized(state)
    minimized = state
    if minimized then
        TweenService:Create(Background, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, WIN_W, 0, TOPBAR_H)
        }):Play()
        LeftPanel.Visible = false
        RightPanel.Visible = false
        task.delay(0.3, function()
            Background.Visible = false
            MinIcon.Visible = true
        end)
    else
        MinIcon.Visible = false
        Background.Visible = true
        LeftPanel.Visible = true
        RightPanel.Visible = not sideClosed
        TweenService:Create(Background, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, WIN_W, 0, WIN_H)
        }):Play()
    end
end

local function SetSideTray(closed)
    sideClosed = closed
    if closed then
        TweenService:Create(RightPanel, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, -TOPBAR_H)}):Play()
        TweenService:Create(LeftPanel, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, -TOPBAR_H)}):Play()
        task.delay(0.22, function() RightPanel.Visible = false end)
    else
        if minimized then SetMinimized(false) end
        RightPanel.Visible = true
        TweenService:Create(LeftPanel, TweenInfo.new(0.2), {Size = UDim2.new(0, LEFT_W, 1, -TOPBAR_H)}):Play()
        TweenService:Create(RightPanel, TweenInfo.new(0.2), {Size = UDim2.new(1, -LEFT_W, 1, -TOPBAR_H)}):Play()
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    SetMinimized(not minimized)
end)
SideBtn.MouseButton1Click:Connect(function()
    SetSideTray(not sideClosed)
end)
MinIcon.MouseButton1Click:Connect(function()
    SetMinimized(false)
end)

TitleBtn.MouseButton1Click:Connect(function()
    -- toggle the spy on/off
end)

-- ============================================================
-- REMOTE LOG LIST
-- ============================================================

local function SelectLog(log)
    -- Deselect old
    for _, l in ipairs(logs) do
        if l.Button then
            TweenService:Create(l.Button, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
        end
    end
    selected = log
    if log and log.Button then
        TweenService:Create(log.Button, TweenInfo.new(0.15), {BackgroundTransparency = 0.4}):Play()
    end
    if log then
        if sideClosed then SetSideTray(false) end
        if log.GenScript and codebox then
            codebox:setRaw(log.GenScript)
        end
    end
end

local function AddRemoteLog(remoteType, data)
    if layoutOrder < 1 then layoutOrder = 999999999 end
    local remote = data.remote
    if not remote then return end

    local frame = New("Frame", {
        LayoutOrder      = layoutOrder,
        Name             = "RemoteLog",
        Parent           = LogList,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, -4, 0, isMobile and 24 or 22),
    })

    New("Frame", {
        Parent           = frame,
        BackgroundColor3 = remoteType == "event" and T.EventCol or T.FuncCol,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0.1, 0),
        Size             = UDim2.new(0, 2, 0.8, 0),
        ZIndex           = 13,
    })

    New("TextLabel", {
        Parent           = frame,
        BackgroundTransparency = 1,
        Position         = UDim2.new(0, 6, 0, 0),
        Size             = UDim2.new(1, -8, 1, 0),
        Font             = Enum.Font.Gotham,
        Text             = remote.Name,
        TextColor3       = T.Text,
        TextSize         = FONT_SM,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        ZIndex           = 13,
    })

    local btn = New("TextButton", {
        Name             = "Button",
        Parent           = frame,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.85,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 1, 0),
        AutoButtonColor  = false,
        Text             = "",
        ZIndex           = 14,
    })
    Corner(3, btn)

    btn.MouseEnter:Connect(function()
        if not (selected and selected.Log == frame) then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.65}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not (selected and selected.Log == frame) then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.85}):Play()
        end
    end)

    local log = {
        Name      = remote.Name,
        Remote    = remote,
        DebugId   = data.id,
        args      = data.args or {},
        Log       = frame,
        Button    = btn,
        Blocked   = data.blockcheck or false,
        Source    = data.callingscript,
        GenScript = "-- Generating...",
    }

    -- Generate script immediately (non-blocking)
    logThread(task.defer(function()
        local ok, result = pcall(genScript, remote, log.args)
        log.GenScript = ok and result or ("-- Generation failed: " .. tostring(result))
        if log.Blocked then
            log.GenScript = "-- THIS REMOTE WAS BLOCKED FROM FIRING TO SERVER\n\n" .. log.GenScript
        end
        if selected == log and codebox then
            codebox:setRaw(log.GenScript)
        end
    end))

    -- Left click: select
    btn.MouseButton1Click:Connect(function()
        SelectLog(log)
        if codebox then codebox:setRaw(log.GenScript) end
    end)

    -- Right click: context menu
    btn.MouseButton2Click:Connect(function()
        selected = log
        ShowCtxForLog(log)
    end)

    -- Mobile long press
    if isMobile then
        local pressT = 0
        btn.MouseButton1Down:Connect(function() pressT = tick() end)
        btn.MouseButton1Up:Connect(function()
            if tick() - pressT >= 0.45 then
                selected = log
                ShowCtxForLog(log)
            end
        end)
    end

    table.insert(logs, log)
    layoutOrder -= 1
    table.insert(remoteLogs, 1, {frame})

    -- Cleanup old logs
    local max = getgenv().HOLTSPY_MaxRemotes or 500
    if #remoteLogs > max then
        for i = max, #remoteLogs do
            local v = remoteLogs[i]
            if v[1] and v[1].Parent then v[1]:Destroy() end
        end
        while #remoteLogs > max do
            table.remove(remoteLogs, #remoteLogs)
        end
        while #logs > max do
            table.remove(logs, #logs)
        end
    end
end

-- ============================================================
-- SEARCH
-- ============================================================

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchBar.Text:lower()
    for _, child in ipairs(LogList:GetChildren()) do
        if child:IsA("Frame") and child.Name == "RemoteLog" then
            local lbl = child:FindFirstChildWhichIsA("TextLabel")
            if lbl then
                child.Visible = q == "" or lbl.Text:lower():find(q, 1, true) ~= nil
            end
        end
    end
end)

-- ============================================================
-- BUTTONS
-- ============================================================

local function NewBtn(name, tip, onClick)
    local f = New("Frame", {
        Parent           = BtnScroll,
        BackgroundTransparency = 1,
        Size             = UDim2.new(0, BTN_W, 0, BTN_H),
    })
    local b = New("TextButton", {
        Parent           = f,
        BackgroundColor3 = T.SurfaceLL,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 1, 0),
        Font             = Enum.Font.Gotham,
        Text             = name,
        TextColor3       = T.Text,
        TextSize         = FONT_SM,
        AutoButtonColor  = false,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        ZIndex           = 13,
    })
    Corner(4, b)
    New("Frame", {
        Parent           = b,
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 1, -2),
        Size             = UDim2.new(1, 0, 0, 2),
        ZIndex           = 14,
    })
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.SurfaceL}):Play()
        ShowTip(tip)
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.SurfaceLL}):Play()
        HideTip()
    end)
    b.MouseButton1Click:Connect(function()
        logThread(running())
        onClick()
    end)
end

NewBtn("Copy Code", "Copy generated code for selected remote", function()
    if selected and selected.GenScript then
        setclipboard(selected.GenScript)
    end
end)

NewBtn("Run Code", "Execute the selected remote once", function()
    if not selected or not selected.Remote then return end
    xpcall(function()
        if selected.Remote:IsA("RemoteEvent") or selected.Remote:IsA("UnreliableRemoteEvent") then
            selected.Remote:FireServer(table.unpack(selected.args))
        elseif selected.Remote:IsA("RemoteFunction") then
            selected.Remote:InvokeServer(table.unpack(selected.args))
        end
    end, function(e) warn("[Holt Spy] " .. e) end)
end)

NewBtn("Edit Code", "Open editor to modify this remote call", function()
    if not selected then return end
    EditInput.Text = selected.GenScript or ""
    EditPanel.Visible = true
    ShowOverlay()
    local sc, cc, oc
    sc = EditSaveBtn.MouseButton1Click:Connect(function()
        table.insert(modifiedCodes, {
            Name = selected.Name,
            Code = EditInput.Text,
            Time = os.date("%H:%M:%S"),
        })
        HideOverlay(); EditPanel.Visible = false
        sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
    end)
    cc = EditCloseBtn.MouseButton1Click:Connect(function()
        HideOverlay(); EditPanel.Visible = false
        sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
    end)
    oc = Overlay.MouseButton1Click:Connect(function()
        HideOverlay(); EditPanel.Visible = false
        sc:Disconnect(); cc:Disconnect(); oc:Disconnect()
    end)
end)

NewBtn("Modified", "View your saved modified scripts", function()
    RefreshModPanel()
    ModPanel.Visible = true
    ShowOverlay()
end)

NewBtn("Copy Loop", "Copy a looped version of the selected remote", function()
    if selected and selected.GenScript then
        local lc = "while task.wait(0.1) do\n    " .. selected.GenScript:gsub("\n", "\n    ") .. "\nend"
        setclipboard(lc)
    end
end)

NewBtn("Run Loop", "Run the selected remote in a loop", function()
    if not selected or not selected.Remote then return end
    local lid = (selected.DebugId or tostring(selected.Remote)) .. "_rl_" .. tostring(tick())
    activeLoops[lid] = true
    logThread(spawn(function()
        while activeLoops[lid] do
            xpcall(function()
                if selected.Remote:IsA("RemoteEvent") or selected.Remote:IsA("UnreliableRemoteEvent") then
                    selected.Remote:FireServer(table.unpack(selected.args))
                elseif selected.Remote:IsA("RemoteFunction") then
                    selected.Remote:InvokeServer(table.unpack(selected.args))
                end
            end, function() end)
            task.wait(0.1)
        end
    end))
end)

NewBtn("Stop Loops", "Stop all active loops", function()
    for k in pairs(activeLoops) do activeLoops[k] = false end
    table.clear(activeLoops)
end)

NewBtn("Clr Logs", "Clear all remote logs", function()
    for _, l in ipairs(logs) do
        if l.Log and l.Log.Parent then l.Log:Destroy() end
    end
    table.clear(logs)
    table.clear(remoteLogs)
    selected = nil
    if codebox then codebox:setRaw("") end
end)

NewBtn("Exclude", "Exclude selected remote by instance", function()
    if selected and selected.DebugId then
        blacklist[selected.DebugId] = true
    end
end)

NewBtn("Block", "Block selected remote from firing", function()
    if selected and selected.DebugId then
        blocklist[selected.DebugId] = true
    end
end)

NewBtn("Clr Blacks", "Clear blacklist and blocklist", function()
    table.clear(blacklist)
    table.clear(blocklist)
end)

NewBtn("Autoblock", "Toggle auto-blocking of spammy remotes", function()
    configs.autoblock = not configs.autoblock
    table.clear(history)
    table.clear(excluding)
end)

NewBtn("Log Caller", "Toggle logging of client-fired remotes", function()
    configs.logcheckcaller = not configs.logcheckcaller
end)

NewBtn("Discord", "Join the Holt Spy Discord server", function()
    setclipboard("https://discord.gg/E7Tfjgruck")
    local ok, resp = pcall(function()
        return (request or syn and syn.request)({
            Url    = "http://127.0.0.1:6463/rpc?v=1",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                Origin           = "https://discord.com"
            },
            Body = HttpService:JSONEncode({
                cmd   = "INVITE_BROWSER",
                nonce = HttpService:GenerateGUID(false),
                args  = {code = "E7Tfjgruck"}
            })
        })
    end)
end)

-- ============================================================
-- REMOTE HANDLER
-- ============================================================

local function remoteHandler(data)
    if not data or not data.remote then return end

    local id = data.id
    if not id then return end

    -- Blacklist check
    if blacklist[id] or blacklist[data.remote.Name] then return end

    -- Autoblock
    if configs.autoblock then
        if excluding[id] then return end
        if not history[id] then history[id] = {count = 0, last = tick()} end
        local h = history[id]
        if tick() - h.last < 0.5 then
            h.count += 1
            if h.count > 15 then
                excluding[id] = true
                return
            end
        else
            h.count = 0
            h.last = tick()
        end
    end

    if blocklist[id] or blocklist[data.remote.Name] then
        data.blockcheck = true
    end

    local rtype = "event"
    if data.remote:IsA("RemoteFunction") then rtype = "function" end
    AddRemoteLog(rtype, data)
end

-- ============================================================
-- SCHEDULER
-- ============================================================

local function schedule(f, ...)
    table.insert(scheduled, {f, ...})
end

local function taskScheduler()
    if #scheduled == 0 then return end
    local max = getgenv().HOLTSPY_MaxRemotes or 500
    if #scheduled > max + 200 then
        -- Trim excess
        while #scheduled > max do
            table.remove(scheduled, #scheduled)
        end
    end
    local current = table.remove(scheduled, 1)
    if type(current) == "table" and type(current[1]) == "function" then
        local ok, err = pcall(table.unpack(current))
        if not ok then warn("[Holt Spy Scheduler] " .. tostring(err)) end
    end
end

-- ============================================================
-- HOOKS
-- ============================================================

-- The namecall hook function
local namecallFunc = newcclosure(function(...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer"
    or method == "fireServer" or method == "invokeServer" then
        local self = ...
        if typeof(self) == "Instance" and (
            self:IsA("RemoteEvent") or
            self:IsA("RemoteFunction") or
            self:IsA("UnreliableRemoteEvent")
        ) then
            if not configs.logcheckcaller and checkcaller() then
                return originalNamecall(...)
            end

            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)

            -- Block check
            if blocklist[safeId] or blocklist[self.Name] then
                return -- don't fire, don't log
            end

            if not blacklist[safeId] and not blacklist[self.Name] then
                local allArgs = {...}
                local passedArgs = {}
                for i = 2, #allArgs do
                    passedArgs[i - 1] = allArgs[i]
                end

                local safeCopy
                local ok2, copied = pcall(deepclone, passedArgs)
                safeCopy = ok2 and copied or passedArgs

                local cs = nil
                pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end

                local data = {
                    method        = method,
                    remote        = self,
                    args          = safeCopy,
                    id            = safeId,
                    callingscript = cs,
                    blockcheck    = false,
                }
                schedule(remoteHandler, data)
            end
        end
    end
    return originalNamecall(...)
end)

-- FireServer hook
local function makeFireHook(origFn)
    return newcclosure(function(self, ...)
        if typeof(self) == "Instance" and (
            self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")
        ) then
            if not configs.logcheckcaller and checkcaller() then
                return origFn(self, ...)
            end

            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)

            if blocklist[safeId] or blocklist[self.Name] then return end

            if not blacklist[safeId] and not blacklist[self.Name] then
                local passedArgs = {...}
                local ok2, copied = pcall(deepclone, passedArgs)
                local cs = nil
                pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end

                schedule(remoteHandler, {
                    method        = "FireServer",
                    remote        = self,
                    args          = ok2 and copied or passedArgs,
                    id            = safeId,
                    callingscript = cs,
                    blockcheck    = false,
                })
            end
        end
        return origFn(self, ...)
    end)
end

-- InvokeServer hook
local function makeInvokeHook(origFn)
    return newcclosure(function(self, ...)
        if typeof(self) == "Instance" and self:IsA("RemoteFunction") then
            if not configs.logcheckcaller and checkcaller() then
                return origFn(self, ...)
            end

            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)

            if blocklist[safeId] or blocklist[self.Name] then return origFn(self, ...) end

            if not blacklist[safeId] and not blacklist[self.Name] then
                local passedArgs = {...}
                local ok2, copied = pcall(deepclone, passedArgs)
                local cs = nil
                pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end

                schedule(remoteHandler, {
                    method        = "InvokeServer",
                    remote        = self,
                    args          = ok2 and copied or passedArgs,
                    id            = safeId,
                    callingscript = cs,
                    blockcheck    = false,
                })
            end
        end
        return origFn(self, ...)
    end)
end

local function enableHooks()
    -- Hook __namecall (catches all :FireServer and :InvokeServer calls)
    local oldNC
    if hookmetamethod then
        oldNC = hookmetamethod(game, "__namecall", namecallFunc)
    elseif hookfunction then
        local mt = getrawmetatable(game)
        local wasRO = isreadonly(mt)
        if wasRO then makewritable(mt) end
        oldNC = mt.__namecall
        mt.__namecall = namecallFunc
        if wasRO then makereadonly(mt) end
    end
    originalNamecall = oldNC

    -- Also hook the explicit method functions as a fallback
    local fireHook    = makeFireHook(originalEvent)
    local unreliHook  = makeFireHook(originalUnreliable)
    local invokeHook  = makeInvokeHook(originalFunction)

    if hookfunction then
        hookfunction(originalEvent,     fireHook)
        hookfunction(originalUnreliable, unreliHook)
        hookfunction(originalFunction,  invokeHook)
    end
end

local function disableHooks()
    if originalNamecall then
        if hookmetamethod then
            hookmetamethod(game, "__namecall", originalNamecall)
        elseif hookfunction then
            local mt = getrawmetatable(game)
            local wasRO = isreadonly(mt)
            if wasRO then makewritable(mt) end
            mt.__namecall = originalNamecall
            if wasRO then makereadonly(mt) end
        end
    end
    if hookfunction then
        hookfunction(originalEvent,     originalEvent)
        hookfunction(originalUnreliable, originalUnreliable)
        hookfunction(originalFunction,  originalFunction)
    end
end

-- ============================================================
-- SHUTDOWN
-- ============================================================

local function Shutdown()
    if schedulerConn then schedulerConn:Disconnect() end
    for _, c in pairs(connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for _, t in ipairs(running_threads) do
        if type(t) == "thread" and cstatus(t) ~= "dead" then
            pcall(cclose, t)
        end
    end
    for k in pairs(activeLoops) do activeLoops[k] = false end
    pcall(disableHooks)
    pcall(function() Screen:Destroy() end)
    pcall(function() Storage:Destroy() end)
    getgenv().HoltSpyExecuted = false
    getgenv().HoltSpyShutdown = nil
end

-- ============================================================
-- CLOSE BUTTON
-- ============================================================

CloseButton and CloseButton.MouseButton1Click:Connect(Shutdown)
-- CloseBtn is the actual button var name used above
local _closeConn = CloseBtn.MouseButton1Click:Connect(Shutdown)

-- ============================================================
-- TITLE BUTTON: toggle spy on/off
-- ============================================================

local spyActive = false

local function ToggleSpy()
    if not spyActive then
        enableHooks()
        spyActive = true
        TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.Success}):Play()
    else
        disableHooks()
        spyActive = false
        TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.AccentL}):Play()
    end
end

TitleBtn.MouseButton1Click:Connect(ToggleSpy)

TitleBtn.MouseEnter:Connect(function()
    TweenService:Create(TitleBtn, TweenInfo.new(0.15), {
        TextColor3 = spyActive and T.Error or T.Success
    }):Play()
end)
TitleBtn.MouseLeave:Connect(function()
    TweenService:Create(TitleBtn, TweenInfo.new(0.15), {
        TextColor3 = spyActive and T.Success or T.AccentL
    }):Play()
end)

-- ============================================================
-- INIT
-- ============================================================

local function Init()
    if not RunService:IsClient() then
        warn("[Holt Spy] Must run on client!")
        return
    end

    getgenv().HoltSpyExecuted = true
    getgenv().HoltSpyShutdown = Shutdown

    -- Parent GUI
    local guiParent = (gethui and gethui())
        or (syn and syn.protect_gui and syn.protect_gui(Screen) and CoreGui)
        or CoreGui
    Screen.Parent = guiParent
    Screen.Enabled = true

    -- Show loading (non-blocking)
    logThread(spawn(ShowLoadingScreen))

    -- Setup dragging
    setupDrag()

    -- Init codebox (Highlight)
    codebox = Highlight.new(CodeFrame)
    codebox:setRaw("-- Holt Spy ready\n-- Click a remote in the list to view code\n-- Right-click for advanced options\n-- discord.gg/E7Tfjgruck")

    -- Start scheduler
    schedulerConn = RunService.Heartbeat:Connect(taskScheduler)

    -- Start spying immediately
    ToggleSpy()

    -- Generation table for known instances
    logThread(spawn(function()
        local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
        if lp then
            generation[SafeDebugId(lp)] = 'game:GetService("Players").LocalPlayer'
        end
    end))

    -- Keep window in bounds on viewport resize
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local vp = workspace.CurrentCamera.ViewportSize
        local pos = Background.AbsolutePosition
        local newX = math.clamp(pos.X, 0, math.max(0, vp.X - WIN_W))
        local newY = math.clamp(pos.Y, 0, math.max(0, vp.Y - WIN_H - GuiInset.Y))
        Background.Position = UDim2.new(0, newX, 0, newY)
    end)
end

Init()
