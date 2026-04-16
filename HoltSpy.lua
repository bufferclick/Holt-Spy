--[[
    Holt Spy - Advanced Remote Spy
    Made by BufferClick
    Discord: https://discord.gg/E7Tfjgruck
]]

if getgenv().HoltSpyExecuted and type(getgenv().HoltSpyShutdown) == "function" then
    getgenv().HoltSpyShutdown()
    task.wait(0.1)
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
local GuiInset = GuiService:GetGuiInset()

-- ============================================================
-- SAFETY WRAPPERS
-- ============================================================

local newcclosure  = newcclosure  or function(f) return f end
local clonefunction = clonefunction or function(f) return f end
local hookmetamethod = hookmetamethod or nil
local hookfunction   = hookfunction   or nil
local getnamecallmethod = getnamecallmethod or function() return "" end
local checkcaller  = checkcaller  or function() return false end
local getcallingscript = getcallingscript or function() return nil end
local isreadonly   = isreadonly   or table.isfrozen or function() return false end
local makewritable = makewriteable or (setreadonly and function(t) setreadonly(t,false) end) or function() end
local makereadonly2 = makereadonly or (setreadonly and function(t) setreadonly(t,true) end) or function() end
local getnilinstances = getnilinstances or function() return {} end
local getrawmetatable = getrawmetatable or function(x) return getmetatable(x) end

local setclipboard = setclipboard or toclipboard or set_clipboard
    or (Clipboard and Clipboard.set)
    or function() warn("[HoltSpy] No clipboard support") end

local OldDebugId = game.GetDebugId

-- ============================================================
-- EXTERNAL LIBRARIES
-- ============================================================

local Highlight, LazyFix

local ok1, r1 = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"
    ))()
end)
Highlight = ok1 and r1

local ok2, r2 = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"
    ))()
end)
LazyFix = ok2 and r2

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
    return ok and id or tostring(obj)
end

local function IsCyclicTable(tbl, visited)
    visited = visited or {}
    if visited[tbl] then return true end
    visited[tbl] = true
    for _, v in next, tbl do
        if type(v) == "table" and IsCyclicTable(v, visited) then
            return true
        end
    end
    return false
end

-- ============================================================
-- DETECT MOBILE
-- ============================================================

local isMobile = UserInputService.TouchEnabled
    and not UserInputService.KeyboardEnabled

-- ============================================================
-- THEME
-- ============================================================

local T = {
    BG       = Color3.fromRGB(15,  15,  20),
    Surface  = Color3.fromRGB(22,  22,  28),
    SurfL    = Color3.fromRGB(30,  30,  38),
    SurfLL   = Color3.fromRGB(40,  40,  50),
    TopBar   = Color3.fromRGB(10,  10,  14),
    Accent   = Color3.fromRGB(90,  70,  200),
    AccentL  = Color3.fromRGB(120, 100, 240),
    Text     = Color3.fromRGB(215, 215, 225),
    TextDim  = Color3.fromRGB(130, 130, 150),
    TextMut  = Color3.fromRGB(80,  80,  100),
    EvCol    = Color3.fromRGB(255, 200, 50),
    FnCol    = Color3.fromRGB(100, 140, 255),
    Err      = Color3.fromRGB(220, 60,  60),
    Succ     = Color3.fromRGB(60,  200, 100),
    Border   = Color3.fromRGB(45,  45,  60),
    Scroll   = Color3.fromRGB(55,  55,  75),
    CtxBG    = Color3.fromRGB(20,  20,  28),
    CtxHov   = Color3.fromRGB(38,  38,  52),
}

-- ============================================================
-- SIZING
-- ============================================================

local WIN_W    = isMobile and 300  or 520
local WIN_H    = isMobile and 280  or 340
local LEFT_W   = isMobile and 95   or 145
local TB_H     = isMobile and 26   or 28
local BTN_W    = isMobile and 74   or 96
local BTN_H    = isMobile and 22   or 24
local FS       = isMobile and 10   or 11
local FS_MD    = isMobile and 11   or 12
local FS_LG    = isMobile and 13   or 14

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

local function Corner(r, p)
    New("UICorner", {CornerRadius = UDim.new(0, r), Parent = p})
end

local function Stroke(col, th, p)
    New("UIStroke", {Color = col, Thickness = th, Parent = p})
end

local function Pad(l, r, t, b, p)
    New("UIPadding", {
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
        Parent        = p,
    })
end

-- ============================================================
-- GUI PARENT (must resolve before building)
-- ============================================================

local GuiParent = CoreGui
if gethui then
    GuiParent = gethui()
elseif syn and syn.protect_gui then
    -- will be called later
end

-- ============================================================
-- SCREEN GUI
-- ============================================================

local Screen = New("ScreenGui", {
    Name           = "HoltSpy",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder   = 999,
    IgnoreGuiInset = true,
    Parent         = GuiParent,
})

if syn and syn.protect_gui then
    pcall(syn.protect_gui, Screen)
end

-- ============================================================
-- LOADING SCREEN (small corner, bottom-right)
-- ============================================================

local LoadFrame = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.BG,
    Size             = UDim2.new(0, 210, 0, 68),
    Position         = UDim2.new(1, -220, 1, -78),
    BorderSizePixel  = 0,
    ZIndex           = 9000,
})
Corner(8, LoadFrame)
Stroke(T.AccentL, 1, LoadFrame)

New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 7),
    Size                = UDim2.new(1, -20, 0, 20),
    Font                = Enum.Font.GothamBold,
    Text                = "Holt Spy",
    TextColor3          = T.AccentL,
    TextSize            = 16,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 9001,
})

New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 28),
    Size                = UDim2.new(1, -20, 0, 13),
    Font                = Enum.Font.Gotham,
    Text                = "by BufferClick  |  discord.gg/E7Tfjgruck",
    TextColor3          = T.TextMut,
    TextSize            = 10,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 9001,
})

local LoadBarBG = New("Frame", {
    Parent           = LoadFrame,
    BackgroundColor3 = T.SurfLL,
    Position         = UDim2.new(0, 10, 0, 50),
    Size             = UDim2.new(1, -20, 0, 4),
    BorderSizePixel  = 0,
    ZIndex           = 9001,
})
Corner(2, LoadBarBG)

local LoadFill = New("Frame", {
    Parent           = LoadBarBG,
    BackgroundColor3 = T.AccentL,
    Size             = UDim2.new(0, 0, 1, 0),
    BorderSizePixel  = 0,
    ZIndex           = 9002,
})
Corner(2, LoadFill)

local LoadStatusLbl = New("TextLabel", {
    Parent              = LoadFrame,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 44),
    Size                = UDim2.new(1, -20, 0, 10),
    Font                = Enum.Font.Gotham,
    Text                = "Starting...",
    TextColor3          = T.TextMut,
    TextSize            = 9,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 9001,
})

-- ============================================================
-- MINIMIZED ICON
-- ============================================================

local MinIcon = New("TextButton", {
    Parent              = Screen,
    BackgroundColor3    = T.Accent,
    Size                = UDim2.new(0, 44, 0, 44),
    Position            = UDim2.new(0, 10, 0.5, -22),
    BorderSizePixel     = 0,
    Font                = Enum.Font.GothamBold,
    Text                = "HS",
    TextColor3          = T.Text,
    TextSize            = 13,
    AutoButtonColor     = false,
    ZIndex              = 500,
    Visible             = false,
})
Corner(22, MinIcon)
Stroke(T.AccentL, 1.5, MinIcon)

-- ============================================================
-- MAIN WINDOW  (centered)
-- ============================================================

local Background = New("Frame", {
    Parent              = Screen,
    Name                = "Background",
    BackgroundColor3    = T.BG,
    BorderSizePixel     = 0,
    AnchorPoint         = Vector2.new(0.5, 0.5),
    Position            = UDim2.new(0.5, 0, 0.5, 0),
    Size                = UDim2.new(0, WIN_W, 0, WIN_H),
    ClipsDescendants    = false,
    ZIndex              = 10,
})
Corner(8, Background)
Stroke(T.Border, 1, Background)

-- Shadow
local Shadow = New("ImageLabel", {
    Parent              = Background,
    BackgroundTransparency = 1,
    AnchorPoint         = Vector2.new(0.5, 0.5),
    Position            = UDim2.new(0.5, 0, 0.5, 0),
    Size                = UDim2.new(1, 40, 1, 40),
    ZIndex              = 9,
    Image               = "rbxassetid://6015897843",
    ImageColor3         = Color3.new(0,0,0),
    ImageTransparency   = 0.5,
    ScaleType           = Enum.ScaleType.Slice,
    SliceCenter         = Rect.new(49, 49, 450, 450),
})

-- TopBar
local TopBar = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0, 0),
    Size             = UDim2.new(1, 0, 0, TB_H),
    ZIndex           = 20,
    ClipsDescendants = true,
})
Corner(8, TopBar)
-- Fill bottom corners of topbar
New("Frame", {
    Parent           = TopBar,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -6),
    Size             = UDim2.new(1, 0, 0, 6),
    ZIndex           = 21,
})

local TitleBtn = New("TextButton", {
    Parent              = TopBar,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 0),
    Size                = UDim2.new(0, 85, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Holt Spy",
    TextColor3          = T.AccentL,
    TextSize            = FS_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    AutoButtonColor     = false,
    ZIndex              = 22,
})

local function WinBtn(icon, xOff, hCol)
    local b = New("TextButton", {
        Parent              = TopBar,
        BackgroundTransparency = 1,
        AnchorPoint         = Vector2.new(1, 0),
        Position            = UDim2.new(1, xOff, 0, 0),
        Size                = UDim2.new(0, TB_H + 2, 1, 0),
        Font                = Enum.Font.GothamBold,
        Text                = icon,
        TextColor3          = T.TextDim,
        TextSize            = FS_MD,
        AutoButtonColor     = false,
        ZIndex              = 22,
    })
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = hCol or T.Text}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {TextColor3 = T.TextDim}):Play()
    end)
    return b
end

local CloseBtn    = WinBtn("X",  0,            T.Err)
local SideBtn     = WinBtn("+",  -(TB_H+2),    T.AccentL)
local MinBtn      = WinBtn("-",  -(TB_H+2)*2,  T.TextDim)

-- Left Panel
local LeftPanel = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.Surface,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0, TB_H),
    Size             = UDim2.new(0, LEFT_W, 1, -TB_H),
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
    BackgroundColor3    = T.SurfLL,
    BorderSizePixel     = 0,
    Position            = UDim2.new(0, 4, 0, 4),
    Size                = UDim2.new(1, -8, 0, isMobile and 20 or 22),
    Font                = Enum.Font.Gotham,
    PlaceholderText     = "Search...",
    PlaceholderColor3   = T.TextMut,
    Text                = "",
    TextColor3          = T.Text,
    TextSize            = FS,
    ClearTextOnFocus    = false,
    ZIndex              = 12,
})
Corner(4, SearchBar)
Pad(5, 5, 0, 0, SearchBar)

local LogList = New("ScrollingFrame", {
    Parent                = LeftPanel,
    BackgroundTransparency = 1,
    BorderSizePixel       = 0,
    Position              = UDim2.new(0, 2, 0, (isMobile and 28 or 30)),
    Size                  = UDim2.new(1, -4, 1, -(isMobile and 28 or 30)),
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness    = 2,
    ScrollBarImageColor3  = T.Scroll,
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    ZIndex                = 12,
})
New("UIListLayout", {
    Parent              = LogList,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder           = Enum.SortOrder.LayoutOrder,
    Padding             = UDim.new(0, 2),
})

-- Right Panel
local RightPanel = New("Frame", {
    Parent           = Background,
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, LEFT_W, 0, TB_H),
    Size             = UDim2.new(1, -LEFT_W, 1, -TB_H),
    ClipsDescendants = true,
    ZIndex           = 10,
    Visible          = false,
})

-- Code area (top 58%)
local CodeFrame = New("Frame", {
    Parent           = RightPanel,
    BackgroundColor3 = T.Surface,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0, 0),
    Size             = UDim2.new(1, 0, 0.58, 0),
    ClipsDescendants = true,
    ZIndex           = 11,
})

-- Divider
New("Frame", {
    Parent           = RightPanel,
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 0.58, 0),
    Size             = UDim2.new(1, 0, 0, 1),
    ZIndex           = 12,
})

-- Button scroll (bottom 42%)
local BtnScroll = New("ScrollingFrame", {
    Parent               = RightPanel,
    BackgroundTransparency = 1,
    BorderSizePixel      = 0,
    Position             = UDim2.new(0, 3, 0.58, 3),
    Size                 = UDim2.new(1, -6, 0.42, -6),
    CanvasSize           = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness   = 2,
    ScrollBarImageColor3 = T.Scroll,
    AutomaticCanvasSize  = Enum.AutomaticSize.Y,
    ZIndex               = 12,
})
New("UIGridLayout", {
    Parent              = BtnScroll,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder           = Enum.SortOrder.LayoutOrder,
    CellPadding         = UDim2.new(0, 3, 0, 3),
    CellSize            = UDim2.new(0, BTN_W, 0, BTN_H),
    FillDirection       = Enum.FillDirection.Horizontal,
})
Pad(2, 2, 2, 2, BtnScroll)

-- Tooltip
local ToolTip = New("Frame", {
    Parent              = Screen,
    BackgroundColor3    = T.CtxBG,
    BorderSizePixel     = 0,
    Size                = UDim2.new(0, 180, 0, 30),
    ZIndex              = 800,
    Visible             = false,
})
Corner(4, ToolTip)
Stroke(T.Border, 1, ToolTip)
local ToolTipLbl = New("TextLabel", {
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

-- Context menu
local CtxMenu = New("Frame", {
    Parent           = Screen,
    BackgroundColor3 = T.CtxBG,
    BorderSizePixel  = 0,
    Size             = UDim2.new(0, isMobile and 165 or 195, 0, 10),
    Visible          = false,
    ZIndex           = 600,
    ClipsDescendants = true,
})
Corner(6, CtxMenu)
Stroke(T.Border, 1, CtxMenu)

local CtxInner = New("ScrollingFrame", {
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
New("UIListLayout", {
    Parent    = CtxInner,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 1),
})
Pad(0, 0, 3, 3, CtxInner)

-- Edit panel
local EditPanel = New("Frame", {
    Parent              = Screen,
    BackgroundColor3    = T.BG,
    BorderSizePixel     = 0,
    AnchorPoint         = Vector2.new(0.5, 0.5),
    Position            = UDim2.new(0.5, 0, 0.5, 0),
    Size                = UDim2.new(0, isMobile and 285 or 420, 0, isMobile and 240 or 300),
    Visible             = false,
    ZIndex              = 700,
})
Corner(8, EditPanel)
Stroke(T.Border, 1, EditPanel)

local EditTB = New("Frame", {
    Parent           = EditPanel,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, 28),
    ZIndex           = 701,
    ClipsDescendants = true,
})
Corner(8, EditTB)
New("Frame", {
    Parent           = EditTB,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -6),
    Size             = UDim2.new(1, 0, 0, 6),
    ZIndex           = 702,
})
New("TextLabel", {
    Parent              = EditTB,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 0),
    Size                = UDim2.new(0.8, 0, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Edit Code",
    TextColor3          = T.AccentL,
    TextSize            = FS_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 702,
})
local EditCloseBtn = New("TextButton", {
    Parent              = EditTB,
    BackgroundTransparency = 1,
    AnchorPoint         = Vector2.new(1, 0),
    Position            = UDim2.new(1, 0, 0, 0),
    Size                = UDim2.new(0, 28, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "X",
    TextColor3          = T.TextDim,
    TextSize            = FS_MD,
    AutoButtonColor     = false,
    ZIndex              = 702,
})

local EditInput = New("TextBox", {
    Parent              = EditPanel,
    BackgroundColor3    = T.Surface,
    BorderSizePixel     = 0,
    Position            = UDim2.new(0, 6, 0, 34),
    Size                = UDim2.new(1, -12, 1, -72),
    Font                = Enum.Font.Code,
    Text                = "",
    TextColor3          = T.Text,
    TextSize            = FS,
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
    Size                = UDim2.new(0, 120, 0, 26),
    Font                = Enum.Font.GothamBold,
    Text                = "Save to Modified",
    TextColor3          = T.Text,
    TextSize            = FS,
    AutoButtonColor     = false,
    ZIndex              = 702,
})
Corner(4, EditSaveBtn)

-- Modified panel
local ModPanel = New("Frame", {
    Parent              = Screen,
    BackgroundColor3    = T.BG,
    BorderSizePixel     = 0,
    AnchorPoint         = Vector2.new(0.5, 0.5),
    Position            = UDim2.new(0.5, 0, 0.5, 0),
    Size                = UDim2.new(0, isMobile and 285 or 420, 0, isMobile and 240 or 300),
    Visible             = false,
    ZIndex              = 700,
})
Corner(8, ModPanel)
Stroke(T.Border, 1, ModPanel)

local ModTB = New("Frame", {
    Parent           = ModPanel,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, 28),
    ZIndex           = 701,
    ClipsDescendants = true,
})
Corner(8, ModTB)
New("Frame", {
    Parent           = ModTB,
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0, 0, 1, -6),
    Size             = UDim2.new(1, 0, 0, 6),
    ZIndex           = 702,
})
New("TextLabel", {
    Parent              = ModTB,
    BackgroundTransparency = 1,
    Position            = UDim2.new(0, 10, 0, 0),
    Size                = UDim2.new(0.8, 0, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "Modified Code",
    TextColor3          = T.AccentL,
    TextSize            = FS_LG,
    TextXAlignment      = Enum.TextXAlignment.Left,
    ZIndex              = 702,
})
local ModCloseBtn = New("TextButton", {
    Parent              = ModTB,
    BackgroundTransparency = 1,
    AnchorPoint         = Vector2.new(1, 0),
    Position            = UDim2.new(1, 0, 0, 0),
    Size                = UDim2.new(0, 28, 1, 0),
    Font                = Enum.Font.GothamBold,
    Text                = "X",
    TextColor3          = T.TextDim,
    TextSize            = FS_MD,
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
New("UIListLayout", {
    Parent    = ModList,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 3),
})

-- Overlay
local Overlay = New("TextButton", {
    Parent              = Screen,
    BackgroundColor3    = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    Size                = UDim2.new(1, 0, 1, 0),
    Text                = "",
    AutoButtonColor     = false,
    Visible             = false,
    ZIndex              = 399,
    BorderSizePixel     = 0,
})

-- ============================================================
-- STATE
-- ============================================================

local logs          = {}
local remoteLogs    = {}
local selected      = nil
local blacklist     = {}
local blocklist     = {}
local scheduled     = {}
local activeLoops   = {}
local modifiedCodes = {}
local history       = {}
local excluding     = {}
local connections   = {}
local running_threads = {}
local layoutOrder   = 999999999
local ctxVisible    = false
local sideClosed    = true
local isMinimized   = false
local spyActive     = false
local schedulerConn = nil
local codebox       = nil
local originalNamecall = nil

getgenv().HOLTSPY_MaxRemotes = 500

local Storage          = New("Folder", {Parent = game:GetService("CoreGui")})
local _re              = New("RemoteEvent",         {Parent = Storage})
local _ure             = New("UnreliableRemoteEvent")
local _rf              = New("RemoteFunction",       {Parent = Storage})
local origFireServer   = _re.FireServer
local origUnreliable   = _ure.FireServer
local origInvoke       = _rf.InvokeServer

-- ============================================================
-- LOGGING THREADS
-- ============================================================

local function logThread(t)
    table.insert(running_threads, t)
end

-- ============================================================
-- TOOLTIP
-- ============================================================

local tipConn

local function ShowTip(txt)
    if tipConn then tipConn:Disconnect() tipConn = nil end
    ToolTipLbl.Text = txt
    local sz = TextService:GetTextSize(txt, 11, Enum.Font.Gotham, Vector2.new(168, 200))
    ToolTip.Size = UDim2.new(0, sz.X + 14, 0, sz.Y + 10)
    ToolTip.Visible = true
    local first = true
    tipConn = RunService.RenderStepped:Connect(function()
        local mp = UserInputService:GetMouseLocation()
        local tp = mp + Vector2.new(14, -ToolTip.AbsoluteSize.Y - 4)
        local vp = workspace.CurrentCamera.ViewportSize
        if tp.X + ToolTip.AbsoluteSize.X > vp.X then
            tp = Vector2.new(vp.X - ToolTip.AbsoluteSize.X - 4, tp.Y)
        end
        if tp.Y < 4 then tp = Vector2.new(tp.X, mp.Y + 16) end
        if first then
            ToolTip.Position = UDim2.fromOffset(tp.X, tp.Y)
            first = false
        else
            ToolTip.Position = UDim2.fromOffset(tp.X, tp.Y)
        end
    end)
end

local function HideTip()
    if tipConn then tipConn:Disconnect() tipConn = nil end
    ToolTip.Visible = false
end

-- ============================================================
-- OVERLAY
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
-- CONTEXT MENU SYSTEM
-- ============================================================

local function HideCtx()
    ctxVisible = false
    CtxMenu.Visible = false
    for _, c in ipairs(CtxInner:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end
end

local function CtxItem(lbl, order, cb, col)
    local iH = isMobile and 26 or 23
    local btn = New("TextButton", {
        Parent              = CtxInner,
        BackgroundColor3    = T.CtxBG,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 0, iH),
        Font                = Enum.Font.Gotham,
        Text                = "   " .. lbl,
        TextColor3          = col or T.Text,
        TextSize            = FS,
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
        Parent           = CtxInner,
        BackgroundColor3 = T.Border,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, -8, 0, 1),
        LayoutOrder      = order,
        ZIndex           = 602,
    })
end

local function CtxToggle(lbl, order, initState, cb)
    local state = initState
    local btn
    local function Refresh()
        btn.Text = "   " .. lbl .. (state and "  [ON]" or "  [OFF]")
        btn.TextColor3 = state and T.Succ or T.TextDim
    end
    local iH = isMobile and 26 or 23
    btn = New("TextButton", {
        Parent              = CtxInner,
        BackgroundColor3    = T.CtxBG,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 0, iH),
        Font                = Enum.Font.Gotham,
        Text                = "",
        TextSize            = FS,
        TextXAlignment      = Enum.TextXAlignment.Left,
        AutoButtonColor     = false,
        LayoutOrder         = order,
        ZIndex              = 602,
    })
    Refresh()
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxHov}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = T.CtxBG}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        Refresh()
        if cb then cb(state) end
    end)
    return btn
end

local function PositionCtx(mp, itemCount)
    local iH  = isMobile and 26 or 23
    local tot = math.min(itemCount * (iH + 1) + 8, 280)
    local cW  = isMobile and 165 or 195
    local vp  = workspace.CurrentCamera.ViewportSize
    local px  = mp.X
    local py  = mp.Y

    if px + cW  > vp.X then px = vp.X - cW  - 4 end
    if py + tot > vp.Y then py = vp.Y - tot - 4 end
    if px < 2 then px = 2 end
    if py < 2 then py = 2 end

    CtxMenu.Position = UDim2.new(0, px, 0, py)
    CtxMenu.Size     = UDim2.new(0, cW, 0, tot)
    CtxMenu.Visible  = true
    ctxVisible       = true
end

UserInputService.InputBegan:Connect(function(inp)
    if not ctxVisible then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local mp = UserInputService:GetMouseLocation()
    local cp = CtxMenu.AbsolutePosition
    local cs = CtxMenu.AbsoluteSize
    if mp.X < cp.X or mp.X > cp.X + cs.X
    or mp.Y < cp.Y or mp.Y > cp.Y + cs.Y then
        task.defer(HideCtx)
    end
end)

-- ============================================================
-- SCRIPT GENERATION
-- ============================================================

local getnilRequired = false

local function i2p(inst)
    if not inst then return "nil" end
    getnilRequired = false

    local ok, result = pcall(function()
        -- LocalPlayer shortcut
        local lp = Players.LocalPlayer
        if lp and (inst == lp or inst:IsDescendantOf(lp)) then
            local full = inst:GetFullName()
            local lpFull = lp:GetFullName()
            local rel = full:sub(#lpFull + 2)
            return 'game:GetService("Players").LocalPlayer'
                .. (rel ~= "" and ("." .. rel) or "")
        end

        -- Walk up to find service
        local obj = inst
        while obj.Parent and obj.Parent ~= game do
            obj = obj.Parent
        end

        if obj.Parent == game then
            local svcOk, svc = pcall(function() return game:GetService(obj.ClassName) end)
            if svcOk and svc then
                local prefix
                if obj.ClassName == "Workspace" then
                    prefix = "workspace"
                else
                    prefix = 'game:GetService("' .. obj.ClassName .. '")'
                end
                local full = inst:GetFullName()
                local objFull = obj:GetFullName()
                local rel = full:sub(#objFull + 2)
                return prefix .. (rel ~= "" and ("." .. rel) or "")
            end
        end

        -- Nil instance
        if not inst.Parent then
            getnilRequired = true
            return ('getNil("' .. inst.Name .. '", "' .. inst.ClassName .. '")')
        end

        return "game." .. inst:GetFullName():sub(6)
    end)

    return ok and result or ('game:GetService("' .. (pcall(function() return inst.ClassName end) and inst.ClassName or "Unknown") .. '")')
end

local function v2s(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "nil"     then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then
        if v ~= v           then return "0/0"
        elseif v == math.huge  then return "math.huge"
        elseif v == -math.huge then return "-math.huge"
        else return tostring(v) end
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "Instance" then
        return i2p(v)
    elseif t == "Vector3" then
        return ("Vector3.new(%g, %g, %g)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return ("Vector2.new(%g, %g)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local c = {v:GetComponents()}
        local parts = {}
        for _, n in ipairs(c) do parts[#parts+1] = tostring(n) end
        return "CFrame.new(" .. table.concat(parts, ", ") .. ")"
    elseif t == "Color3" then
        return ("Color3.new(%g, %g, %g)"):format(v.R, v.G, v.B)
    elseif t == "UDim2" then
        return ("UDim2.new(%g, %g, %g, %g)"):format(
            v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then
        return ("UDim.new(%g, %g)"):format(v.Scale, v.Offset)
    elseif t == "BrickColor" then
        return ('BrickColor.new("%s")'):format(v.Name)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "TweenInfo" then
        return ("TweenInfo.new(%g, %s, %s, %g, %s, %g)"):format(
            v.Time, tostring(v.EasingStyle), tostring(v.EasingDirection),
            v.RepeatCount, tostring(v.Reverses), v.DelayTime)
    elseif t == "table" then
        if depth > 8 then return "{--[[max depth]]}" end
        local parts = {}
        for k, val in next, v do
            local ks
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                ks = k
            else
                ks = "[" .. v2s(k, depth+1) .. "]"
            end
            parts[#parts+1] = ks .. " = " .. v2s(val, depth+1)
        end
        if #parts == 0 then return "{}" end
        return "{\n    " .. table.concat(parts, ",\n    ") .. "\n}"
    else
        return tostring(v)
    end
end

local function genScript(remote, args)
    getnilRequired = false
    local remotePath = i2p(remote)
    local prefix = ""

    -- args string
    local argsStr = ""
    if args and #args > 0 then
        -- try LazyFix first, fall back to v2s
        local ok, res = false, nil
        if LazyFix then
            ok, res = pcall(LazyFix.Convert, args, true)
        end
        if ok and res then
            argsStr = "local args = " .. res .. "\n"
        else
            local parts = {}
            for _, a in ipairs(args) do
                parts[#parts+1] = v2s(a)
            end
            argsStr = "local args = {" .. table.concat(parts, ", ") .. "}\n"
        end
    end

    if getnilRequired then
        prefix = "local function getNil(name, class)\n"
            .. "    for _, v in next, getnilinstances() do\n"
            .. "        if v.ClassName == class and v.Name == name then return v end\n"
            .. "    end\nend\n\n"
    end

    local callStr
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        callStr = args and #args > 0
            and (remotePath .. ":FireServer(table.unpack(args))")
            or  (remotePath .. ":FireServer()")
    elseif remote:IsA("RemoteFunction") then
        callStr = args and #args > 0
            and ("local result = " .. remotePath .. ":InvokeServer(table.unpack(args))\nprint(result)")
            or  ("local result = " .. remotePath .. ":InvokeServer()\nprint(result)")
    else
        callStr = "-- Unknown remote type"
    end

    return prefix .. argsStr .. callStr
end

-- ============================================================
-- REMOTE LOG ENTRY
-- ============================================================

local function SelectLog(log)
    for _, l in ipairs(logs) do
        if l.Button then
            l.Button.BackgroundTransparency = 0.85
        end
    end
    selected = log
    if log and log.Button then
        log.Button.BackgroundTransparency = 0.35
    end
    if log then
        if sideClosed then
            -- Open side panel
            sideClosed = false
            RightPanel.Visible = true
            TweenService:Create(LeftPanel, TweenInfo.new(0.2), {
                Size = UDim2.new(0, LEFT_W, 1, -TB_H)
            }):Play()
            TweenService:Create(RightPanel, TweenInfo.new(0.2), {
                Size = UDim2.new(1, -LEFT_W, 1, -TB_H)
            }):Play()
        end
        if codebox then
            codebox:setRaw(log.GenScript or "-- Generating...")
        end
    end
end

local function ShowCtxForLog(log)
    if not log or not log.Remote then return end
    HideCtx()

    local remote = log.Remote
    local remId  = log.DebugId
    local o = 0
    local function no() o = o + 1; return o end

    CtxItem("Copy Code", no(), function()
        if log.GenScript then setclipboard(log.GenScript) end
    end)
    CtxItem("Run Code", no(), function()
        if not remote then return end
        xpcall(function()
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                remote:FireServer(table.unpack(log.args or {}))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(table.unpack(log.args or {}))
            end
        end, function(e) warn("[HoltSpy] " .. e) end)
    end)
    CtxSep(no())
    CtxItem("Copy Looped Code", no(), function()
        if not log.GenScript then return end
        local lc = "while task.wait(0.1) do\n    "
            .. log.GenScript:gsub("\n", "\n    ") .. "\nend"
        setclipboard(lc)
    end)
    CtxItem("Run Looped Code", no(), function()
        if not remote then return end
        local lid = tostring(remId or remote) .. "_l" .. tostring(tick()):sub(-4)
        activeLoops[lid] = true
        logThread(task.spawn(function()
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
        local tc = "_G._holtLoop"..tostring(remId):sub(-4).." = not _G._holtLoop"..tostring(remId):sub(-4)
            .. "\nif _G._holtLoop"..tostring(remId):sub(-4).." then\n"
            .. "    task.spawn(function()\n"
            .. "        while _G._holtLoop"..tostring(remId):sub(-4).." do\n"
            .. "            task.wait(0.1)\n            "
            .. inner .. "\n        end\n    end)\nend"
        setclipboard(tc)
    end)
    local lk = tostring(remId or remote) .. "_tog"
    CtxToggle("Toggle Loop", no(), activeLoops[lk] and true or false, function(state)
        if state then
            activeLoops[lk] = true
            logThread(task.spawn(function()
                while activeLoops[lk] do
                    xpcall(function()
                        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                            remote:FireServer(table.unpack(log.args or {}))
                        elseif remote:IsA("RemoteFunction") then
                            remote:InvokeServer(table.unpack(log.args or {}))
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
        local function closeEdit()
            HideOverlay()
            EditPanel.Visible = false
            if sc then sc:Disconnect() end
            if cc then cc:Disconnect() end
            if oc then oc:Disconnect() end
        end
        sc = EditSaveBtn.MouseButton1Click:Connect(function()
            table.insert(modifiedCodes, {
                Name = log.Name or "Unknown",
                Code = EditInput.Text,
                Time = os.date("%H:%M:%S"),
            })
            closeEdit()
        end)
        cc = EditCloseBtn.MouseButton1Click:Connect(closeEdit)
        oc = Overlay.MouseButton1Click:Connect(closeEdit)
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
        if log.Remote then
            pcall(function() setclipboard(log.Remote:GetFullName()) end)
        end
    end)

    local mp = UserInputService:GetMouseLocation()
    PositionCtx(mp, o)
end

local function AddRemoteLog(remoteType, data)
    if layoutOrder < 1 then layoutOrder = 999999999 end
    local remote = data.remote
    if not remote then return end

    local frame = New("Frame", {
        LayoutOrder         = layoutOrder,
        Name                = "RemoteLog",
        Parent              = LogList,
        BackgroundTransparency = 1,
        Size                = UDim2.new(1, -2, 0, isMobile and 24 or 22),
    })

    -- Color tag
    New("Frame", {
        Parent           = frame,
        BackgroundColor3 = remoteType == "event" and T.EvCol or T.FnCol,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0.15, 0),
        Size             = UDim2.new(0, 2, 0.7, 0),
        ZIndex           = 13,
    })

    New("TextLabel", {
        Parent              = frame,
        BackgroundTransparency = 1,
        Position            = UDim2.new(0, 6, 0, 0),
        Size                = UDim2.new(1, -8, 1, 0),
        Font                = Enum.Font.Gotham,
        Text                = remote.Name,
        TextColor3          = T.Text,
        TextSize            = FS,
        TextXAlignment      = Enum.TextXAlignment.Left,
        TextTruncate        = Enum.TextTruncate.AtEnd,
        ZIndex              = 13,
    })

    local btn = New("TextButton", {
        Name                = "Button",
        Parent              = frame,
        BackgroundColor3    = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.85,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 1, 0),
        AutoButtonColor     = false,
        Text                = "",
        ZIndex              = 14,
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

    -- generate script async
    logThread(task.spawn(function()
        local ok, result = pcall(genScript, remote, log.args)
        log.GenScript = ok and result or ("-- Generation error: " .. tostring(result))
        if log.Blocked then
            log.GenScript = "-- REMOTE BLOCKED FROM FIRING\n\n" .. log.GenScript
        end
        if selected == log and codebox then
            codebox:setRaw(log.GenScript)
        end
    end))

    -- Left click
    btn.MouseButton1Click:Connect(function()
        SelectLog(log)
        if codebox and log.GenScript then
            codebox:setRaw(log.GenScript)
        end
    end)

    -- Right click
    btn.MouseButton2Click:Connect(function()
        selected = log
        ShowCtxForLog(log)
    end)

    -- Mobile long press
    if isMobile then
        local pt = 0
        btn.MouseButton1Down:Connect(function() pt = tick() end)
        btn.MouseButton1Up:Connect(function()
            if tick() - pt >= 0.5 then
                selected = log
                ShowCtxForLog(log)
            end
        end)
    end

    table.insert(logs, log)
    layoutOrder = layoutOrder - 1

    -- Max logs cleanup
    local max = getgenv().HOLTSPY_MaxRemotes or 500
    table.insert(remoteLogs, 1, frame)
    if #remoteLogs > max then
        for i = max + 1, #remoteLogs do
            if remoteLogs[i] and remoteLogs[i].Parent then
                remoteLogs[i]:Destroy()
            end
        end
        while #remoteLogs > max do
            table.remove(remoteLogs)
        end
        while #logs > max do
            table.remove(logs)
        end
    end
end

-- ============================================================
-- SEARCH
-- ============================================================

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchBar.Text:lower()
    for _, c in ipairs(LogList:GetChildren()) do
        if c:IsA("Frame") and c.Name == "RemoteLog" then
            local lbl = c:FindFirstChildWhichIsA("TextLabel")
            if lbl then
                c.Visible = q == "" or (lbl.Text:lower():find(q, 1, true) ~= nil)
            end
        end
    end
end)

-- ============================================================
-- MODIFIED CODE
-- ============================================================

local function RefreshModPanel()
    for _, c in ipairs(ModList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for i, entry in ipairs(modifiedCodes) do
        local row = New("TextButton", {
            Parent              = ModList,
            BackgroundColor3    = T.SurfL,
            BorderSizePixel     = 0,
            Size                = UDim2.new(1, -2, 0, isMobile and 28 or 24),
            Font                = Enum.Font.Gotham,
            Text                = "  [" .. entry.Time .. "]  " .. entry.Name,
            TextColor3          = T.Text,
            TextSize            = FS,
            TextXAlignment      = Enum.TextXAlignment.Left,
            TextTruncate        = Enum.TextTruncate.AtEnd,
            AutoButtonColor     = false,
            LayoutOrder         = i,
            ZIndex              = 703,
        })
        Corner(4, row)
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfLL}):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = T.SurfL}):Play()
        end)
        row.MouseButton1Click:Connect(function()
            local mp = UserInputService:GetMouseLocation()
            HideCtx()
            local o = 0
            local function no() o = o + 1; return o end
            CtxItem("Copy Code", no(), function() setclipboard(entry.Code) end)
            CtxItem("Run Code", no(), function()
                local fn, err = loadstring(entry.Code)
                if fn then xpcall(fn, function(e) warn("[HoltSpy] " .. e) end)
                else warn("[HoltSpy] Parse error: " .. tostring(err)) end
            end)
            CtxSep(no())
            CtxItem("Copy Looped Code", no(), function()
                local lc = "while task.wait(0.1) do\n    "
                    .. entry.Code:gsub("\n", "\n    ") .. "\nend"
                setclipboard(lc)
            end)
            CtxItem("Run Looped Code", no(), function()
                local lid = "mod_" .. tostring(i) .. "_" .. tostring(tick()):sub(-4)
                activeLoops[lid] = true
                logThread(task.spawn(function()
                    while activeLoops[lid] do
                        local fn = loadstring(entry.Code)
                        if fn then xpcall(fn, function() end) end
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
                local tc = "_G._holtModLoop = not _G._holtModLoop\n"
                    .. "if _G._holtModLoop then\n"
                    .. "    task.spawn(function()\n"
                    .. "        while _G._holtModLoop do\n"
                    .. "            task.wait(0.1)\n            "
                    .. entry.Code:gsub("\n", "\n            ")
                    .. "\n        end\n    end)\nend"
                setclipboard(tc)
            end)
            local lk = "mod_tog_" .. tostring(entry)
            CtxToggle("Toggle Loop", no(), activeLoops[lk] and true or false, function(state)
                if state then
                    activeLoops[lk] = true
                    logThread(task.spawn(function()
                        while activeLoops[lk] do
                            local fn = loadstring(entry.Code)
                            if fn then xpcall(fn, function() end) end
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
                local function closeEdit()
                    HideOverlay(); EditPanel.Visible = false
                    if sc then sc:Disconnect() end
                    if cc then cc:Disconnect() end
                    if oc then oc:Disconnect() end
                end
                sc = EditSaveBtn.MouseButton1Click:Connect(function()
                    entry.Code = EditInput.Text
                    closeEdit()
                    RefreshModPanel()
                end)
                cc = EditCloseBtn.MouseButton1Click:Connect(closeEdit)
                oc = Overlay.MouseButton1Click:Connect(closeEdit)
            end)
            CtxItem("Delete", no(), function()
                for idx, e in ipairs(modifiedCodes) do
                    if e == entry then table.remove(modifiedCodes, idx); break end
                end
                RefreshModPanel()
            end, T.Err)
            PositionCtx(mp, o)
        end)
    end
end

ModCloseBtn.MouseButton1Click:Connect(function()
    ModPanel.Visible = false
    HideOverlay()
end)
Overlay.MouseButton1Click:Connect(function()
    if EditPanel.Visible then
        EditPanel.Visible = false
    end
    if ModPanel.Visible then
        ModPanel.Visible = false
    end
    HideOverlay()
end)

-- ============================================================
-- BOTTOM BUTTONS
-- ============================================================

local function NewBtn(name, tip, fn)
    local f = New("Frame", {
        Parent              = BtnScroll,
        BackgroundTransparency = 1,
        Size                = UDim2.new(0, BTN_W, 0, BTN_H),
    })
    local b = New("TextButton", {
        Parent              = f,
        BackgroundColor3    = T.SurfLL,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 1, 0),
        Font                = Enum.Font.Gotham,
        Text                = name,
        TextColor3          = T.Text,
        TextSize            = FS,
        AutoButtonColor     = false,
        TextTruncate        = Enum.TextTruncate.AtEnd,
        ZIndex              = 13,
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
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.SurfL}):Play()
        ShowTip(tip)
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = T.SurfLL}):Play()
        HideTip()
    end)
    b.MouseButton1Click:Connect(function()
        logThread(coroutine.running())
        fn()
    end)
end

NewBtn("Copy Code",   "Copy generated code for the selected remote", function()
    if selected and selected.GenScript then setclipboard(selected.GenScript) end
end)
NewBtn("Run Code",    "Execute selected remote once", function()
    if not selected or not selected.Remote then return end
    xpcall(function()
        local r = selected.Remote
        if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
            r:FireServer(table.unpack(selected.args or {}))
        elseif r:IsA("RemoteFunction") then
            r:InvokeServer(table.unpack(selected.args or {}))
        end
    end, function(e) warn("[HoltSpy] " .. e) end)
end)
NewBtn("Edit Code",   "Open code editor for the selected remote", function()
    if not selected then return end
    EditInput.Text = selected.GenScript or ""
    EditPanel.Visible = true
    ShowOverlay()
    local sc, cc, oc
    local function closeEdit()
        HideOverlay(); EditPanel.Visible = false
        if sc then sc:Disconnect() end
        if cc then cc:Disconnect() end
        if oc then oc:Disconnect() end
    end
    sc = EditSaveBtn.MouseButton1Click:Connect(function()
        table.insert(modifiedCodes, {
            Name = selected.Name or "Unknown",
            Code = EditInput.Text,
            Time = os.date("%H:%M:%S"),
        })
        closeEdit()
    end)
    cc = EditCloseBtn.MouseButton1Click:Connect(closeEdit)
    oc = Overlay.MouseButton1Click:Connect(closeEdit)
end)
NewBtn("Modified",    "View saved modified scripts", function()
    RefreshModPanel()
    ModPanel.Visible = true
    ShowOverlay()
end)
NewBtn("Copy Loop",   "Copy looped version of selected remote code", function()
    if selected and selected.GenScript then
        local lc = "while task.wait(0.1) do\n    "
            .. selected.GenScript:gsub("\n", "\n    ") .. "\nend"
        setclipboard(lc)
    end
end)
NewBtn("Run Loop",    "Run selected remote in a loop", function()
    if not selected or not selected.Remote then return end
    local lid = tostring(selected.DebugId or selected.Remote) .. "_rl"
    activeLoops[lid] = true
    logThread(task.spawn(function()
        local r = selected.Remote
        local a = selected.args or {}
        while activeLoops[lid] do
            xpcall(function()
                if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
                    r:FireServer(table.unpack(a))
                elseif r:IsA("RemoteFunction") then
                    r:InvokeServer(table.unpack(a))
                end
            end, function() end)
            task.wait(0.1)
        end
    end))
end)
NewBtn("Stop Loops",  "Stop all active loops", function()
    for k in pairs(activeLoops) do activeLoops[k] = false end
    table.clear(activeLoops)
end)
NewBtn("Clr Logs",    "Clear all remote logs", function()
    for _, l in ipairs(logs) do
        if l.Log and l.Log.Parent then l.Log:Destroy() end
    end
    table.clear(logs)
    table.clear(remoteLogs)
    selected = nil
    if codebox then codebox:setRaw("") end
end)
NewBtn("Exclude",     "Exclude selected remote by instance ID", function()
    if selected and selected.DebugId then blacklist[selected.DebugId] = true end
end)
NewBtn("Block",       "Block selected remote from firing server", function()
    if selected and selected.DebugId then blocklist[selected.DebugId] = true end
end)
NewBtn("Clr Lists",   "Clear blacklist and blocklist", function()
    table.clear(blacklist)
    table.clear(blocklist)
    table.clear(excluding)
    table.clear(history)
end)
NewBtn("Autoblock",   "Toggle auto-blocking of spammy remotes", function()
    realAutoblock = not realAutoblock
    table.clear(history)
    table.clear(excluding)
end)
NewBtn("Log Caller",  "Toggle logging remotes called by client scripts", function()
    realLogCaller = not realLogCaller
end)
NewBtn("Discord",     "Copy Discord invite and attempt to open it", function()
    setclipboard("https://discord.gg/E7Tfjgruck")
    pcall(function()
        local req = request or (syn and syn.request)
        if req then
            req({
                Url    = "http://127.0.0.1:6463/rpc?v=1",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json", Origin = "https://discord.com"},
                Body   = HttpService:JSONEncode({
                    cmd   = "INVITE_BROWSER",
                    nonce = HttpService:GenerateGUID(false),
                    args  = {code = "E7Tfjgruck"},
                }),
            })
        end
    end)
end)

-- ============================================================
-- CONFIG SHORTCUTS (direct vars for the hooks to read fast)
-- ============================================================

local realAutoblock = false
local realLogCaller = false

-- ============================================================
-- REMOTE HANDLER
-- ============================================================

local function remoteHandler(data)
    if not data or not data.remote then return end
    local id = data.id or ""

    if blacklist[id] or blacklist[data.remote.Name] then return end

    if realAutoblock then
        if excluding[id] then return end
        if not history[id] then history[id] = {count = 0, last = tick()} end
        local h = history[id]
        if tick() - h.last < 0.5 then
            h.count = h.count + 1
            if h.count > 20 then excluding[id] = true; return end
        else
            h.count = 0
            h.last  = tick()
        end
    end

    if blocklist[id] or blocklist[data.remote.Name] then
        data.blockcheck = true
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
    if type(fn) == "function" then
        local ok, err = pcall(fn)
        if not ok then warn("[HoltSpy Sched] " .. tostring(err)) end
    end
end

-- ============================================================
-- HOOKS
-- ============================================================

-- Build namecall hook
local namecallHook = newcclosure(function(...)
    local method = getnamecallmethod()
    if method == "FireServer"  or method == "fireServer"
    or method == "InvokeServer" or method == "invokeServer" then
        local self = select(1, ...)
        if typeof(self) == "Instance" and (
            self:IsA("RemoteEvent") or
            self:IsA("RemoteFunction") or
            self:IsA("UnreliableRemoteEvent")
        ) then
            if not realLogCaller and checkcaller() then
                return originalNamecall(...)
            end

            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)

            if blocklist[safeId] or blocklist[self.Name] then
                return  -- blocked: don't fire, don't log
            end

            if not blacklist[safeId] and not blacklist[self.Name] then
                local allArgs = {...}
                local passedArgs = {}
                for i = 2, #allArgs do passedArgs[i-1] = allArgs[i] end

                local okC, copied = pcall(deepclone, passedArgs)
                local cs; pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end

                schedule(remoteHandler, {
                    method        = method,
                    remote        = self,
                    args          = okC and copied or passedArgs,
                    id            = safeId,
                    callingscript = cs,
                    blockcheck    = false,
                })
            end
        end
    end
    return originalNamecall(...)
end)

local function enableHooks()
    -- Hook __namecall via hookmetamethod (preferred) or manual
    if hookmetamethod then
        local old = hookmetamethod(game, "__namecall", namecallHook)
        originalNamecall = old
    else
        -- Manual approach
        local mt     = getrawmetatable(game)
        local wasRO  = isreadonly(mt)
        if wasRO then makewritable(mt) end
        local old        = mt.__namecall
        mt.__namecall    = namecallHook
        if wasRO then makereadonly2(mt) end
        originalNamecall = old
    end

    -- Direct FireServer hooks (belt-and-suspenders)
    if hookfunction then
        -- RemoteEvent.FireServer
        local reHook = newcclosure(function(self, ...)
            if typeof(self) ~= "Instance" then return origFireServer(self, ...) end
            if not (self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")) then
                return origFireServer(self, ...)
            end
            if not realLogCaller and checkcaller() then return origFireServer(self, ...) end
            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)
            if blocklist[safeId] or blocklist[self.Name] then return end
            if not blacklist[safeId] and not blacklist[self.Name] then
                local a = {...}
                local okC, copied = pcall(deepclone, a)
                local cs; pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end
                schedule(remoteHandler, {
                    method = "FireServer", remote = self,
                    args = okC and copied or a, id = safeId,
                    callingscript = cs, blockcheck = false,
                })
            end
            return origFireServer(self, ...)
        end)
        hookfunction(origFireServer, reHook)

        -- RemoteFunction.InvokeServer
        local rfHook = newcclosure(function(self, ...)
            if typeof(self) ~= "Instance" or not self:IsA("RemoteFunction") then
                return origInvoke(self, ...)
            end
            if not realLogCaller and checkcaller() then return origInvoke(self, ...) end
            local ok, id = pcall(SafeDebugId, self)
            local safeId = ok and id or tostring(self)
            if blocklist[safeId] or blocklist[self.Name] then return origInvoke(self, ...) end
            if not blacklist[safeId] and not blacklist[self.Name] then
                local a = {...}
                local okC, copied = pcall(deepclone, a)
                local cs; pcall(function() cs = getcallingscript() end)
                if cs then pcall(function() cs = cloneref(cs) end) end
                schedule(remoteHandler, {
                    method = "InvokeServer", remote = self,
                    args = okC and copied or a, id = safeId,
                    callingscript = cs, blockcheck = false,
                })
            end
            return origInvoke(self, ...)
        end)
        hookfunction(origInvoke, rfHook)
    end

    spyActive = true
    TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.Succ}):Play()
end

local function disableHooks()
    if originalNamecall then
        if hookmetamethod then
            pcall(hookmetamethod, game, "__namecall", originalNamecall)
        else
            local mt = getrawmetatable(game)
            local wasRO = isreadonly(mt)
            if wasRO then makewritable(mt) end
            mt.__namecall = originalNamecall
            if wasRO then makereadonly2(mt) end
        end
    end
    if hookfunction then
        pcall(hookfunction, origFireServer, origFireServer)
        pcall(hookfunction, origInvoke,     origInvoke)
    end
    spyActive = false
    TweenService:Create(TitleBtn, TweenInfo.new(0.3), {TextColor3 = T.AccentL}):Play()
end

-- ============================================================
-- WINDOW CONTROLS
-- ============================================================

-- Dragging
do
    local dragging = false
    local dragStart, startPos

    TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        -- Don't drag if clicking buttons on the right
        local mp = UserInputService:GetMouseLocation()
        local tbAbs = TopBar.AbsolutePosition
        local tbSize = TopBar.AbsoluteSize
        if mp.X > tbAbs.X + tbSize.X - (TB_H + 2) * 3 then return end
        dragging  = true
        dragStart = mp
        startPos  = Background.Position
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = UserInputService:GetMouseLocation() - dragStart
        local vp    = workspace.CurrentCamera.ViewportSize
        local newX  = startPos.X.Offset + delta.X
        local newY  = startPos.Y.Offset + delta.Y
        -- Clamp: keep at least 60px of window visible
        newX = math.clamp(newX, -(WIN_W - 60), vp.X - 60)
        newY = math.clamp(newY, 0,             vp.Y - TB_H)
        Background.Position = UDim2.new(0, newX, 0, newY)
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Minimize
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(Background, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, WIN_W, 0, TB_H)
        }):Play()
        LeftPanel.Visible  = false
        RightPanel.Visible = false
        task.delay(0.28, function()
            Background.Visible = false
            MinIcon.Visible    = true
        end)
    else
        MinIcon.Visible    = false
        Background.Visible = true
        LeftPanel.Visible  = true
        RightPanel.Visible = not sideClosed
        TweenService:Create(Background, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, WIN_W, 0, WIN_H)
        }):Play()
    end
end)

MinIcon.MouseButton1Click:Connect(function()
    isMinimized = false
    MinIcon.Visible    = false
    Background.Visible = true
    LeftPanel.Visible  = true
    RightPanel.Visible = not sideClosed
    TweenService:Create(Background, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
end)

-- Side panel toggle
SideBtn.MouseButton1Click:Connect(function()
    sideClosed = not sideClosed
    if sideClosed then
        TweenService:Create(RightPanel, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 0, 1, -TB_H)
        }):Play()
        TweenService:Create(LeftPanel, TweenInfo.new(0.2), {
            Size = UDim2.new(1, 0, 1, -TB_H)
        }):Play()
        task.delay(0.22, function() RightPanel.Visible = false end)
    else
        RightPanel.Visible = true
        TweenService:Create(LeftPanel, TweenInfo.new(0.2), {
            Size = UDim2.new(0, LEFT_W, 1, -TB_H)
        }):Play()
        TweenService:Create(RightPanel, TweenInfo.new(0.2), {
            Size = UDim2.new(1, -LEFT_W, 1, -TB_H)
        }):Play()
    end
end)

-- Title btn: toggle spy
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

-- Close
CloseBtn.MouseButton1Click:Connect(function()
    if getgenv().HoltSpyShutdown then
        getgenv().HoltSpyShutdown()
    end
end)

-- MinIcon hover
MinIcon.MouseEnter:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.15), {BackgroundColor3 = T.AccentL}):Play()
end)
MinIcon.MouseLeave:Connect(function()
    TweenService:Create(MinIcon, TweenInfo.new(0.15), {BackgroundColor3 = T.Accent}):Play()
end)

-- ============================================================
-- SHUTDOWN
-- ============================================================

local function Shutdown()
    if schedulerConn then
        schedulerConn:Disconnect()
        schedulerConn = nil
    end
    for _, c in pairs(connections) do
        if typeof(c) == "RBXScriptConnection" then pcall(c.Disconnect, c) end
    end
    for _, t in ipairs(running_threads) do
        if type(t) == "thread" and coroutine.status(t) ~= "dead" then
            pcall(coroutine.close, t)
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
-- INIT
-- ============================================================

local function Init()
    if not RunService:IsClient() then
        warn("[HoltSpy] Must be run on the client!")
        return
    end

    getgenv().HoltSpyExecuted = true
    getgenv().HoltSpyShutdown = Shutdown

    -- Init codebox
    if Highlight then
        local ok, cb = pcall(Highlight.new, Highlight, CodeFrame)
        if ok and cb then
            codebox = cb
            codebox:setRaw(
                "-- Holt Spy ready\n"
             .. "-- Click any remote in the left panel to view its code\n"
             .. "-- Right-click a remote for advanced options\n"
             .. "-- Press + to open this panel\n"
             .. "-- discord.gg/E7Tfjgruck"
            )
        end
    end
    if not codebox then
        -- Fallback plain textbox if Highlight fails
        local tb = New("TextBox", {
            Parent              = CodeFrame,
            BackgroundTransparency = 1,
            Size                = UDim2.new(1, 0, 1, 0),
            Font                = Enum.Font.Code,
            Text                = "-- Holt Spy ready",
            TextColor3          = T.Text,
            TextSize            = FS,
            TextXAlignment      = Enum.TextXAlignment.Left,
            TextYAlignment      = Enum.TextYAlignment.Top,
            MultiLine           = true,
            TextWrapped         = true,
            ClearTextOnFocus    = false,
            ZIndex              = 12,
        })
        Pad(6, 6, 4, 4, tb)
        codebox = {
            setRaw = function(_, str) tb.Text = str end,
            getString = function(_) return tb.Text end,
        }
    end

    -- Start scheduler
    schedulerConn = RunService.Heartbeat:Connect(taskScheduler)

    -- Start spy immediately (on by default)
    enableHooks()

    -- Animate loading bar
    logThread(task.spawn(function()
        local steps = {
            {0.25, "Loading modules..."},
            {0.5,  "Hooks ready..."},
            {0.75, "Building UI..."},
            {1.0,  "Done!"},
        }
        for _, s in ipairs(steps) do
            TweenService:Create(LoadFill, TweenInfo.new(0.22), {
                Size = UDim2.new(s[1], 0, 1, 0)
            }):Play()
            LoadStatusLbl.Text = s[2]
            task.wait(0.22)
        end
        task.wait(0.5)
        TweenService:Create(LoadFrame, TweenInfo.new(0.4), {
            Position = UDim2.new(1, 10, 1, -78)
        }):Play()
        task.wait(0.45)
        pcall(function() LoadFrame:Destroy() end)
    end))
end

Init()
