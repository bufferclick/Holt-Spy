--[[
    Holt Spy - Advanced Remote Spy
    Made by BufferClick
    Discord: https://discord.gg/E7Tfjgruck
    Website: holt.pages.dev
]]

if getgenv().HoltSpyExecuted and type(getgenv().HoltSpyShutdown) == "function" then
    getgenv().HoltSpyShutdown()
    task.wait(0.2)
end

-- ============================================================
-- SERVICES
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TextService      = game:GetService("TextService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local GuiService       = game:GetService("GuiService")

local cloneref = cloneref or function(x) return x end

-- ============================================================
-- SAFETY WRAPPERS (never error, never break game)
-- ============================================================

local newcclosure       = newcclosure       or function(f) return f end
local hookmetamethod    = hookmetamethod    or nil
local hookfunction      = hookfunction      or nil
local getnamecallmethod = getnamecallmethod or function() return "" end
local checkcaller       = checkcaller       or function() return false end
local getcallingscript  = getcallingscript  or function() return nil end
local isreadonly        = isreadonly        or table.isfrozen or function() return false end
local makewritable      = makewriteable     or (setreadonly and function(t) setreadonly(t, false) end) or function() end
local makereadonly2     = makereadonly      or (setreadonly and function(t) setreadonly(t, true) end)  or function() end
local getnilinstances   = getnilinstances   or function() return {} end
local getrawmeta        = getrawmetatable   or function(x) return getmetatable(x) end
local OldDebugId        = game.GetDebugId

local setclipboard = setclipboard or toclipboard or set_clipboard
    or (Clipboard and Clipboard.set)
    or function() end

-- ============================================================
-- EXTERNAL LIBS
-- ============================================================

local Highlight, LazyFix
pcall(function()
    Highlight = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()
end)
pcall(function()
    LazyFix = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"))()
end)

-- ============================================================
-- HELPERS
-- ============================================================

local function deepclone(t, seen)
    seen = seen or {}
    if type(t) ~= "table" then
        if typeof(t) == "Instance" then
            local ok, r = pcall(cloneref, t)
            return ok and r or t
        end
        return t
    end
    if seen[t] then return seen[t] end
    local copy = {}
    seen[t] = copy
    for k, v in next, t do
        copy[deepclone(k, seen)] = deepclone(v, seen)
    end
    return copy
end

local function SafeDebugId(obj)
    local ok, id = pcall(OldDebugId, obj)
    return ok and id or ""
end

-- ============================================================
-- THEME
-- ============================================================

local T = {
    BG      = Color3.fromRGB(15, 15, 20),
    Surface = Color3.fromRGB(22, 22, 28),
    SurfL   = Color3.fromRGB(30, 30, 38),
    SurfLL  = Color3.fromRGB(40, 40, 50),
    TopBar  = Color3.fromRGB(10, 10, 14),
    Accent  = Color3.fromRGB(90, 70, 200),
    AccentL = Color3.fromRGB(120, 100, 240),
    Text    = Color3.fromRGB(215, 215, 225),
    TextDim = Color3.fromRGB(130, 130, 150),
    TextMut = Color3.fromRGB(80, 80, 100),
    EvCol   = Color3.fromRGB(255, 200, 50),
    FnCol   = Color3.fromRGB(100, 140, 255),
    Err     = Color3.fromRGB(220, 60, 60),
    Succ    = Color3.fromRGB(60, 200, 100),
    Border  = Color3.fromRGB(45, 45, 60),
    Scroll  = Color3.fromRGB(55, 55, 75),
}

-- ============================================================
-- CREATE HELPERS
-- ============================================================

local function New(cls, props)
    local o = Instance.new(cls)
    for k, v in next, props or {} do
        if k ~= "Parent" then o[k] = v end
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end
local function Corner(r, p) return New("UICorner", {CornerRadius = UDim.new(0, r), Parent = p}) end
local function Stroke(c, th, p) return New("UIStroke", {Color = c, Thickness = th, Parent = p}) end
local function Pad(l, r, t, b, p)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
        PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b), Parent = p,
    })
end

-- ============================================================
-- GUI ROOT
-- ============================================================

local GuiParent = CoreGui
if gethui then GuiParent = gethui() end

local Screen = New("ScreenGui", {
    Name = "HoltSpy", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999, IgnoreGuiInset = true,
    Parent = GuiParent,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, Screen) end

-- ============================================================
-- DEVICE SELECT
-- ============================================================

local isMobile = false
local deviceDone = Instance.new("BindableEvent")

local DFrame = New("Frame", {
    Parent = Screen, BackgroundColor3 = T.BG,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 260, 0, 170),
    BorderSizePixel = 0, ZIndex = 9999,
})
Corner(10, DFrame)
Stroke(T.AccentL, 1.5, DFrame)

New("TextLabel", {
    Parent = DFrame, BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 16),
    Size = UDim2.new(1, 0, 0, 26),
    Font = Enum.Font.GothamBold, Text = "Holt Spy",
    TextColor3 = T.AccentL, TextSize = 20,
    ZIndex = 10000,
})
New("TextLabel", {
    Parent = DFrame, BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 46),
    Size = UDim2.new(1, 0, 0, 16),
    Font = Enum.Font.Gotham, Text = "Select your device",
    TextColor3 = T.TextDim, TextSize = 12,
    ZIndex = 10000,
})
New("TextLabel", {
    Parent = DFrame, BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 1, -20),
    Size = UDim2.new(1, 0, 0, 14),
    Font = Enum.Font.Gotham,
    Text = "holt.pages.dev | discord.gg/E7Tfjgruck",
    TextColor3 = T.TextMut, TextSize = 9,
    ZIndex = 10000,
})

local function DBtn(txt, xPos, cb)
    local b = New("TextButton", {
        Parent = DFrame, BackgroundColor3 = T.Accent,
        BorderSizePixel = 0, Position = UDim2.new(xPos, 0, 0, 80),
        Size = UDim2.new(0, 100, 0, 34),
        Font = Enum.Font.GothamBold, Text = txt,
        TextColor3 = T.Text, TextSize = 12,
        AutoButtonColor = false, ZIndex = 10000,
    })
    Corner(6, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.AccentL}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.Accent}):Play()
    end)
    b.MouseButton1Click:Connect(function()
        cb()
        DFrame:Destroy()
        deviceDone:Fire()
    end)
end

DBtn("PC", 0.08, function() isMobile = false end)
DBtn("Mobile", 0.53, function() isMobile = true end)

deviceDone.Event:Wait()
deviceDone:Destroy()
task.wait(0.1)

-- ============================================================
-- SIZING
-- ============================================================

local W    = isMobile and 260 or 520
local H    = isMobile and 210 or 340
local LW   = isMobile and 85  or 145
local TH   = isMobile and 22  or 28
local BW   = isMobile and 64  or 96
local BH   = isMobile and 18  or 24
local FS   = isMobile and 9   or 11
local FSM  = isMobile and 10  or 12
local FSL  = isMobile and 11  or 14
local RH   = isMobile and 18  or 22
local BWin = TH + 4

-- ============================================================
-- LOADING NOTIFICATION
-- ============================================================

local LoadF = New("Frame", {
    Parent = Screen, BackgroundColor3 = T.BG,
    Size = UDim2.new(0, 190, 0, 56),
    Position = UDim2.new(1, -200, 1, -66),
    BorderSizePixel = 0, ZIndex = 8000,
})
Corner(8, LoadF)
Stroke(T.AccentL, 1, LoadF)

New("TextLabel", {
    Parent = LoadF, BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 6),
    Size = UDim2.new(1, -20, 0, 16),
    Font = Enum.Font.GothamBold, Text = "Holt Spy",
    TextColor3 = T.AccentL, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8001,
})
New("TextLabel", {
    Parent = LoadF, BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 22),
    Size = UDim2.new(1, -20, 0, 10),
    Font = Enum.Font.Gotham, Text = "by BufferClick",
    TextColor3 = T.TextMut, TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8001,
})

local LBarBG = New("Frame", {
    Parent = LoadF, BackgroundColor3 = T.SurfLL,
    Position = UDim2.new(0, 10, 0, 40),
    Size = UDim2.new(1, -20, 0, 3),
    BorderSizePixel = 0, ZIndex = 8001,
})
Corner(2, LBarBG)
local LFill = New("Frame", {
    Parent = LBarBG, BackgroundColor3 = T.AccentL,
    Size = UDim2.new(0, 0, 1, 0),
    BorderSizePixel = 0, ZIndex = 8002,
})
Corner(2, LFill)

-- ============================================================
-- MINIMIZED ICON
-- ============================================================

local MinIcon = New("Frame", {
    Parent = Screen, BackgroundColor3 = T.Accent,
    Size = UDim2.new(0, 42, 0, 42),
    Position = UDim2.new(0, 10, 0.5, -21),
    BorderSizePixel = 0, ZIndex = 490, Visible = false,
})
Corner(21, MinIcon)
Stroke(T.AccentL, 2, MinIcon)

local MinIconInner = New("Frame", {
    Parent = MinIcon, BackgroundColor3 = T.AccentL,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 30, 0, 30),
    BorderSizePixel = 0, ZIndex = 491,
    BackgroundTransparency = 0.85,
})
Corner(15, MinIconInner)

local MinIconBtn = New("TextButton", {
    Parent = MinIcon, BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold, Text = "HS",
    TextColor3 = T.Text, TextSize = isMobile and 10 or 12,
    AutoButtonColor = false, ZIndex = 492,
})

-- ============================================================
-- MAIN WINDOW
-- ============================================================

local BG = New("Frame", {
    Parent = Screen, Name = "BG", BackgroundColor3 = T.BG,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, W, 0, H), ZIndex = 10,
})
Corner(8, BG)
Stroke(T.Border, 1, BG)

local TopBar = New("Frame", {
    Parent = BG, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, TH),
    ZIndex = 20, ClipsDescendants = true,
})
Corner(8, TopBar)
New("Frame", {
    Parent = TopBar, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -6),
    Size = UDim2.new(1, 0, 0, 6), ZIndex = 21,
})

local TitleBtn = New("TextButton", {
    Parent = TopBar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 8, 0, 0),
    Size = UDim2.new(0, 70, 1, 0),
    Font = Enum.Font.GothamBold, Text = "Holt Spy",
    TextColor3 = T.AccentL, TextSize = FSL,
    TextXAlignment = Enum.TextXAlignment.Left,
    AutoButtonColor = false, ZIndex = 22,
})

local function MakeWinBtn(icon, xOff, hCol)
    local b = New("TextButton", {
        Parent = TopBar, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, xOff, 0, 0),
        Size = UDim2.new(0, BWin, 1, 0),
        Font = Enum.Font.GothamBold, Text = icon,
        TextColor3 = T.TextDim, TextSize = FSM,
        AutoButtonColor = false, ZIndex = 22,
    })
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = hCol or T.Text}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = T.TextDim}):Play()
    end)
    return b
end

local CloseBtn = MakeWinBtn("X", 0, T.Err)
local SideBtn  = MakeWinBtn("+", -BWin, T.AccentL)
local MinBtn   = MakeWinBtn("_", -BWin * 2, T.TextDim)

-- Left Panel
local LP = New("Frame", {
    Parent = BG, BackgroundColor3 = T.Surface,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, TH),
    Size = UDim2.new(0, LW, 1, -TH),
    ClipsDescendants = true, ZIndex = 10,
})
New("Frame", {
    Parent = LP, BackgroundColor3 = T.Border,
    BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0), ZIndex = 11,
})

local SBar = New("TextBox", {
    Parent = LP, BackgroundColor3 = T.SurfLL,
    BorderSizePixel = 0, Position = UDim2.new(0, 4, 0, 3),
    Size = UDim2.new(1, -8, 0, isMobile and 16 or 20),
    Font = Enum.Font.Gotham, PlaceholderText = "Search...",
    PlaceholderColor3 = T.TextMut, Text = "",
    TextColor3 = T.Text, TextSize = FS,
    ClearTextOnFocus = false, ZIndex = 12,
})
Corner(3, SBar)
Pad(4, 4, 0, 0, SBar)

local LogList = New("ScrollingFrame", {
    Parent = LP, BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 2, 0, isMobile and 22 or 26),
    Size = UDim2.new(1, -4, 1, -(isMobile and 22 or 26)),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 2, ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12,
})
New("UIListLayout", {
    Parent = LogList,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 1),
})

-- Right Panel
local RP = New("Frame", {
    Parent = BG, BackgroundColor3 = T.BG,
    BorderSizePixel = 0,
    Position = UDim2.new(0, LW, 0, TH),
    Size = UDim2.new(1, -LW, 1, -TH),
    ClipsDescendants = true, ZIndex = 10, Visible = false,
})

-- Code area top 45%
local CodeFrame = New("Frame", {
    Parent = RP, BackgroundColor3 = T.Surface,
    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.45, 0),
    ClipsDescendants = true, ZIndex = 11,
})

New("Frame", {
    Parent = RP, BackgroundColor3 = T.Border,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.45, 0),
    Size = UDim2.new(1, 0, 0, 1), ZIndex = 12,
})

-- Action buttons area (bottom 55%) - scrollable list of action buttons
local ActionScroll = New("ScrollingFrame", {
    Parent = RP, BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0.45, 2),
    Size = UDim2.new(1, 0, 0.55, -2),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 2, ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12,
})
New("UIListLayout", {
    Parent = ActionScroll,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
})
Pad(4, 4, 4, 4, ActionScroll)

-- Edit Panel
local EditPanel = New("Frame", {
    Parent = Screen, BackgroundColor3 = T.BG,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, isMobile and 250 or 400, 0, isMobile and 200 or 270),
    Visible = false, ZIndex = 700,
})
Corner(8, EditPanel)
Stroke(T.Border, 1, EditPanel)

local EditTBar = New("Frame", {
    Parent = EditPanel, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24),
    ZIndex = 701, ClipsDescendants = true,
})
Corner(8, EditTBar)
New("Frame", {
    Parent = EditTBar, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -5),
    Size = UDim2.new(1, 0, 0, 5), ZIndex = 702,
})
New("TextLabel", {
    Parent = EditTBar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 8, 0, 0),
    Size = UDim2.new(0.8, 0, 1, 0),
    Font = Enum.Font.GothamBold, Text = "Edit Code",
    TextColor3 = T.AccentL, TextSize = FSL,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 702,
})
local EditCloseBtn = New("TextButton", {
    Parent = EditTBar, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 24, 1, 0),
    Font = Enum.Font.GothamBold, Text = "X",
    TextColor3 = T.TextDim, TextSize = FSM,
    AutoButtonColor = false, ZIndex = 702,
})

local EditInput = New("TextBox", {
    Parent = EditPanel, BackgroundColor3 = T.Surface,
    BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 30),
    Size = UDim2.new(1, -12, 1, -62),
    Font = Enum.Font.Code, Text = "",
    TextColor3 = T.Text, TextSize = FS,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false, MultiLine = true,
    TextWrapped = true, ZIndex = 702, ClipsDescendants = true,
})
Corner(4, EditInput)
Pad(6, 6, 4, 4, EditInput)

local EditSaveBtn = New("TextButton", {
    Parent = EditPanel, BackgroundColor3 = T.Accent,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -6),
    Size = UDim2.new(0, 100, 0, 22),
    Font = Enum.Font.GothamBold, Text = "Save Modified",
    TextColor3 = T.Text, TextSize = FS,
    AutoButtonColor = false, ZIndex = 702,
})
Corner(4, EditSaveBtn)

-- Modified Panel
local ModPanel = New("Frame", {
    Parent = Screen, BackgroundColor3 = T.BG,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, isMobile and 250 or 400, 0, isMobile and 200 or 270),
    Visible = false, ZIndex = 700,
})
Corner(8, ModPanel)
Stroke(T.Border, 1, ModPanel)

local ModTBar = New("Frame", {
    Parent = ModPanel, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24),
    ZIndex = 701, ClipsDescendants = true,
})
Corner(8, ModTBar)
New("Frame", {
    Parent = ModTBar, BackgroundColor3 = T.TopBar,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -5),
    Size = UDim2.new(1, 0, 0, 5), ZIndex = 702,
})
New("TextLabel", {
    Parent = ModTBar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 8, 0, 0),
    Size = UDim2.new(0.8, 0, 1, 0),
    Font = Enum.Font.GothamBold, Text = "Modified Code",
    TextColor3 = T.AccentL, TextSize = FSL,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 702,
})
local ModCloseBtn = New("TextButton", {
    Parent = ModTBar, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 24, 1, 0),
    Font = Enum.Font.GothamBold, Text = "X",
    TextColor3 = T.TextDim, TextSize = FSM,
    AutoButtonColor = false, ZIndex = 702,
})
local ModList = New("ScrollingFrame", {
    Parent = ModPanel, BackgroundTransparency = 1,
    BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 30),
    Size = UDim2.new(1, -12, 1, -36),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 2, ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 702,
})
New("UIListLayout", {
    Parent = ModList, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
})

-- Overlay
local Overlay = New("TextButton", {
    Parent = Screen, BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
    Text = "", AutoButtonColor = false,
    Visible = false, ZIndex = 399, BorderSizePixel = 0,
})

-- ============================================================
-- STATE
-- ============================================================

local logs, remoteLogs = {}, {}
local selected = nil
local blacklistById   = {} -- key = debugId string
local blacklistByName = {} -- key = remote name string
local blocklist       = {} -- key = debugId or name
local scheduled       = {}
local activeLoops     = {}
local modifiedCodes   = {}
local history, excluding = {}, {}
local layoutOrder     = 999999999
local sideClosed      = true
local isMinimized     = false
local spyActive       = false
local schedulerConn   = nil
local codebox         = nil
local originalNamecall = nil
local realAutoblock   = false
local realLogCaller   = false

getgenv().HOLTSPY_MaxRemotes = 500

local Storage        = New("Folder", {Parent = CoreGui})
local _re            = New("RemoteEvent", {Parent = Storage})
local _ure           = New("UnreliableRemoteEvent")
local _rf            = New("RemoteFunction", {Parent = Storage})
local origFire       = _re.FireServer
local origUnreliable = _ure.FireServer
local origInvoke     = _rf.InvokeServer

local function logThread(t) end -- simplified, no need to track

-- ============================================================
-- OVERLAY HELPERS
-- ============================================================

local function ShowOverlay()
    Overlay.Visible = true
    TweenService:Create(Overlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.6}):Play()
end
local function HideOverlay()
    TweenService:Create(Overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    task.delay(0.22, function() Overlay.Visible = false end)
end

-- ============================================================
-- SCRIPT GENERATION
-- ============================================================

local getnilReq = false

local function i2p(inst)
    if not inst then return "nil" end
    local ok, res = pcall(function()
        local lp = Players.LocalPlayer
        if lp and (inst == lp or inst:IsDescendantOf(lp)) then
            local rel = inst:GetFullName():sub(#lp:GetFullName() + 2)
            return 'game:GetService("Players").LocalPlayer' .. (rel ~= "" and ("." .. rel) or "")
        end
        local obj = inst
        while obj.Parent and obj.Parent ~= game do obj = obj.Parent end
        if obj.Parent == game then
            local sOk, svc = pcall(function() return game:GetService(obj.ClassName) end)
            if sOk and svc then
                local pfx = obj.ClassName == "Workspace" and "workspace"
                    or ('game:GetService("' .. obj.ClassName .. '")')
                local rel = inst:GetFullName():sub(#obj:GetFullName() + 2)
                return pfx .. (rel ~= "" and ("." .. rel) or "")
            end
        end
        if not inst.Parent then
            getnilReq = true
            return 'getNil("' .. inst.Name .. '", "' .. inst.ClassName .. '")'
        end
        return "game." .. inst:GetFullName():sub(6)
    end)
    return ok and res or tostring(inst)
end

local function v2s(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then
        if v ~= v then return "0/0"
        elseif v == math.huge then return "math.huge"
        elseif v == -math.huge then return "-math.huge"
        else return tostring(v) end
    elseif t == "string" then return string.format("%q", v)
    elseif t == "Instance" then return i2p(v)
    elseif t == "Vector3" then return ("Vector3.new(%g,%g,%g)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then return ("Vector2.new(%g,%g)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local c = {v:GetComponents()}
        local p2 = {}; for _, n in ipairs(c) do p2[#p2+1] = tostring(n) end
        return "CFrame.new(" .. table.concat(p2, ",") .. ")"
    elseif t == "Color3" then return ("Color3.new(%g,%g,%g)"):format(v.R, v.G, v.B)
    elseif t == "UDim2" then return ("UDim2.new(%g,%g,%g,%g)"):format(v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then return ("UDim.new(%g,%g)"):format(v.Scale, v.Offset)
    elseif t == "BrickColor" then return ('BrickColor.new("%s")'):format(v.Name)
    elseif t == "EnumItem" then return tostring(v)
    elseif t == "table" then
        if d > 5 then return "{}" end
        local parts = {}
        for k, val in next, v do
            local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. v2s(k, d+1) .. "]")
            parts[#parts+1] = ks .. "=" .. v2s(val, d+1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else return tostring(v) end
end

local function genScript(remote, args)
    getnilReq = false
    local rp = i2p(remote)
    local pfx, argsStr = "", ""
    if args and #args > 0 then
        local ok, res = false, nil
        if LazyFix then ok, res = pcall(LazyFix.Convert, args, true) end
        if ok and res then argsStr = "local args = " .. res .. "\n"
        else
            local p2 = {}
            for _, a in ipairs(args) do p2[#p2+1] = v2s(a) end
            argsStr = "local args = {" .. table.concat(p2, ", ") .. "}\n"
        end
    end
    if getnilReq then
        pfx = "local function getNil(n,c) for _,v in next,getnilinstances()do if v.ClassName==c and v.Name==n then return v end end end\n\n"
    end
    local call
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        call = args and #args > 0 and (rp..":FireServer(table.unpack(args))") or (rp..":FireServer()")
    elseif remote:IsA("RemoteFunction") then
        call = args and #args > 0
            and ("local r="..rp..":InvokeServer(table.unpack(args))\nprint(r)")
            or  ("local r="..rp..":InvokeServer()\nprint(r)")
    else call = "-- Unknown" end
    return pfx .. argsStr .. call
end

-- ============================================================
-- IS BLACKLISTED CHECK (proper)
-- ============================================================

local function isBlacklisted(id, name)
    return blacklistById[id] == true or blacklistByName[name] == true
end

local function isBlocked(id, name)
    return blocklist[id] == true or blocklist[name] == true
end

-- ============================================================
-- ACTION BUTTONS IN RIGHT PANEL (rebuilt when selecting a remote)
-- ============================================================

local function ClearActions()
    for _, c in ipairs(ActionScroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end
end

local function ActionBtn(txt, order, cb, col)
    local b = New("TextButton", {
        Parent = ActionScroll, BackgroundColor3 = T.SurfLL,
        BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, BH),
        Font = Enum.Font.Gotham, Text = "  " .. txt,
        TextColor3 = col or T.Text, TextSize = FS,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = order,
        ZIndex = 13,
    })
    Corner(4, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfL}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfLL}):Play()
    end)
    b.MouseButton1Click:Connect(function()
        if cb then cb() end
    end)
    return b
end

local function BuildActions(log)
    ClearActions()
    if not log or not log.Remote then return end

    local remote = log.Remote
    local remId  = log.DebugId
    local remName = log.Name
    local o = 0
    local function no() o = o + 1; return o end

    ActionBtn("Copy Code", no(), function()
        if log.GenScript then setclipboard(log.GenScript) end
    end)
    ActionBtn("Run Code", no(), function()
        xpcall(function()
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                remote:FireServer(table.unpack(log.args or {}))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(table.unpack(log.args or {}))
            end
        end, function(e) warn("[HoltSpy] " .. e) end)
    end)
    ActionBtn("Copy Looped Code", no(), function()
        if log.GenScript then
            setclipboard("while task.wait(0.1) do\n    " .. log.GenScript:gsub("\n", "\n    ") .. "\nend")
        end
    end)
    ActionBtn("Run Looped Code", no(), function()
        local lid = tostring(remId) .. "_lp"
        activeLoops[lid] = true
        task.spawn(function()
            while activeLoops[lid] do
                xpcall(function()
                    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                        remote:FireServer(table.unpack(log.args or {}))
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(table.unpack(log.args or {}))
                    end
                end, function() end)
                task.wait(0.1)
            end
        end)
    end)
    ActionBtn("Stop All Loops", no(), function()
        for k in pairs(activeLoops) do activeLoops[k] = false end
        table.clear(activeLoops)
    end)
    ActionBtn("Copy Toggled Code", no(), function()
        if not log.GenScript then return end
        local tag = tostring(remId):sub(-4)
        local inner = log.GenScript:gsub("\n", "\n            ")
        setclipboard(
            "_G._hl"..tag.."=not _G._hl"..tag.."\n"
            .."if _G._hl"..tag.." then task.spawn(function()\n"
            .."    while _G._hl"..tag.." do task.wait(0.1)\n        "
            ..inner.."\n    end\nend) end"
        )
    end)
    ActionBtn("Edit Code", no(), function()
        EditInput.Text = log.GenScript or ""
        EditPanel.Visible = true
        ShowOverlay()
        local sc, cc, oc
        local function cls()
            HideOverlay(); EditPanel.Visible = false
            if sc then sc:Disconnect() end
            if cc then cc:Disconnect() end
            if oc then oc:Disconnect() end
        end
        sc = EditSaveBtn.MouseButton1Click:Connect(function()
            table.insert(modifiedCodes, {Name = log.Name or "?", Code = EditInput.Text, Time = os.date("%H:%M:%S")})
            cls()
        end)
        cc = EditCloseBtn.MouseButton1Click:Connect(cls)
        oc = Overlay.MouseButton1Click:Connect(cls)
    end)
    ActionBtn("View Modified", no(), function()
        RefreshModPanel()
        ModPanel.Visible = true
        ShowOverlay()
    end)
    ActionBtn("Exclude (Instance)", no(), function()
        if remId and remId ~= "" then
            blacklistById[remId] = true
            -- Remove from logs
            for i = #logs, 1, -1 do
                if logs[i].DebugId == remId then
                    if logs[i].Log and logs[i].Log.Parent then logs[i].Log:Destroy() end
                    table.remove(logs, i)
                end
            end
            selected = nil
            ClearActions()
            if codebox then codebox:setRaw("-- Excluded") end
        end
    end)
    ActionBtn("Exclude (Name)", no(), function()
        if remName and remName ~= "" then
            blacklistByName[remName] = true
            for i = #logs, 1, -1 do
                if logs[i].Name == remName then
                    if logs[i].Log and logs[i].Log.Parent then logs[i].Log:Destroy() end
                    table.remove(logs, i)
                end
            end
            selected = nil
            ClearActions()
            if codebox then codebox:setRaw("-- Excluded by name: " .. remName) end
        end
    end)
    ActionBtn("Block (Instance)", no(), function()
        if remId then blocklist[remId] = true end
    end)
    ActionBtn("Block (Name)", no(), function()
        if remName then blocklist[remName] = true end
    end)
    ActionBtn("Clear Blacklist", no(), function()
        table.clear(blacklistById)
        table.clear(blacklistByName)
        table.clear(blocklist)
    end)
    ActionBtn("Copy Remote Path", no(), function()
        pcall(function() setclipboard(remote:GetFullName()) end)
    end)
    ActionBtn("Discord", no(), function()
        setclipboard("https://discord.gg/E7Tfjgruck")
    end)
end

-- ============================================================
-- MODIFIED CODE
-- ============================================================

function RefreshModPanel()
    for _, c in ipairs(ModList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for i, entry in ipairs(modifiedCodes) do
        local row = New("TextButton", {
            Parent = ModList, BackgroundColor3 = T.SurfL,
            BorderSizePixel = 0, Size = UDim2.new(1, -2, 0, RH + 2),
            Font = Enum.Font.Gotham,
            Text = " [" .. entry.Time .. "] " .. entry.Name,
            TextColor3 = T.Text, TextSize = FS,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false, LayoutOrder = i, ZIndex = 703,
        })
        Corner(3, row)
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfLL}):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfL}):Play()
        end)
        row.MouseButton1Click:Connect(function()
            -- Show code in codebox and rebuild actions for modified entry
            if codebox then codebox:setRaw(entry.Code) end
            ClearActions()
            local o = 0
            local function no() o = o + 1; return o end
            ActionBtn("Copy Code", no(), function() setclipboard(entry.Code) end)
            ActionBtn("Run Code", no(), function()
                local fn = loadstring(entry.Code)
                if fn then xpcall(fn, function(e) warn("[HoltSpy] " .. e) end) end
            end)
            ActionBtn("Copy Looped", no(), function()
                setclipboard("while task.wait(0.1) do\n    " .. entry.Code:gsub("\n", "\n    ") .. "\nend")
            end)
            ActionBtn("Run Looped", no(), function()
                local lid = "mod_" .. tostring(i)
                activeLoops[lid] = true
                task.spawn(function()
                    while activeLoops[lid] do
                        local fn = loadstring(entry.Code)
                        if fn then xpcall(fn, function() end) end
                        task.wait(0.1)
                    end
                end)
            end)
            ActionBtn("Stop All Loops", no(), function()
                for k in pairs(activeLoops) do activeLoops[k] = false end
                table.clear(activeLoops)
            end)
            ActionBtn("Edit", no(), function()
                EditInput.Text = entry.Code
                EditPanel.Visible = true; ShowOverlay()
                local sc, cc, oc
                local function cls()
                    HideOverlay(); EditPanel.Visible = false
                    if sc then sc:Disconnect() end
                    if cc then cc:Disconnect() end
                    if oc then oc:Disconnect() end
                end
                sc = EditSaveBtn.MouseButton1Click:Connect(function()
                    entry.Code = EditInput.Text; cls(); RefreshModPanel()
                end)
                cc = EditCloseBtn.MouseButton1Click:Connect(cls)
                oc = Overlay.MouseButton1Click:Connect(cls)
            end)
            ActionBtn("Delete", no(), function()
                for idx, e in ipairs(modifiedCodes) do
                    if e == entry then table.remove(modifiedCodes, idx); break end
                end
                RefreshModPanel()
            end, T.Err)
        end)
    end
end

ModCloseBtn.MouseButton1Click:Connect(function()
    ModPanel.Visible = false; HideOverlay()
end)
Overlay.MouseButton1Click:Connect(function()
    EditPanel.Visible = false
    ModPanel.Visible = false
    HideOverlay()
end)

-- ============================================================
-- LOG ENTRIES
-- ============================================================

local function SelectLog(log)
    for _, l in ipairs(logs) do
        if l.Button then l.Button.BackgroundTransparency = 0.85 end
    end
    selected = log
    if log and log.Button then log.Button.BackgroundTransparency = 0.3 end
    if log then
        if sideClosed then
            sideClosed = false
            RP.Visible = true
            TweenService:Create(LP, TweenInfo.new(0.2), {Size = UDim2.new(0, LW, 1, -TH)}):Play()
            TweenService:Create(RP, TweenInfo.new(0.2), {Size = UDim2.new(1, -LW, 1, -TH)}):Play()
        end
        if codebox then codebox:setRaw(log.GenScript or "-- Generating...") end
        BuildActions(log)
    end
end

local function AddRemoteLog(rType, data)
    if layoutOrder < 1 then layoutOrder = 999999999 end
    local remote = data.remote
    if not remote then return end

    local frame = New("Frame", {
        LayoutOrder = layoutOrder, Name = "RL",
        Parent = LogList, BackgroundTransparency = 1,
        Size = UDim2.new(1, -2, 0, RH),
    })
    New("Frame", {
        Parent = frame, BackgroundColor3 = rType == "event" and T.EvCol or T.FnCol,
        BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.15, 0),
        Size = UDim2.new(0, 2, 0.7, 0), ZIndex = 13,
    })
    New("TextLabel", {
        Parent = frame, BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        Font = Enum.Font.Gotham, Text = remote.Name,
        TextColor3 = T.Text, TextSize = FS,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13,
    })
    local btn = New("TextButton", {
        Name = "B", Parent = frame,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.85, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        AutoButtonColor = false, Text = "", ZIndex = 14,
    })
    Corner(3, btn)

    btn.MouseEnter:Connect(function()
        if not (selected and selected.Log == frame) then
            btn.BackgroundTransparency = 0.65
        end
    end)
    btn.MouseLeave:Connect(function()
        if not (selected and selected.Log == frame) then
            btn.BackgroundTransparency = 0.85
        end
    end)

    local log = {
        Name = remote.Name, Remote = remote,
        DebugId = data.id, args = data.args or {},
        Log = frame, Button = btn,
        Blocked = data.blockcheck or false,
        Source = data.callingscript,
        GenScript = "-- Generating...",
    }

    task.spawn(function()
        local ok, res = pcall(genScript, remote, log.args)
        log.GenScript = ok and res or ("-- Error: " .. tostring(res))
        if log.Blocked then log.GenScript = "-- BLOCKED\n\n" .. log.GenScript end
        if selected == log and codebox then codebox:setRaw(log.GenScript) end
    end)

    -- LEFT CLICK: select, open right panel, show action buttons
    btn.MouseButton1Click:Connect(function()
        SelectLog(log)
        if codebox then codebox:setRaw(log.GenScript or "-- Generating...") end
    end)

    -- RIGHT CLICK on PC only (no context menu, no long press on mobile)
    if not isMobile then
        btn.MouseButton2Click:Connect(function()
            SelectLog(log)
        end)
    end

    table.insert(logs, log)
    layoutOrder = layoutOrder - 1

    -- Cleanup
    local max = getgenv().HOLTSPY_MaxRemotes or 500
    table.insert(remoteLogs, 1, frame)
    if #remoteLogs > max then
        for i = max + 1, #remoteLogs do
            if remoteLogs[i] and remoteLogs[i].Parent then remoteLogs[i]:Destroy() end
        end
        while #remoteLogs > max do table.remove(remoteLogs) end
        while #logs > max do table.remove(logs) end
    end
end

-- ============================================================
-- SEARCH
-- ============================================================

SBar:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SBar.Text:lower()
    for _, c in ipairs(LogList:GetChildren()) do
        if c:IsA("Frame") and c.Name == "RL" then
            local lbl = c:FindFirstChildWhichIsA("TextLabel")
            if lbl then c.Visible = q == "" or (lbl.Text:lower():find(q, 1, true) ~= nil) end
        end
    end
end)

-- ============================================================
-- REMOTE HANDLER (LOG ONLY - NEVER INTERFERE WITH GAME)
-- ============================================================

local function remoteHandler(data)
    if not data or not data.remote then return end
    local id   = data.id or ""
    local name = data.remote.Name or ""

    -- Check blacklist (proper check)
    if isBlacklisted(id, name) then return end

    -- Autoblock spam filter
    if realAutoblock then
        if excluding[id] then return end
        if not history[id] then history[id] = {count = 0, last = tick()} end
        local h = history[id]
        if tick() - h.last < 0.5 then
            h.count = h.count + 1
            if h.count > 20 then excluding[id] = true; return end
        else h.count = 0; h.last = tick() end
    end

    local rtype = data.remote:IsA("RemoteFunction") and "function" or "event"
    AddRemoteLog(rtype, data)
end

-- ============================================================
-- SCHEDULER
-- ============================================================

local function schedule(f, ...)
    local args = {...}
    table.insert(scheduled, function() f(table.unpack(args)) end)
end

local function taskScheduler()
    if #scheduled == 0 then return end
    local fn = table.remove(scheduled, 1)
    if type(fn) == "function" then pcall(fn) end
end

-- ============================================================
-- HOOKS (LOG ONLY - ALWAYS PASS THROUGH TO ORIGINAL)
-- ============================================================

local namecallHook = newcclosure(function(...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "fireServer"
    or method == "InvokeServer" or method == "invokeServer" then
        local self = select(1, ...)
        if typeof(self) == "Instance" and (
            self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")
        ) then
            if not realLogCaller and checkcaller() then
                return originalNamecall(...)
            end
            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or ""
            local name   = ""
            pcall(function() name = self.Name end)

            if not isBlacklisted(safeId, name) then
                local allArgs = {...}
                local passedArgs = {}
                for i = 2, #allArgs do passedArgs[i-1] = allArgs[i] end
                local okC, copied = pcall(deepclone, passedArgs)
                local cs; pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end
                schedule(remoteHandler, {
                    method = method, remote = self,
                    args = okC and copied or passedArgs,
                    id = safeId, callingscript = cs, blockcheck = false,
                })
            end
        end
    end
    -- ALWAYS pass through, never block
    return originalNamecall(...)
end)

local function enableHooks()
    if hookmetamethod then
        originalNamecall = hookmetamethod(game, "__namecall", namecallHook)
    else
        local mt = getrawmeta(game)
        local wasRO = isreadonly(mt)
        if wasRO then makewritable(mt) end
        originalNamecall = mt.__namecall
        mt.__namecall = namecallHook
        if wasRO then makereadonly2(mt) end
    end
    spyActive = true
    TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.Succ}):Play()
end

local function disableHooks()
    if originalNamecall then
        if hookmetamethod then
            pcall(hookmetamethod, game, "__namecall", originalNamecall)
        else
            local mt = getrawmeta(game)
            local wasRO = isreadonly(mt)
            if wasRO then makewritable(mt) end
            mt.__namecall = originalNamecall
            if wasRO then makereadonly2(mt) end
        end
    end
    spyActive = false
    TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.AccentL}):Play()
end

-- ============================================================
-- WINDOW CONTROLS
-- ============================================================

-- Dragging (proper mobile friendly)
do
    local dragging = false
    local dragOffset = Vector2.zero

    TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        -- Don't drag if clicking window buttons
        local mp = inp.Position
        local tbAbs = TopBar.AbsolutePosition
        local tbSize = TopBar.AbsoluteSize
        if mp.X > tbAbs.X + tbSize.X - BWin * 3 then return end
        dragging = true
        dragOffset = Vector2.new(mp.X - BG.AbsolutePosition.X, mp.Y - BG.AbsolutePosition.Y)
    end)

    TopBar.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local vp = workspace.CurrentCamera.ViewportSize
        local nx = inp.Position.X - dragOffset.X
        local ny = inp.Position.Y - dragOffset.Y
        nx = math.clamp(nx, 0, vp.X - W)
        ny = math.clamp(ny, 0, vp.Y - TH)
        BG.AnchorPoint = Vector2.new(0, 0)
        BG.Position = UDim2.new(0, nx, 0, ny)
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Minimize (instant)
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    BG.Visible = false
    MinIcon.Visible = true
end)
MinIconBtn.MouseButton1Click:Connect(function()
    isMinimized = false
    MinIcon.Visible = false
    BG.Visible = true
end)
MinIconBtn.MouseEnter:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.12), {BackgroundColor3 = T.AccentL}):Play()
end)
MinIconBtn.MouseLeave:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.12), {BackgroundColor3 = T.Accent}):Play()
end)

-- Side toggle
SideBtn.MouseButton1Click:Connect(function()
    sideClosed = not sideClosed
    if sideClosed then
        TweenService:Create(RP, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, -TH)}):Play()
        TweenService:Create(LP, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, -TH)}):Play()
        task.delay(0.22, function() RP.Visible = false end)
    else
        RP.Visible = true
        TweenService:Create(LP, TweenInfo.new(0.2), {Size = UDim2.new(0, LW, 1, -TH)}):Play()
        TweenService:Create(RP, TweenInfo.new(0.2), {Size = UDim2.new(1, -LW, 1, -TH)}):Play()
    end
end)

-- Title: toggle spy
TitleBtn.MouseButton1Click:Connect(function()
    if spyActive then disableHooks() else enableHooks() end
end)
TitleBtn.MouseEnter:Connect(function()
    TweenService:Create(TitleBtn, TweenInfo.new(0.15), {
        TextColor3 = spyActive and T.Err or T.Succ
    }):Play()
end)
TitleBtn.MouseLeave:Connect(function()
    TweenService:Create(TitleBtn, TweenInfo.new(0.15), {
        TextColor3 = spyActive and T.Succ or T.AccentL
    }):Play()
end)

-- ============================================================
-- SHUTDOWN
-- ============================================================

local function Shutdown()
    if schedulerConn then schedulerConn:Disconnect() end
    for k in pairs(activeLoops) do activeLoops[k] = false end
    pcall(disableHooks)
    pcall(function() Screen:Destroy() end)
    pcall(function() Storage:Destroy() end)
    getgenv().HoltSpyExecuted = false
    getgenv().HoltSpyShutdown = nil
end

CloseBtn.MouseButton1Click:Connect(Shutdown)

-- ============================================================
-- INIT
-- ============================================================

local function Init()
    if not RunService:IsClient() then
        warn("[HoltSpy] Client only!"); return
    end

    getgenv().HoltSpyExecuted = true
    getgenv().HoltSpyShutdown = Shutdown

    if Highlight then
        local ok, cb = pcall(Highlight.new, Highlight, CodeFrame)
        if ok and cb then
            codebox = cb
            codebox:setRaw("-- Holt Spy\n-- Tap a remote to view code\n-- holt.pages.dev | discord.gg/E7Tfjgruck")
        end
    end
    if not codebox then
        local tb = New("TextBox", {
            Parent = CodeFrame, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Font = Enum.Font.Code, Text = "-- Holt Spy ready",
            TextColor3 = T.Text, TextSize = FS,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            MultiLine = true, TextWrapped = true,
            ClearTextOnFocus = false, ZIndex = 12,
        })
        Pad(6, 6, 4, 4, tb)
        codebox = {
            setRaw = function(_, s) tb.Text = s end,
            getString = function(_) return tb.Text end,
        }
    end

    schedulerConn = RunService.Heartbeat:Connect(taskScheduler)
    enableHooks()

    task.spawn(function()
        local steps = {{0.3, "Loading..."}, {0.7, "Hooking..."}, {1.0, "Ready!"}}
        for _, s in ipairs(steps) do
            TweenService:Create(LFill, TweenInfo.new(0.2), {Size = UDim2.new(s[1], 0, 1, 0)}):Play()
            task.wait(0.25)
        end
        task.wait(0.4)
        TweenService:Create(LoadF, TweenInfo.new(0.3), {Position = UDim2.new(1, 10, 1, -66)}):Play()
        task.wait(0.35)
        pcall(function() LoadF:Destroy() end)
    end)
end

Init()
