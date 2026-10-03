-- ShiroNeko Hub
-- Game: WarZ / CSGO Shooter (UniverseId: 10763998990)
-- Version: 1.1.16 Pro UI (Shooter & Survival Control)
-- UI direction: modern dark sidebar/card layout using WindUI.

(function()
local ENV = getgenv and getgenv() or _G
if ENV.ShiroNekoShooter and ENV.ShiroNekoShooter.Version=="1.1.16" then
    local alive = false
    pcall(function() alive = ENV.ShiroNekoShooter.IsAlive and ENV.ShiroNekoShooter.IsAlive() or false end)
    if alive then print("[ShiroNeko] Already loaded; duplicate auto-injection ignored.");return end
    ENV.ShiroNekoShooter = nil
end
if not ENV.ShiroNekoShooter and ENV.ShiroNekoShooterBoot and not ENV.ShiroNekoShooterBoot.Cancelled
    and os.clock()-(ENV.ShiroNekoShooterBoot.Started or 0)<180 then
    print("[ShiroNeko] Startup already in progress; duplicate ignored.");return
end
if ENV.ShiroNekoShooter and type(ENV.ShiroNekoShooter.Unload)=="function" then pcall(ENV.ShiroNekoShooter.Unload) end
local boot = {Phase = "Waiting for client", Started=os.clock()}
ENV.ShiroNekoShooterBoot = boot
local function ownsBoot() return ENV.ShiroNekoShooterBoot == boot end
local function awaitReady(label, predicate, seconds)
    boot.Phase = label
    print("[ShiroNeko Startup] " .. label)
    local deadline = os.clock() + (seconds or 120)
    repeat
        if not ownsBoot() or boot.Cancelled then error("ShiroNeko startup superseded or cancelled", 0) end
        local ok, value = pcall(predicate)
        if ok and value then return value end
        if os.clock() >= deadline then boot.Cancelled=true; if ownsBoot() then ENV.ShiroNekoShooterBoot=nil end; error("ShiroNeko startup timeout: " .. label, 0) end
        task.wait(0.2)
    until false
end

awaitReady("Waiting for game.Loaded", function() return game:IsLoaded() end)

local P, RS, Run, UIS, TS = 
    game:GetService("Players"), game:GetService("ReplicatedStorage"), 
    game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("TeleportService")

local LP = awaitReady("Waiting for LocalPlayer", function() return P.LocalPlayer end)
awaitReady("Waiting for PlayerGui", function() return LP:FindFirstChild("PlayerGui") end)

-- Wait for the observed game readiness flags, not merely Roblox Loaded.
if game.GameId~=10763998990 then boot.Cancelled=true;warn("ShiroNeko WarZ: different universe; stopped");return end
awaitReady("Waiting for WarZ profile and boot",function()
    return LP:GetAttribute("WarzBootReady")==true and LP:GetAttribute("WarzProfileReady")==true
end,120)
-- รอระบบของเกมโหลด
local Remotes = awaitReady("Waiting for Remotes", function() return RS:FindFirstChild("Remotes") end)
local Shared = awaitReady("Waiting for Shared Modules", function() return RS:FindFirstChild("Shared") end)
local WarzShared = Shared:FindFirstChild("warz")

local CFGFILE = "ShiroNekoHub_Shooter_Config.json"

-- ค่าเริ่มต้นของ Config
local D = {
    Version = 1,
    ESP=false, ESPThroughWalls=true, AimLock=false, AimActivation="Hold", AimKey="Right mouse", AimMethod="Auto", AimRespectUnlock=true, AimPart="Head", AimFOV=150, AimSpeed=28, AimVisible=true, ShowFOV=true, TeamCheck=true, VisualDistance=1500,
    -- Player
    AntiAFK = true, Walk = false, WalkSpeed = 44, InfJump = false, Noclip = false, Fly = false, FlySpeed = 60,
    -- Combat
    NoSpread = false, NoRecoil = false, ExpandHitbox = false, HitboxSize = 5, AutoCombineMags = false,
    -- Farming & Minigames
    AutoFishing = false, FishingDelay = 1, FishDepositWeight=100, FishReserveSlots=0, AutoLoot = false, AutoUseItem = false,
    MedSelection="Both", MedHealth=70, MedInterval=.25, MedKey="H", LootKey="G", ExitKey="F8",
    PartyCheck=true, AimOffset=0, AimPrediction=false, AimLead=.1,
    ESPProtect=true, ESPGear=false, GearHelmet="Any", GearArmor="Any", GearWeapon="Any", GearOnly=false, GearPreset="กำหนดเอง",
    RecoilReduction=100, SpreadReduction=100,
    AutoDeposit=false, DepositOnFull=true, DepositInterval=10,
    FishSpotMarked=false, FishSpotX=0, FishSpotY=0, FishSpotZ=0, FishLookX=0, FishLookY=0, FishLookZ=-1,
    WarehouseSpotMarked=false, WarehouseSpotX=0, WarehouseSpotY=0, WarehouseSpotZ=0,
    SurvivalAutomation=false,
    -- Lobby
    AutoReady = false, AutoStartMatch = false,
    -- Settings
    MenuBind = "LeftControl", Theme = "Dark", Transparency = 0
}

local function clone(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = clone(x) end
    return t
end

local function loadcfg()
    local c = clone(D)
    if isfile and isfile(CFGFILE) and readfile then
        local ok, r = pcall(readfile, CFGFILE)
        if ok then
            local ok2, t = pcall(function() return game:GetService("HttpService"):JSONDecode(r) end)
            if ok2 and type(t) == "table" then
                for k, v in pairs(t) do
                    if D[k] ~= nil and type(v) == type(D[k]) then c[k] = v end
                end
            end
        end
    end
    for k,r in pairs({AimFOV={30,500},AimSpeed={1,80},VisualDistance={50,5000},FishDepositWeight={50,100},FishReserveSlots={0,5},MedHealth={5,100},MedInterval={.1,5},AimOffset={-3,3},AimLead={0,.5},RecoilReduction={0,100},SpreadReduction={0,100},DepositInterval={1,120}}) do
        local n=c[k];if type(n)~="number" or n~=n or math.abs(n)==math.huge then n=D[k] end
        c[k]=math.clamp(n,r[1],r[2])
    end
    if c.AimSpeed==12 then c.AimSpeed=28 end
    if c.WalkSpeed==32 then c.WalkSpeed=44 end
    if c.AimActivation~="Hold" and c.AimActivation~="Toggle" and c.AimActivation~="Automatic" then c.AimActivation="Hold" end
    local keyOK = c.AimKey=="Right mouse" or c.AimKey=="MouseButton2" or c.AimKey=="MouseButton3"
    if not keyOK then pcall(function() keyOK=Enum.KeyCode[c.AimKey]~=nil and c.AimKey~="Unknown" end) end
    if not keyOK then c.AimKey="Right mouse" end
    if c.AimMethod~="Auto" and c.AimMethod~="Native" and c.AimMethod~="Camera" and c.AimMethod~="Mouse" then c.AimMethod="Auto" end
    if c.AimPart=="HumanoidRootPart" then c.AimPart="Body" end
    if c.AimPart~="Head" and c.AimPart~="Body" then c.AimPart="Head" end
    if c.MedSelection~="Both" and c.MedSelection~="DX Bandages" and c.MedSelection~="Medkit" then c.MedSelection="Both" end
    for _,field in ipairs({"MedKey","LootKey","ExitKey"}) do
        local ok,value=pcall(function()return Enum.KeyCode[c[field]] end)
        if not ok or not value or c[field]=="Unknown" or c[field]==c.MenuBind or c[field]==c.AimKey then c[field]=D[field] end
    end
    if c.MedKey==c.LootKey then c.LootKey="G";if c.MedKey=="G" then c.LootKey="J" end end
    local used={[c.MenuBind]=true,[c.AimKey]=true}
    for _,field in ipairs({"MedKey","LootKey","ExitKey"}) do
        if used[c[field]] then
            for _,key in ipairs({D[field],"F8","F9","F10","H","G","J"}) do
                if not used[key] then c[field]=key;break end
            end
        end
        used[c[field]]=true
    end
    return c
end

local S = loadcfg()
S.AutoFishing=false -- Manual-position fishing requires explicit start each session.
S.Run = true
S.Ready = false
S.LastCalls = {}
S.Conns = {}
S.OrigCollision = setmetatable({}, {__mode = "k"})
S.FlyBV = nil; S.FlyBG = nil; S.FlyRoot = nil
S.StartClock = os.clock()
S.LastError = nil
S.ESPObjects={}
S.SessionAutomation=false;S.InputFocused=true
S.VisualBinding="ShiroNekoShooterAim_"..game:GetService("HttpService"):GenerateGUID(false)

local SaveSequence = 0
local function writeConfig()
    if type(writefile) ~= "function" then return false end
    local out = {}
    for k in pairs(D) do out[k] = clone(S[k]) end
    local ok, err = pcall(function() writefile(CFGFILE, game:GetService("HttpService"):JSONEncode(out)) end)
    if not ok then S.LastError = "Config: " .. tostring(err) end
    return ok
end
local function save()
    if not S.Ready then return end
    SaveSequence = SaveSequence + 1
    local token = SaveSequence
    task.delay(0.4, function() if S.Run and token == SaveSequence then writeConfig() end end)
end

-- โหลด WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not ownsBoot() then return end
boot.Phase = "Creating window"

local Window = WindUI:CreateWindow({
    Title = "ShiroNeko Hub", Author = "WarZ Shooter", Folder = "ShiroNekoHub",
    Icon = "crosshair", Size = UDim2.fromOffset(720, 560), Theme = S.Theme or "Dark",
    NewElements = true
})

Window:Tag({Title = "v1.1.16", Color = Color3.fromHex("#1fbf8f")})
pcall(function() Window:SetToggleKey(Enum.KeyCode[S.MenuBind] or Enum.KeyCode.LeftControl) end)
pcall(function() Window:SetBackgroundTransparency(S.Transparency); Window:SetBackgroundImageTransparency(S.Transparency) end)

Window:CreateTopbarButton("shiro-theme", "moon", function()
    local nextTheme = WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark"
    WindUI:SetTheme(nextTheme); S.Theme = nextTheme; save()
end, 990)

local T = {
    Dashboard = Window:Tab({Title = "Overview", Icon = "layout-dashboard"}),
    Combat = Window:Tab({Title = "Combat & Guns", Icon = "swords"}),
    Visuals = Window:Tab({Title = "ESP", Icon = "eye"}),
    Farming = Window:Tab({Title = "Minigames & Loot", Icon = "fish"}),
    Settings = Window:Tab({Title = "Settings", Icon = "settings"}),
}

local F = {}
-- Verified client catalog snapshot: 20261003_162228_73396012.
F.EquipmentCatalog={["ARMOR_CITYSS2FTK"]={["name"]="ARMOR CITYSS2FTK",["kind"]="Armor",["icon"]="rbxassetid://92888930518454",["value"]=0.4},["ARMOR_CLLSJABZFTK"]={["name"]="ARMOR CORSAIR",["kind"]="Armor",["icon"]="rbxassetid://136204014751881",["value"]=0.5},["ARMOR_COMBAFTK"]={["name"]="ARMOR COMBAFTK",["kind"]="Armor",["icon"]="rbxassetid://103908166428763",["value"]=0.7},["ARMOR_Rebel_Heavy"]={["name"]="Custom Guerilla",["kind"]="Armor",["icon"]="rbxassetid://91079116266254",["value"]=0.3},["ARMOR_Rebel_Heavy_Blue"]={["name"]="Custom Guerilla · มุมน้ำเงิน",["kind"]="Armor",["icon"]="rbxassetid://91079116266254",["value"]=0.3},["ARMOR_Rebel_Heavy_Red"]={["name"]="Custom Guerilla · มุมแดง",["kind"]="Armor",["icon"]="rbxassetid://91079116266254",["value"]=0.3},["ARMOR_SPIDERMANFTK"]={["name"]="ARMOR SPIDERMANFTK",["kind"]="Armor",["icon"]="rbxassetid://140461959126017",["value"]=0.6},["AW_CITYSS2FTK"]={["name"]="AW CITYSS2FTK",["kind"]="SNP",["icon"]="rbxassetid://75606438401251",["value"]=0},["Blaser"]={["name"]="BLASER R93",["kind"]="SNP",["icon"]="rbxassetid://123070295177826",["value"]=0},["HAND_CLLJABZFTK"]={["name"]="HAND CORSAIR",["kind"]="Helmet",["icon"]="rbxassetid://89977192646541",["value"]=0.5},["HEADHELMET"]={["name"]="K. Style Helmet",["kind"]="Helmet",["icon"]="rbxassetid://135028019649154",["value"]=0.3},["HEADHELMET_Blue"]={["name"]="K. Style Helmet · มุมน้ำเงิน",["kind"]="Helmet",["icon"]="rbxassetid://135028019649154",["value"]=0.3},["HEADHELMET_Red"]={["name"]="K. Style Helmet · มุมแดง",["kind"]="Helmet",["icon"]="rbxassetid://135028019649154",["value"]=0.3},["HoneyBadger"]={["name"]="Honey Badger",["kind"]="ASR",["icon"]="rbxassetid://100109411965297",["value"]=0},["Honey_COMBAFTK"]={["name"]="Honey COMBAFTK",["kind"]="ASR",["icon"]="rbxassetid://115587174969314",["value"]=0},["LS90_SPIDERMANFTK"]={["name"]="LS90 SPIDERMANFTK",["kind"]="ASR",["icon"]="rbxassetid://130451385633995",["value"]=0},["M134_COBBAFTK"]={["name"]="M134 COBBAFTK",["kind"]="ASR",["icon"]="rbxassetid://100037602406609",["value"]=0},["M134_SPIDERMANFTK"]={["name"]="M134 SPIDERMANFTK",["kind"]="ASR",["icon"]="rbxassetid://124816500283201",["value"]=0},["MOTO_CITYSS2FTK"]={["name"]="MOTO CITYSS2FTK",["kind"]="Helmet",["icon"]="rbxassetid://111003586819118",["value"]=0.4},["MOTO_COBBAFTK"]={["name"]="MOTO COBBAFTK",["kind"]="Helmet",["icon"]="rbxassetid://128337179034758",["value"]=0.7},["MOTO_SPIDERRMANFTK"]={["name"]="MOTO SPIDERRMANFTK",["kind"]="Helmet",["icon"]="rbxassetid://94335288565212",["value"]=0.6},["SCAR_CITYSS2FTK"]={["name"]="SCAR CITYSS2FTK",["kind"]="ASR",["icon"]="rbxassetid://77026754818355",["value"]=0},["SIG556"]={["name"]="SIG SAUER 556",["kind"]="ASR",["icon"]="rbxassetid://86183293615073",["value"]=0},["SIG_CLLJABZFTK"]={["name"]="SIG CORSAIR",["kind"]="ASR",["icon"]="rbxassetid://123324490916056",["value"]=0},["SP_SPIDERMANFTK"]={["name"]="SP SPIDERMANFTK",["kind"]="SNP",["icon"]="rbxassetid://83734003248482",["value"]=0},["TAR21"]={["name"]="IMI TAR-21",["kind"]="ASR",["icon"]="rbxassetid://88558647065913",["value"]=0},["UZI"]={["name"]="UZI",["kind"]="SMG",["icon"]="rbxassetid://82968271540446",["value"]=0},["VSS_CITYSS2FTK"]={["name"]="VSS CITYSS2FTK",["kind"]="SNP",["icon"]="rbxassetid://124104750320306",["value"]=0},["VSS_CLLJABZFTK"]={["name"]="VSS CORSAIR",["kind"]="SNP",["icon"]="rbxassetid://121466196858670",["value"]=0},["VSS_COBBAFTK"]={["name"]="VSS COBBAFTK",["kind"]="SNP",["icon"]="rbxassetid://81850354512392",["value"]=0},["Vintorez"]={["name"]="VSS VINTOREZ",["kind"]="SNP",["icon"]="rbxassetid://120712465461152",["value"]=0}}
local UI = {}

local function safeDesc(obj, text)
    if obj and type(obj.SetDesc) == "function" then pcall(obj.SetDesc, obj, text) end
end
local function notify(t, c)
    pcall(function() WindUI:Notify({Title = t, Content = c, Icon = "bell", Duration = 4}) end)
end
local function root()
    local c = LP.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

-- ==========================================
-- BACKEND SYSTEMS (อิงจาก Remotes Dump)
-- ==========================================
local function fireRemote(remoteName, ...)
    if not S.Run or not S.Ready or not S.SessionAutomation or not F.inMatch() then return false end
    local remote = Remotes:FindFirstChild(remoteName)
    if remote then
        if remote:IsA("RemoteEvent") then remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then return remote:InvokeServer(...) end
        return true
    end
    return false
end

-- Verified client call sites: CombatInput.applyViewRecoil / fire.
-- Patches are owned wrappers; restore only if still installed by this instance.
F.gunPatches={}
function F.restoreGunMods()
    for _,p in pairs(F.gunPatches) do
        if p.module[p.key]==p.wrapper then p.module[p.key]=p.original end
    end
    F.gunPatches={}
end
function F.applyGunMods()
    F.restoreGunMods()
    if not S.Run or not S.Ready then return end
    local notes={}
    local function install(module,key,scaleField,enabled)
        if not enabled then return end
        local ok,err=pcall(function()
            assert(module,"Module unavailable")
            local t=require(module);assert(type(t)=="table" and type(t[key])=="function","Contract unavailable: "..key)
            local original=t[key]
            local wrapper
            if key=="ApplyRecoil" then
                wrapper=function(strength,...)
                    if S.Run and F.inMatch() then strength=(tonumber(strength) or 0)*(1-S[scaleField]/100) end
                    return original(strength,...)
                end
            else
                wrapper=function(direction,spread,...)
                    if S.Run and F.inMatch() and type(spread)=="number" then spread=spread*(1-S[scaleField]/100) end
                    return original(direction,spread,...)
                end
            end
            t[key]=wrapper;F.gunPatches[key]={module=t,key=key,original=original,wrapper=wrapper}
            notes[#notes+1]=key.." installed"
        end)
        if not ok then notes[#notes+1]=key..": "..tostring(err) end
    end
    local ps=LP:FindFirstChild("PlayerScripts");local client=ps and ps:FindFirstChild("Client")
    local world=client and client:FindFirstChild("world")
    install(world and world:FindFirstChild("WarzCamera"),"ApplyRecoil","RecoilReduction",S.NoRecoil)
    install(Shared:FindFirstChild("WarzSpread"),"ApplySpread","SpreadReduction",S.NoSpread)
    safeDesc(UI.GunStatus,#notes>0 and table.concat(notes," • ") or "OFF")
end

-- ==========================================
-- TABS BUILDER
-- ==========================================

-- v1.1.7: contracts from 20261002_213556_6C2A4F72; no native Build/Start calls.
local N = {state="Waiting for map", loaded=false}
local A = {phase="Off", enabled=false, fishing=false, med=false, loot=false, generation=0, walkSpeedOriginal=nil, walkSpeedApplied=false, waterAdjustIndex=0}
function F.readUpvalue(fn,index)
    if type(fn)~="function" or not debug or type(debug.getupvalue)~="function" then return nil end
    local ok,a,b=pcall(debug.getupvalue,fn,index)
    if not ok then return nil end
    -- Standard Lua returns name,value; Volt-style APIs may return value only.
    if type(a)=="string" and b~=nil then return b end
    return a
end
function F.loadNative()
    if N.loaded or N.loading or not F.inMatch() then return end
    N.loading=true;N.state="Reading existing game modules"
    task.spawn(function()
        local ok,err=pcall(function()
            local ps=LP:FindFirstChild("PlayerScripts")
            local client=ps and ps:FindFirstChild("Client")
            local world=client and client:FindFirstChild("world")
            local function cached(parent,name)
                local module=parent and parent:FindFirstChild(name)
                assert(module and module:IsA("ModuleScript"),"Missing module: "..name)
                return require(module)
            end
            local config=cached(Shared,"Config")
            local inv=cached(Shared,"Inventory")
            local fish=cached(world,"Fishing")
            local loot=cached(world,"LootPickup")
            local compat=cached(Shared,"FishingCompatibility")
            assert(type(config.ShopItem)=="function" and type(config.IsFishingRodKind)=="function" and type(config.IsBaitKind)=="function","Config contract changed")
            assert(type(fish.Press)=="function" and type(fish.IsActive)=="function" and type(fish.Build)=="function","Fishing contract changed")
            assert(type(loot.SetTouchHeld)=="function" and type(loot.CanPickup)=="function","Loot contract changed")
            assert(type(compat.Allows)=="function" and inv.BAG_START==9,"Inventory contract changed")
            if not S.Run then return end
            N.Config=config;N.Inventory=inv;N.Fishing=fish;N.Loot=loot;N.Compat=compat
            N.loaded=true;N.state="Native modules available"
        end)
        N.loading=false
        if not ok then N.state=tostring(err);A.error=N.state end
    end)
end
function F.context()
    if not N.loaded then return nil end
    local callback=F.readUpvalue(N.Fishing.Build,2)
    if type(callback)~="function" then return nil end
    local ok,c=pcall(callback)
    if ok and type(c)=="table" and type(c.profile)=="table" and type(c.profile.Backpack)=="table" and type(c.profile.Backpack.Slots)=="table" then return c end
end
function F.slot(bag,i)
    local row=bag and bag.Slots and bag.Slots[i]
    if type(row)=="table" and type(row.ItemId)=="string" and row.ItemId~="" and (tonumber(row.Qty) or 0)>0 then return row end
end
function F.item(row)
    if not row then return nil end
    local ok,item=pcall(N.Config.ShopItem,row.ItemId)
    if ok and type(item)=="table" then return item end
end
function F.isProtected(row)
    local item=F.item(row)
    if not item then return nil,"Unknown item definition: "..tostring(row.ItemId) end
    return N.Config.IsFishingRodKind(item.Kind) or N.Config.IsBaitKind(item.Kind)
end
function F.depositCandidate(bag)
    for i=9,math.floor(tonumber(bag.Size) or 0) do
        local row=F.slot(bag,i)
        if row then
            local protected,err=F.isProtected(row)
            if protected==nil then return nil,err end
            if not protected then return {slot=i,id=row.ItemId,qty=math.floor(row.Qty)} end
        end
    end
end
function F.bagFull(bag)
    if type(bag.Weight)=="number" and type(bag.WeightMax)=="number" and bag.WeightMax>0 and bag.Weight>=bag.WeightMax then return true end
    local top=tonumber(bag.Size)
    if not top or top<9 then return false end
    for i=9,math.floor(top) do if not F.slot(bag,i) then return false end end
    return true
end
function F.bagStatus(bag)
    local top=math.floor(tonumber(bag.Size) or 0);local free=0
    for i=9,top do if not F.slot(bag,i) then free=free+1 end end
    local weight,max=tonumber(bag.Weight),tonumber(bag.WeightMax)
    local percent=weight and max and max>0 and weight/max*100 or nil
    return free,math.max(0,top-8),percent
end
function F.shouldDeposit(bag)
    local free,total,percent=F.bagStatus(bag)
    local wanted=(total>0 and free<=math.floor(S.FishReserveSlots)) or (percent and percent>=S.FishDepositWeight)
    if not wanted then return false end
    -- Protected-only contents must not trigger an endless warehouse round trip.
    local item=F.depositCandidate(bag)
    return item~=nil
end
function F.bagStatusText(bag)
    if not bag then return "รอข้อมูลกระเป๋า" end
    local free,total,percent=F.bagStatus(bag)
    return string.format("ว่าง %d/%d ช่อง • น้ำหนัก %s",free,total,percent and string.format("%.1f%%",percent) or "ไม่มีข้อมูล")
end
function F.rodAndBait(bag)
    local active=LP:GetAttribute("CSGO_ActiveSlot")
    local rodSlot
    for i=1,6 do
        local item=F.item(F.slot(bag,i))
        if item and N.Config.IsFishingRodKind(item.Kind) then
            rodSlot=rodSlot or i;if i==active then rodSlot=i;break end
        end
    end
    if not rodSlot then return nil,"Put a fishing rod in hotbar slots 1–6" end
    local rod=F.slot(bag,rodSlot)
    for i=3,math.floor(tonumber(bag.Size) or 0) do
        if i~=7 and i~=8 and i~=rodSlot then
            local row=F.slot(bag,i);local item=F.item(row)
            if item and N.Config.IsBaitKind(item.Kind) and N.Compat.Allows(rod.ItemId,row.ItemId) then return rodSlot end
        end
    end
    return nil,"No compatible bait in backpack"
end

function F.warehouseButton()
    local pg=LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    -- Native Stash.lua names the red bulk button StashAll. It may be
    -- reparented by the fullscreen inventory layout; do not require Stash frame.
    for _,obj in ipairs(pg:GetDescendants()) do
        if obj.Name=="StashAll" and obj:IsA("GuiButton") then
            local visible=true;local node=obj
            while node and node~=pg do
                if node:IsA("GuiObject") and not node.Visible then visible=false;break end
                if node:IsA("ScreenGui") and not node.Enabled then visible=false;break end
                node=node.Parent
            end
            if visible and obj.AbsoluteSize.X>0 and obj.AbsoluteSize.Y>0 then return obj end
        end
    end
end
function F.warehouseOpen()
    return F.warehouseButton()~=nil
end
function F.warehouseReady()
    local button=F.warehouseButton()
    return button~=nil and button.Active==true
end
function F.fishingMessage()
    -- Only an explicit response to our cast may trigger recovery.
    return A.castFailure
end
function F.nativeSend(name,...)
    if not S.Run or not S.Ready or not F.inMatch() or LP:GetAttribute("WarzDisconnectAt") or LP:GetAttribute("CSGO_Dead")==true then return false end
    local remote=Remotes:FindFirstChild(name)
    if not remote or not remote:IsA("RemoteEvent") then error("Missing verified RemoteEvent: "..name) end
    remote:FireServer(...);return true
end
-- Movement ordering verified in PlayerStance: Character + 1.
-- Do not overwrite its speed, stamina, locks or facility attributes.
function F.stopWalk()
    A.generation=A.generation+1;A.travel=nil
    if A.navBinding then pcall(function()Run:UnbindFromRenderStep(A.navBinding)end);A.navBinding=nil end
    local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if A.walkOwned and h then h:Move(Vector3.zero,false) end
    A.walkOwned=false
end
function F.navNear(a,b)
    local d=a-b
    return Vector3.new(d.X,0,d.Z).Magnitude<1.5 and math.abs(d.Y)<5
end
function F.walkTo(point,nextPhase)
    F.stopWalk()
    local token=A.generation;local char=LP.Character;local r=root()
    local h=char and char:FindFirstChildOfClass("Humanoid")
    if not h or not r then return F.pauseFishing("Character unavailable") end
    A.travel=true;A.walkOwned=true
    local target=nil
    local function arrived() return F.navNear(r.Position,point) or (nextPhase=="Await warehouse" and F.warehouseOpen()) end
    local function alive()return S.Run and A.fishing and token==A.generation and char==LP.Character and h.Health>0 and F.inMatch() end
    local function paused()return not S.InputFocused or UIS:GetFocusedTextBox() or LP:GetAttribute("CSGO_Paused")==true or (LP:GetAttribute("CSGO_UiUnlock")==true and LP:GetAttribute("WarzFacilityAuto")~=true) end
    A.navBinding=S.VisualBinding.."_Walk"
    Run:BindToRenderStep(A.navBinding,Enum.RenderPriority.Character.Value+2,function()
        if not alive() then return end
        if not target or paused() then h:Move(Vector3.zero,false);return end
        local d=target-r.Position;d=Vector3.new(d.X,0,d.Z)
        h:Move(d.Magnitude>.25 and d.Unit or Vector3.zero,false)
    end)
    task.spawn(function()
        local ok,err=pcall(function()
            for attempt=1,4 do
                if not alive() then return end
                if arrived() then break end
                local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
                path:ComputeAsync(r.Position,point)
                if not alive() then return end
                if path.Status~=Enum.PathStatus.Success then error("No path to destination") end
                local blocked=false;local index=1
                local conn=path.Blocked:Connect(function(i)if i>=index then blocked=true end end)
                local routeOK,routeErr=pcall(function()
                    for i,wp in ipairs(path:GetWaypoints()) do
                        index=i
                        if not alive() or blocked or arrived() then break end
                        target=wp.Position
                        if wp.Action==Enum.PathWaypointAction.Jump then h.Jump=true end
                        local last=r.Position;local stalled=0;local active=0;local waited=0
                        while alive() and not F.navNear(r.Position,target) and not blocked and not arrived() do
                            task.wait(.05);waited=waited+.05
                            if paused() then
                                A.note="ปิดเมนู/กลับหน้าต่างเกมเพื่อเดินต่อ"
                                if waited>60 then error("Movement paused for 60 seconds") end
                            else
                                A.note=nil;active=active+.05
                                if (r.Position-last).Magnitude>.2 then last=r.Position;stalled=0 else stalled=stalled+.05 end
                                if stalled>1.5 or active>15 then blocked=true end
                            end
                        end
                    end
                end)
                conn:Disconnect();target=nil
                if not routeOK then error(routeErr) end
                if not alive() then return end
                if arrived() then break end
            end
            if not alive() then return end
            if not arrived() then error("Route blocked after 4 attempts") end
            F.stopWalk();A.phase=nextPhase;A.phaseAt=os.clock()
        end)
        if not ok and token==A.generation then F.pauseFishing(tostring(err))
        elseif token==A.generation and not alive() then F.stopWalk() end
    end)
end
function F.warehouseCenter()
    local map=workspace:FindFirstChild("Map_WZ_Trade")
    local f=map and map:FindFirstChild("SafeZoneFacilities")
    local zone=f and f:FindFirstChild("WarehouseZone")
    if not zone then return nil end
    local sum,n=Vector3.zero,0
    for _,p in ipairs(zone:GetDescendants()) do
        if p:IsA("BasePart") and p.Name=="Ring" then sum=sum+p.Position;n=n+1 end
    end
    if n<3 then return nil end
    return sum/n+Vector3.new(0,3,0)
end
function F.seekShore()
    F.stopWalk();local token=A.generation;A.travel=true;A.phase="ค้นหาริมน้ำที่เดินถึง"
    task.spawn(function()
        local ok,err=pcall(function()
            local r=root();assert(r,"No character")
            local origin=r.Position
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={LP.Character};params.IgnoreWater=false
            local candidates={}
            for distance=8,240,8 do
                if not S.Run or not A.fishing or token~=A.generation then return end
                for k=0,15 do
                    local dir=Vector3.new(math.cos(k*math.pi/8),0,math.sin(k*math.pi/8))
                    local probe=origin+dir*distance
                    local water=workspace:Raycast(probe+Vector3.new(0,20,0),Vector3.new(0,-65,0),params)
                    if water and water.Material==Enum.Material.Water then
                        for offset=3,15,3 do
                            local land=water.Position-dir*offset
                            local floor=workspace:Raycast(land+Vector3.new(0,8,0),Vector3.new(0,-16,0),params)
                            if floor and floor.Material~=Enum.Material.Water and floor.Normal.Y>.7 and math.abs(floor.Position.Y-water.Position.Y)<5 then
                                local stand=floor.Position+Vector3.new(0,3,0)
                                candidates[#candidates+1]={stand=stand,water=water.Position,dist=(stand-origin).Magnitude};break
                            end
                        end
                    end
                end
                if #candidates>=12 then break end
                task.wait()
            end
            table.sort(candidates,function(a,b)return a.dist<b.dist end)
            for i=1,math.min(#candidates,12) do
                local c=candidates[i]
                local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
                path:ComputeAsync(origin,c.stand)
                if not S.Run or not A.fishing or token~=A.generation then return end
                if path.Status==Enum.PathStatus.Success then
                    A.spot=c.stand;A.water=c.water;A.travel=nil
                    F.walkTo(c.stand,"Aligning water");return
                end
            end
            error("ไม่พบฝั่งที่เดินถึงในระยะ 240 studs — ขยับเข้าใกล้ฝั่งแล้วเปิดใหม่")
        end)
        if not ok and token==A.generation then F.pauseFishing(tostring(err)) end
    end)
end
function F.beginWarehouse()
    local p=F.warehouseCenter()
    if not p then return F.pauseFishing("WarehouseZone not loaded") end
    A.phase="เดินเข้ากลางวงคลัง";A.pending=nil;A.bulkAt=nil;A.bulkSent=false;A.castFailure=nil
    F.walkTo(p,"Await warehouse")
end
function F.pauseFishing(reason)
    F.stopWalk();A.fishing=false;A.phase="Stopped";A.error=reason
    if not A.syncWarehouse then
        A.syncWarehouse=true
        if UI.WarehouseToggle and type(UI.WarehouseToggle.Set)=="function" then pcall(UI.WarehouseToggle.Set,UI.WarehouseToggle,false) end
        A.syncWarehouse=false
    end
    if A.ownsCast and N.Fishing then pcall(N.Fishing.CancelIfActive) end
    A.ownsCast=false;A.pending=nil;A.equip=nil;A.castPending=nil
    safeDesc(UI.FishStatus,reason or "OFF")
    if not A.syncFish then
        A.syncFish=true
        if UI.FishToggle and type(UI.FishToggle.Set)=="function" then pcall(UI.FishToggle.Set,UI.FishToggle,false) end
        A.syncFish=false
    end
end

function F.retryFishing(message,now)
    if not A.fishing or A.depositOnly then return end
    A.castPending=nil;A.castFailure=nil;A.ownsCast=false;A.equip=nil
    A.castRetries=(A.castRetries or 0)+1
    A.retryAt=math.max(now+math.min(15,2+A.castRetries*2),A.nextCast or 0)
    A.phase="Retry cast";A.note="เหวี่ยงไม่สำเร็จ • รอลองใหม่: "..tostring(message)
end
function F.retryFishingStep(now)
    if now<(A.retryAt or 0) then return end
    if F.fishState() or N.Fishing.IsActive() then return end
    local r=root();if not r or not A.water then return F.pauseFishing("ไม่มีตำแหน่งน้ำสำหรับลองใหม่") end
    A.note=nil;A.phase="Aligning water";A.phaseAt=now
    -- At most three small land-validated adjustments per session/accepted cast.
    -- Never step into water, or move just because a result message mentions an error.
    if (A.castRetries or 0)>1 and (A.waterAdjustIndex or 0)<3 then
        local delta=A.water-r.Position;delta=Vector3.new(delta.X,0,delta.Z)
        if delta.Magnitude>3 then
            local nextPos=r.Position+delta.Unit*1.5
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={LP.Character};params.IgnoreWater=false
            local floor=workspace:Raycast(nextPos+Vector3.new(0,2,0),Vector3.new(0,-8,0),params)
            A.waterAdjustIndex=(A.waterAdjustIndex or 0)+1
            if floor and floor.Material~=Enum.Material.Water and floor.Normal.Y>.7 and math.abs(floor.Position.Y-(r.Position.Y-3))<2 then
                A.spot=floor.Position+Vector3.new(0,3,0)
                F.walkTo(A.spot,"Aligning water")
            end
        end
    end
end

function F.clearNativeLook()
    for _,axis in ipairs({"DX","DY"}) do
        local name="WarzLook"..axis
        if A[axis]~=nil and LP:GetAttribute(name)==A[axis] then LP:SetAttribute(name,nil) end
        A[axis]=nil
    end
end
function F.nativeLook(direction,alpha)
    local cam=workspace.CurrentCamera
    if not cam or direction.Magnitude<.001 then return false end
    -- These input attributes are consumed by WarzCamera at RenderPriority.Last-2.
    local yaw=LP:GetAttribute("CSGO_Yaw");local pitch=LP:GetAttribute("CSGO_Pitch")
    if type(yaw)~="number" or type(pitch)~="number" then return false end
    if LP:GetAttribute("WarzLookDX")~=nil or LP:GetAttribute("WarzLookDY")~=nil then return false end
    local v=direction.Unit
    local dyaw=(math.atan2(-v.X,-v.Z)-yaw+math.pi)%(2*math.pi)-math.pi
    local dpitch=math.clamp(math.asin(v.Y),-1.2217,1.2217)-pitch
    local sensitivity=math.max(.05,tonumber(LP:GetAttribute("WarzLookSens")) or 1)*.0034
    local dx=math.clamp(-dyaw*alpha/sensitivity,-60,60)
    local dy=math.clamp(-dpitch*alpha/sensitivity,-60,60)
    A.DX=dx;A.DY=dy
    LP:SetAttribute("WarzLookDX",dx);LP:SetAttribute("WarzLookDY",dy)
    return true
end
function F.fishState()
    if not N.Fishing then return nil end
    local state=F.readUpvalue(N.Fishing.IsActive,1)
    if type(state)=="table" and (state.phase=="cast" or state.phase=="reel") and state.castId~=nil then return state end
end
function F.reelStep()
    if not A.fishing or not A.ownsCast or not F.inMatch() or not S.InputFocused or UIS:GetFocusedTextBox() then return end
    local c=F.context()
    if not c or not c.inMatch or c.dead or c.paused or c.page~="Hud" then return end
    local state=F.fishState()
    if not state or state.phase~="reel" or A.reelSent==state.castId then return end
    if type(state.biteAt)~="number" or type(state.zoneCenter)~="number" or type(state.zoneWidth)~="number" or type(state.speed)~="number" then return F.pauseFishing("Fishing state changed; reel disabled") end
    local now=workspace:GetServerTimeNow()
    if state.deadline and now>=state.deadline then return end
    local marker=((now-state.biteAt)*state.speed)%2
    if marker>1 then marker=2-marker end
    if now>=state.biteAt and math.abs(marker-state.zoneCenter)<=math.max(0,state.zoneWidth*.35) then
        A.reelSent=state.castId;N.Fishing.Press();A.phase="Waiting result";A.phaseAt=os.clock()
    end
end
function F.fishingStep(now,c)
    if not A.fishing then return end
    if not F.inMatch() or LP.Character~=A.character or LP:GetAttribute("CSGO_Dead")==true then return F.pauseFishing("Map/character changed; restart at the water") end
    if not N.loaded or not c then
        if now-A.started>10 then F.pauseFishing("Cannot read game profile. Native context/getupvalue unavailable") end
        return
    end
    if not S.InputFocused or UIS:GetFocusedTextBox() then return end
    if A.travel then return end
    local bag=c.profile.Backpack
    if not A.depositOnly and F.shouldDeposit(bag) and not F.fishState() and not N.Fishing.IsActive() and not A.castPending and A.phase~="Depositing" and A.phase~="Await warehouse" then F.beginWarehouse();return end
    if A.phase=="Retry cast" then
        if not c.paused and not c.dead and c.page=="Hud" and LP:GetAttribute("CSGO_UiUnlock")~=true then F.retryFishingStep(now) end
        return
    end
    if A.phase=="Aligning water" then
        local cam=workspace.CurrentCamera
        if not cam or not A.water then return F.pauseFishing("Water target unavailable") end
        local delta=A.water-cam.CFrame.Position
        if delta.Magnitude<.1 then return F.pauseFishing("Water target too close") end
        if cam.CFrame.LookVector:Dot(delta.Unit)<.99 then
            if now-(A.phaseAt or now)>6 then return F.retryFishing("ยังหันกล้องไม่ถึงน้ำ",now) end
            return
        end
        A.phase="Ready"
    end
    if A.phase=="Await warehouse" then
        if F.warehouseOpen() then A.phase="Depositing";A.phaseAt=now
        elseif now-(A.phaseAt or now)>10 then return F.pauseFishing("ถึงวงแล้วแต่หน้าคลังไม่เปิด") end
        return
    end
    if A.phase=="Depositing" then
        if not F.warehouseOpen() then
            return F.pauseFishing("คลังปิดแล้ว: หยุดฝากของ")
        end
        if A.bulkAt then
            local empty=true
            for i=9,bag.Size do local row=F.slot(bag,i);if row and row.ItemId and (row.Qty or 0)>0 then empty=false;break end end
            if empty then A.bulkAt=nil
            elseif now-A.bulkAt>8 then return F.pauseFishing("Bulk deposit not confirmed; stopped without retry")
            else return end
        end
        if A.pending then
            local row=F.slot(bag,A.pending.slot)
            if not row or row.ItemId~=A.pending.id or row.Qty<A.pending.qty then A.pending=nil;A.nextTransfer=now+.25
            elseif now-A.pending.at>8 then return F.pauseFishing("Warehouse transfer not confirmed (full/rejected). Stopped without retrying") end
            return
        end
        -- Completion must be checked before the native button: empty bag disables StashAll.
        local item,err=F.depositCandidate(bag)
        if err then return F.pauseFishing(err) end
        if not item then
            if F.bagFull(bag) then return F.pauseFishing("เหลือเฉพาะเบ็ด/เหยื่อแต่กระเป๋ายังเต็ม ต้องเคลียร์พื้นที่ก่อน") end
            if A.depositOnly then return F.pauseFishing("ฝากของเสร็จแล้ว") end
            if not A.spot or not A.water then return F.pauseFishing("ไม่มีจุดตกปลาสำหรับเดินกลับ") end
            A.note=nil;A.phase="กลับจุดตกปลา";A.equip=nil;A.castFailure=nil;A.fullFromResult=nil
            F.walkTo(A.spot,"Aligning water");return
        end
        if not F.warehouseReady() then
            A.note="รอปุ่มเก็บของพร้อม"
            if now-(A.phaseAt or now)>10 then return F.pauseFishing("ปุ่ม StashAll ยังไม่พร้อม") end
            return
        end
        A.note=nil
        if now<(A.nextTransfer or 0) then return end
        local protected=false
        for i=9,bag.Size do
            local def=F.item(F.slot(bag,i))
            if def and (N.Config.IsFishingRodKind(def.Kind) or N.Config.IsBaitKind(def.Kind)) then protected=true;break end
        end
        if not protected and not A.bulkSent then
            A.bulkSent=true;A.bulkAt=now;A.note="ส่งคำสั่งเก็บทั้งหมดแล้ว — รอคลังยืนยัน"
            if not F.nativeSend("BagAllToStash") then return F.pauseFishing("Bulk deposit blocked") end
            return
        end
        item.at=now;A.pending=item
        if not F.nativeSend("BagToStash",item.slot,item.qty) then F.pauseFishing("Transfer blocked") end
        return
    end

    if c.paused or c.dead or c.page~="Hud" or LP:GetAttribute("CSGO_UiUnlock")==true then A.note="Close the game menu to continue";return end
    A.note=nil
    local state=F.fishState()
    if state then
        if not A.ownsCast then A.note="Waiting for current manual cast";return end
        A.castPending=nil;A.phase=state.phase=="reel" and "Green-zone reel" or "Waiting for bite"
        if now-(A.castAt or now)>120 then F.pauseFishing("Fishing state timed out") end
        return
    end
    if N.Fishing.IsActive() then return F.pauseFishing("Active fishing state unreadable; no blind reel") end
    local fishMsg=F.fishingMessage()
    if fishMsg then return F.retryFishing(fishMsg,now) end
    if A.castPending then
        if now-A.castPending>6 then return F.retryFishing("ยังไม่ได้รับสถานะเหวี่ยง",now) end
        return
    end
    if A.ownsCast then
        A.ownsCast=false;A.nextCast=now+math.max(1,tonumber(N.Config.Fishing and N.Config.Fishing.ResultHoldSeconds) or 3)
    end
    if F.shouldDeposit(bag) then A.depositOnly=false;F.beginWarehouse();return end
    if F.bagFull(bag) then return F.pauseFishing("กระเป๋าเต็มแต่ไม่มีของที่ฝากได้ • เบ็ด/เหยื่อยังเก็บไว้") end
    if now<(A.nextCast or 0) then A.phase="Reward / cooldown";return end
    local cd=tonumber(LP:GetAttribute("WarzFishCdUntil")) or 0
    if cd>workspace:GetServerTimeNow() then A.phase="Fishing cooldown";return end
    local r=root()
    if not r or not A.spot or (r.Position-A.spot).Magnitude>6 then return F.pauseFishing("ย้ายจากจุดเริ่ม: จัดตำแหน่งแล้วเปิด Auto Fishing ใหม่") end
    local slot,why=F.rodAndBait(bag)
    if not slot then return F.pauseFishing(why) end
    if LP:GetAttribute("CSGO_ActiveSlot")~=slot then
        A.phase="Equipping rod"
        if not A.equip then A.equip={slot=slot,at=now};F.nativeSend("SwitchWeaponRequest",slot)
        elseif now-A.equip.at>5 then F.pauseFishing("Rod equip not confirmed") end
        return
    end
    A.equip=nil

    A.alignAt=nil;A.ownsCast=true;A.castPending=now;A.castAt=now;A.reelSent=nil
    A.phase="Casting (left-click action)";N.Fishing.Press()
end
function F.medKind(item)
    if not item or type(N.Config.IsMedicalKind)~="function" or not N.Config.IsMedicalKind(item.Kind) or item.RestoreStamina==true then return nil end
    local name=(tostring(item.Id or "").." "..tostring(item.Name or "")):lower():gsub("[^%w]","")
    if name:find("medkit",1,true) or name:find("mekit",1,true) then return "Medkit" end
    if name:find("dx",1,true) and name:find("band",1,true) then return "DX Bandages" end
end
function F.medStep(now,c)
    if not A.med then return end
    if LP:GetAttribute("WarzDisconnectAt") then return end
    if not c or not c.inMatch or c.dead or c.paused or c.page~="Hud" or A.phase=="Depositing" or A.travel or A.ownsCast then A.medNote="Waiting for playable state";return end
    local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 then return end
    local cooldown=tonumber(LP:GetAttribute("WarzMedCdLeft")) or 0
    if A.medPending then
        local row=F.slot(c.profile.Backpack,A.medPending.slot)
        if not row or row.ItemId~=A.medPending.id or row.Qty<A.medPending.qty or h.Health>A.medPending.hp or cooldown>.05 then
            A.medPending=nil;A.nextMed=now+S.MedInterval
        elseif now-A.medPending.at>8 then A.med=false;A.medNote="Use not confirmed; stopped. Toggle on to retry" end
        return
    end
    if h.Health/h.MaxHealth*100>S.MedHealth then A.medNote="HP above threshold";return end
    if cooldown>.05 or now<(A.nextMed or 0) then A.medNote="Waiting for game cooldown";return end
    for i=3,6 do
        local row=F.slot(c.profile.Backpack,i);local kind=F.medKind(F.item(row))
        if kind and (S.MedSelection=="Both" or S.MedSelection==kind) then
            A.medPending={slot=i,id=row.ItemId,qty=row.Qty,hp=h.Health,at=now}
            A.medNote="Using "..kind
            F.nativeSend("UseItem",i,row.ItemId,nil,nil,true);return
        end
    end
    A.medNote="Put selected DX Bandages / Medkit in slots 3–6"
end
function F.toggleMed(value)
    if not S.Ready then return end
    A.enabled=true
    if value==nil then value=not A.med end;A.med=value;S.AutoUseItem=value;save();A.medNote=A.med and "Starting" or "OFF";A.medPending=nil
    if A.med then F.loadNative() end
end
function F.toggleLoot(value)
    if not S.Ready then return end
    A.enabled=true
    if value==nil then value=not A.loot end;A.loot=value;S.AutoLoot=value;save()
    if A.loot then F.loadNative() elseif N.Loot and A.lootOwned then N.Loot.SetTouchHeld(false);A.lootOwned=false end
end
function F.startFishing()
    if not S.Ready then return end
    if A.fishing then
        if A.depositOnly then F.pauseFishing("Switching to fishing") else return end
    end
    A.pending=nil;A.equip=nil;A.castPending=nil;A.ownsCast=false
    local r=root()
    if not F.inMatch() or not r or LP:GetAttribute("WarzDisconnectAt") then return F.pauseFishing("เข้าแมพก่อนเปิดตกปลา") end
    F.loadNative();A.enabled=true;A.error=nil;A.note=nil;A.started=os.clock()
    A.character=LP.Character;A.spot=r.Position;A.fishing=true;A.phase="Ready"
    A.castFailure=nil;A.nextCast=nil;A.fullFromResult=nil;A.depositOnly=false;A.castRetries=0;A.waterAdjustIndex=0
    F.seekShore()
end
function F.depositNow()
    if not S.Ready then return end
    if not F.inMatch() then
        return F.pauseFishing("เข้าแมพก่อนเปิด Warehouse")
    end
    if A.phase=="Depositing" and A.fishing then return end
    F.pauseFishing("Preparing deposit");F.loadNative()
    A.enabled=true;A.fishing=true;A.depositOnly=true;A.error=nil;A.note=nil
    A.started=os.clock();A.character=LP.Character;A.phase="Depositing"
    A.phaseAt=os.clock();A.nextTransfer=nil
    F.beginWarehouse()
    A.syncWarehouse=true
    if UI.WarehouseToggle and type(UI.WarehouseToggle.Set)=="function" then pcall(UI.WarehouseToggle.Set,UI.WarehouseToggle,true) end
    A.syncWarehouse=false
end
function F.stopAllAutomation()
    S.AutoFishing=false;F.toggleMed(false);F.toggleLoot(false);save()
    A.enabled=false;A.med=false;A.loot=false;A.capture=nil
    F.pauseFishing("All automation OFF")
    if A.lootOwned and N.Loot then pcall(N.Loot.SetTouchHeld,false);A.lootOwned=false end
end
function F.keyUsed(key,except)
    for _,field in ipairs({"MenuBind","AimKey","MedKey","LootKey","ExitKey"}) do
        if field~=except and S[field]==key then return true end
    end
    return false
end
function F.requestExit()
    if not S.Run or not S.Ready or not F.inMatch() or not S.InputFocused or UIS:GetFocusedTextBox() then return end
    if LP:GetAttribute("WarzDisconnectAt") or os.clock()<(A.exitAt or -math.huge)+3 then return end
    F.pauseFishing("ออกจากแมพ");F.resetAim()
    if F.nativeSend("LeaveMap") then A.exitAt=os.clock();notify("Exit","ส่งคำขอออกจากแมพแล้ว • รอเวลาของเกม") end
end
function F.captureAction(field,label)
    if not S.Ready then return end
    S.CaptureAimKey=nil;S.CaptureMenuKey=nil;A.capture={field=field,label=label,untilAt=os.clock()+10}
    safeDesc(UI.ActionKeys,"Press a keyboard key; Escape cancels (10 seconds)")
end
function F.startSurvival()
    local remote=Remotes:FindFirstChild("FishingState")
    if remote and remote:IsA("RemoteEvent") then
        S.Conns[#S.Conns+1]=remote.OnClientEvent:Connect(function(data)
            if not A.fishing or not A.ownsCast or type(data)~="table" then return end
            if data.phase=="cast" or data.phase=="reel" then A.castPending=nil;A.castFailure=nil;A.castRetries=0;A.waterAdjustIndex=0 end
            if data.phase=="result" or data.phase=="cancel" then
                A.castPending=nil;A.ownsCast=false
                A.nextCast=os.clock()+math.max(1,tonumber(N.Config and N.Config.Fishing and N.Config.Fishing.ResultHoldSeconds) or 3)
                -- Bag-full detection uses the real profile, not guessed result codes.
                if data.ok==false then
                    local msg=tostring(data.message or "Cast failed");A.note=msg
                    A.castFailure=msg
                end
            end
        end)
    end
    S.Conns[#S.Conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if not S.Run or not S.Ready or UIS:GetFocusedTextBox() or not S.InputFocused then return end
        if A.capture then
            if input.KeyCode==Enum.KeyCode.Escape then A.capture=nil;return end
            if input.UserInputType~=Enum.UserInputType.Keyboard or input.KeyCode==Enum.KeyCode.Unknown then return end
            local key=input.KeyCode.Name
            if F.keyUsed(key,A.capture.field) then return notify("Hotkey","Key is already assigned") end
            S[A.capture.field]=key;A.capture=nil;save();return
        end
        if processed or S.CaptureAimKey or S.CaptureMenuKey or not F.inMatch() then return end
        if input.KeyCode.Name==S.MedKey then F.toggleMed()
        elseif input.KeyCode.Name==S.LootKey then F.toggleLoot()
        elseif input.KeyCode.Name==S.ExitKey then F.requestExit() end
    end)
    S.Conns[#S.Conns+1]=UIS.WindowFocusReleased:Connect(function()
        if A.lootOwned and N.Loot then N.Loot.SetTouchHeld(false);A.lootOwned=false end
        F.clearNativeLook();if A.fishing then F.pauseFishing("Focus lost; restart fishing when ready") end
    end)
    S.Conns[#S.Conns+1]=LP.CharacterRemoving:Connect(function()
        F.pauseFishing("Character removed");A.med=false;A.loot=false
        if A.lootOwned and N.Loot then N.Loot.SetTouchHeld(false);A.lootOwned=false end
    end)
    local elapsed=0
    S.Conns[#S.Conns+1]=Run.Heartbeat:Connect(function(dt)
        if not S.Run or not S.Ready then return end
        local ok,err=pcall(function()
            F.reelStep()
            elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
            local now=os.clock();local c=F.context()
            if A.capture and now>A.capture.untilAt then A.capture=nil end
            if A.fishing then F.fishingStep(now,c) end
            if S.InputFocused and not UIS:GetFocusedTextBox() then F.medStep(now,c) end

            if N.Loot then
                local held=A.loot and not LP:GetAttribute("WarzDisconnectAt") and F.inMatch() and S.InputFocused and not UIS:GetFocusedTextBox() and LP:GetAttribute("CSGO_Dead")~=true and LP:GetAttribute("CSGO_UiUnlock")~=true and LP:GetAttribute("CSGO_Paused")~=true and not A.fishing
                if held then N.Loot.SetTouchHeld(true);A.lootOwned=true
                elseif A.lootOwned then N.Loot.SetTouchHeld(false);A.lootOwned=false end
            end
            safeDesc(UI.BagStatus,F.bagStatusText(c and c.profile.Backpack))
            safeDesc(UI.FishStatus,A.error or A.note or (A.fishing and A.phase or "OFF"))
            safeDesc(UI.WarehouseStatus,A.depositOnly and (A.error or A.note or A.phase) or "OFF")
            safeDesc(UI.MedStatus,(A.med and "ON • " or "OFF • ")..(A.medNote or "DX Bandages / Medkit").." | "..S.MedKey)
            safeDesc(UI.LootStatus,(A.loot and "ON • Aim at a nearby pickup; native 1s hold" or "OFF").." | "..S.LootKey)
            if not A.capture then safeDesc(UI.ActionKeys,"Medicine: "..S.MedKey.." • Loot: "..S.LootKey.." • Exit: "..S.ExitKey) end
            safeDesc(UI.ExitStatus,A.capture and A.capture.field=="ExitKey" and "กดคีย์ใหม่ • Escape ยกเลิก" or S.ExitKey)
            safeDesc(UI.NativeStatus,N.state..(N.loaded and not c and " • Profile context unavailable" or ""))
        end)
        if not ok then
            S.LastError="Survival: "..tostring(err);F.pauseFishing(S.LastError);A.med=false;A.loot=false
            if A.lootOwned and N.Loot then pcall(N.Loot.SetTouchHeld,false);A.lootOwned=false end
        end
    end)
end
function F.buildFarming()
    local fish=T.Farming:Section({Title="Fishing → Central Warehouse",Box=true,Opened=true})
    UI.FishToggle=fish:Toggle({Title="Auto Fishing",Value=S.AutoFishing,Desc="ค้นหาฝั่งและเดินไปตกปลา • เต็มแล้วเข้าคลังและกลับมาตกต่อ",Callback=function(v)
        if not S.Ready or A.syncFish then return end
        S.AutoFishing=false;save();if v then F.startFishing() else F.pauseFishing("Auto Fishing OFF") end
    end})
    UI.FishStatus=fish:Paragraph({Title="Fishing status",Desc="OFF"})
    UI.BagStatus=fish:Paragraph({Title="กระเป๋า",Desc="รอข้อมูลกระเป๋า"})
    local cycle=T.Farming:Section({Title="ตกปลา → ฝากของ → กลับมาตกต่อ",Box=true,Opened=false})
    cycle:Paragraph({Title="เปิด Auto Fishing เพียงสวิตช์เดียว",Desc="ไปจุดตกปลาเอง • เต็มแล้วฝาก • รอยืนยันก่อนกลับ • เก็บเบ็ดและเหยื่อไว้"})
    cycle:Slider({Title="กลับฝากเมื่อน้ำหนักถึง (%)",Step=1,Value={Min=50,Max=100,Default=S.FishDepositWeight},Callback=function(v)if not S.Ready then return end;S.FishDepositWeight=v;save()end})
    cycle:Slider({Title="กลับฝากเมื่อเหลือช่องว่างไม่เกิน",Desc="0 = เต็มทุกช่อง • 1–2 = เผื่อช่องรับปลา",Step=1,Value={Min=0,Max=5,Default=S.FishReserveSlots},Callback=function(v)if not S.Ready then return end;S.FishReserveSlots=math.floor(v);save()end})
    local warehouse=T.Farming:Section({Title="Warehouse",Box=true,Opened=true})
    UI.WarehouseToggle=warehouse:Toggle({Title="เดินเข้าคลังและฝากทั้งหมด",Value=false,Desc="ฝากครั้งเดียวด้วยตัวเอง • Auto Fishing จัดการฝากให้อยู่แล้ว",Callback=function(v)
        if not S.Ready or A.syncWarehouse then return end
        if v then F.depositNow() elseif A.depositOnly then F.pauseFishing("Warehouse OFF") end
    end})
    UI.WarehouseStatus=warehouse:Paragraph({Title="Warehouse status",Desc="OFF"})
    warehouse:Paragraph({Title="วิธีใช้",Desc="เดินเข้ากลางวงแล้วฝากทั้งหมด • ถ้ามีเบ็ด/เหยื่อในกระเป๋าจะฝากแยกรายการเพื่อเก็บไว้"})
    local loot=T.Farming:Section({Title="Fast Loot",Box=true,Opened=true})
    UI.LootToggle=loot:Toggle({Title="Auto Loot",Value=S.AutoLoot,Desc="เก็บของใกล้ตัวด้วย native hold • จำค่าอัตโนมัติ",Callback=function(v)if not S.Ready then return end;F.toggleLoot(v)end})
    loot:Paragraph({Title="Loot status",Desc="เก็บเฉพาะของที่ระบบเกมเลือกได้ และหยุดระหว่างตกปลา"})
    UI.LootStatus=loot:Paragraph({Title="Loot status",Desc="OFF"})
    local med=T.Farming:Section({Title="DX Bandages & Medkit",Box=true,Opened=true})
    UI.MedToggle=med:Toggle({Title="Auto Use DX Bandages / Medkit",Value=S.AutoUseItem,Desc="ใช้ยาตาม HP และ cooldown • จำค่าอัตโนมัติ",Callback=function(v)if not S.Ready then return end;F.toggleMed(v)end})
    med:Dropdown({Title="ชนิดยา",Values={"Both","DX Bandages","Medkit"},Value=S.MedSelection,Callback=function(v)if not S.Ready then return end;S.MedSelection=v;save()end})
    med:Slider({Title="ใช้ยาเมื่อ HP เหลือไม่เกิน (%)",Step=1,Value={Min=5,Max=100,Default=S.MedHealth},Callback=function(v)if not S.Ready then return end;S.MedHealth=v;save()end})
    med:Slider({Title="หน่วงหลังใช้ยาสำเร็จ (วินาที)",Desc="ยังรอ cooldown เกมและผลยืนยันก่อนใช้ซ้ำ",Step=.05,Value={Min=.1,Max=5,Default=S.MedInterval},Callback=function(v)if not S.Ready then return end;S.MedInterval=v;save()end})
    UI.MedStatus=med:Paragraph({Title="Medicine status",Desc="OFF"})
    local advanced=T.Farming:Section({Title="Advanced status & hotkeys",Box=true,Opened=false})
    UI.ActionKeys=advanced:Paragraph({Title="Toggle keys",Desc="Medicine: "..S.MedKey.." • Loot: "..S.LootKey.." • Exit: "..S.ExitKey})
    advanced:Button({Title="Set medicine key",Callback=function()F.captureAction("MedKey","Medicine")end})
    advanced:Button({Title="Set loot key",Callback=function()F.captureAction("LootKey","Loot")end})
    advanced:Button({Title="Retry native module lookup",Callback=function()if S.Ready and not N.loaded then F.loadNative() end end})
    UI.NativeStatus=advanced:Paragraph({Title="Game integration",Desc=N.state})
end

function F.buildDashboard()
    T.Dashboard:Paragraph({
        Title = "Welcome back, " .. LP.DisplayName,
        Desc = "@" .. LP.Name .. "\nShiroNeko Hub: WarZ Shooter Edition",
        Image = "user-round", ImageSize = 24, Color = "White"
    })
    UI.Session = T.Dashboard:Paragraph({Title = "SESSION", Desc = "Starting...", Image = "activity", ImageSize = 20, Color = Color3.fromHex("#1fbf8f")})
    
    local diag = T.Dashboard:Section({Title = "Diagnostics", Box = true, Opened = true})
    UI.Diagnostic = diag:Paragraph({Title = "System Status", Desc = "No errors recorded.", Image = "circle-check", ImageSize = 20})
end

function F.gameReady()
    return LP:GetAttribute("WarzBootReady")==true and LP:GetAttribute("WarzProfileReady")==true
end
-- WarZ reports profile readiness in the Home screen too. Visual camera control must
-- wait for the actual match flag, otherwise it can interfere with the map-loading UI.
function F.inMatch()
    return F.gameReady() and LP:GetAttribute("CSGO_StanceInMatch")==true
end
function F.resetAim()
    S.AimHeld=false; S.AimLatched=false; S.AimTarget=nil; S.AimLastDown=false; S.AimDriver=nil
end
function F.aimInputActive()
    if A.capture or S.CaptureAimKey or S.CaptureMenuKey or not S.InputFocused or UIS:GetFocusedTextBox() then F.resetAim();return false end
    local key=S.AimKey=="Right mouse" and "MouseButton2" or S.AimKey
    local down=false
    if key=="MouseButton2" or key=="MouseButton3" then
        down=UIS:IsMouseButtonPressed(Enum.UserInputType[key])
    else
        local ok,value=pcall(function()return UIS:IsKeyDown(Enum.KeyCode[key])end)
        down=ok and value or false
    end
    if S.AimActivation=="Toggle" and down and not S.AimLastDown then S.AimLatched=not S.AimLatched end
    S.AimLastDown=down
    if S.AimActivation=="Automatic" then return true end
    if S.AimActivation=="Toggle" then return S.AimLatched==true end
    return down
end
function F.targetPart(char)
    if not char then return end
    if S.AimPart=="Body" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head")
end
function F.aimBlockReason()
    if not F.inMatch() then return "Waiting for map (StanceInMatch)" end
    if LP:GetAttribute("WarzDisconnectAt") then return "Exiting map" end
    if LP:GetAttribute("CSGO_Dead")==true then return "Paused: player dead" end
    if LP:GetAttribute("CSGO_ReplayActive")==true then return "Paused: replay" end
    if LP:GetAttribute("CSGO_Paused")==true then return "Paused: game menu" end
    if A.fishing then return "Paused: fishing owns camera" end
    if S.AimRespectUnlock and LP:GetAttribute("CSGO_UiUnlock")==true then return "Paused: UiUnlock=true; close inventory/menu" end
end
function F.sameParty(player)
    local mine=LP:GetAttribute("WarzPartyId")
    return mine~=nil and mine~="" and mine~=0 and mine==player:GetAttribute("WarzPartyId")
end
function F.characterDead(player,char,h)
    return player:GetAttribute("CSGO_Dead")==true or player:GetAttribute("CSGO_DeathLoadout")==true
        or char:GetAttribute("WarzDead")==true or not h or h.Health<=0
end
function F.aimPosition(part)
    local point=part.Position+Vector3.new(0,S.AimOffset,0)
    if S.AimPrediction then
        local char=part.Parent;local r=char and char:FindFirstChild("HumanoidRootPart") or part
        local velocity=r.AssemblyLinearVelocity
        if velocity and velocity.Magnitude<150 then point=point+velocity*S.AimLead end
    end
    return point
end
F.GearPresets={["Guerilla / K. Style"]={["armor"]={["ARMOR_Rebel_Heavy"]=1,["ARMOR_Rebel_Heavy_Blue"]=1,["ARMOR_Rebel_Heavy_Red"]=1},["helmet"]={["HEADHELMET"]=1,["HEADHELMET_Blue"]=1,["HEADHELMET_Red"]=1}},["CITY"]={["armor"]={["ARMOR_CITYSS2FTK"]=1},["helmet"]={["MOTO_CITYSS2FTK"]=1}},["CORSAIR"]={["armor"]={["ARMOR_CLLSJABZFTK"]=1},["helmet"]={["HAND_CLLJABZFTK"]=1}},["Spider-Man"]={["armor"]={["ARMOR_SPIDERMANFTK"]=1},["helmet"]={["MOTO_SPIDERRMANFTK"]=1}},["COMBA / COBBA"]={["armor"]={["ARMOR_COMBAFTK"]=1},["helmet"]={["MOTO_COBBAFTK"]=1}}}
F.GearPresetNames={"กำหนดเอง","Guerilla / K. Style","CITY","CORSAIR","Spider-Man","COMBA / COBBA"}
if S.GearPreset~="กำหนดเอง" and not F.GearPresets[S.GearPreset] then S.GearPreset="กำหนดเอง" end
function F.gearLabel(id)
    if id=="Any" then return "Any" end
    local def=F.EquipmentCatalog[id]
    if not def then return id end
    local value=(def.kind=="Armor" or def.kind=="Helmet") and (" • ค่า "..math.floor(def.value*100+.5)) or ""
    return def.name..value.." ["..id.."]"
end
function F.gearSelection(value)
    if type(value)~="string" or value=="" then return nil end
    return value:match("%[([^%[%]]+)%]$") or value
end
function F.chooseGear(key,value)
    if not S.Ready or A.syncGear then return end
    local id=F.gearSelection(value);if not id then return end
    S[key]=id;S.GearPreset="กำหนดเอง"
    A.syncGear=true
    if UI.GearPreset and type(UI.GearPreset.Select)=="function" then pcall(UI.GearPreset.Select,UI.GearPreset,S.GearPreset) end
    A.syncGear=false;save()
end
function F.chooseGearPreset(value)
    if not S.Ready or A.syncGear or (value~="กำหนดเอง" and not F.GearPresets[value]) then return end
    S.GearPreset=value
    -- A preset controls icons only; ordinary players must retain ordinary ESP.
    S.GearOnly=false
    A.syncGear=true
    if UI.GearOnly and type(UI.GearOnly.Set)=="function" then pcall(UI.GearOnly.Set,UI.GearOnly,false) end
    A.syncGear=false
    save();F.updateESP()
end
function F.gearInfo(char)
    local helmet=char:GetAttribute("WarzHelmetId") or ""
    local armor=char:GetAttribute("WarzArmorId") or ""
    local weapon=char:GetAttribute("WarzPrimarySlotId") or ""
    local matched=(S.GearWeapon=="Any" or weapon==S.GearWeapon) and (S.GearHelmet=="Any" or helmet==S.GearHelmet) and (S.GearArmor=="Any" or armor==S.GearArmor)
    local preset=F.GearPresets[S.GearPreset]
    if preset then matched=preset.armor[armor]~=nil and preset.helmet[helmet]~=nil end
    return helmet,armor,matched,weapon
end
function F.gearOptions(attr,saved)
    local seen={Any=true};local values={"Any"}
    local function add(id)if type(id)=="string" and id~="" and not seen[id] then seen[id]=true;values[#values+1]=id end end
    add(saved)
    for id,def in pairs(F.EquipmentCatalog) do
        if (attr=="WarzArmorId" and def.kind=="Armor") or (attr=="WarzHelmetId" and def.kind=="Helmet")
            or (attr=="WarzPrimarySlotId" and def.kind~="Armor" and def.kind~="Helmet") then add(id) end
    end
    for _,player in ipairs(P:GetPlayers()) do if player.Character then add(player.Character:GetAttribute(attr)) end end
    table.sort(values,function(a,b)if a=="Any" then return b~="Any" elseif b=="Any" then return false end;return a<b end)
    for i,id in ipairs(values) do values[i]=F.gearLabel(id) end
    return values
end
function F.refreshGear()
    if not S.Ready then return end
    A.syncGear=true
    local ok,err=pcall(function()
        for _,row in ipairs({{UI.GearWeapon,"WarzPrimarySlotId","GearWeapon"},{UI.GearHelmet,"WarzHelmetId","GearHelmet"},{UI.GearArmor,"WarzArmorId","GearArmor"}}) do
            local control,attr,key=row[1],row[2],row[3]
            if control and type(control.Refresh)=="function" and type(control.Select)=="function" then
                control:Refresh(F.gearOptions(attr,S[key]));control:Select(F.gearLabel(S[key]))
            end
        end
    end)
    A.syncGear=false
    if not ok then S.LastError="Equipment list: "..tostring(err) end
end
-- Read the same icon catalog as native Stash.lua; no image inferred from screenshots.
function F.loadGearCatalog()
    if F.gearCatalog or F.gearLoading or not S.Run or not S.Ready or not F.inMatch() then return end
    if os.clock()<(F.gearRetryAt or 0) then return end
    F.gearLoading=true;F.gearRetryAt=os.clock()+5
    task.spawn(function()
        local ok,result=pcall(function()
            local module=Shared:FindFirstChild("Config")
            assert(module and module:IsA("ModuleScript"),"Missing Config")
            local catalog=require(module)
            assert(type(catalog.StoreIcon)=="function","StoreIcon unavailable")
            return catalog
        end)
        F.gearLoading=false
        if not S.Run then return end
        if ok then F.gearCatalog=result;safeDesc(UI.GearStatus,"ไอคอน: ปืน / เกราะ / หมวก")
        else safeDesc(UI.GearStatus,"ยังอ่านไอคอนไม่ได้ • แสดงตัวย่อแทน") end
    end)
end
function F.gearIcon(id)
    if id=="" then return "",Color3.new(1,1,1),"—" end
    local catalog=F.gearCatalog
    if not catalog then local def=F.EquipmentCatalog[id];return def and def.icon or "",Color3.new(1,1,1),"?" end
    local ok,asset=pcall(catalog.StoreIcon,id)
    if not ok or type(asset)~="string" or asset=="" then local def=F.EquipmentCatalog[id];asset=def and def.icon or "" end
    local tint=Color3.new(1,1,1)
    if type(catalog.StoreIconTint)=="function" then
        local worked,value=pcall(catalog.StoreIconTint,id)
        if worked and typeof(value)=="Color3" then tint=value end
    end
    return asset,tint,id:sub(1,2):upper()
end
function F.createGearRow(label)
    local frame=Instance.new("Frame");frame.Name="EquipmentIcons"
    frame.BackgroundTransparency=1;frame.Size=UDim2.fromOffset(100,30)
    frame.AnchorPoint=Vector2.new(.5,0);frame.Position=UDim2.new(.5,0,0,60)
    frame.Visible=false;frame.Parent=label
    local slots={}
    for i,name in ipairs({"Weapon","Armor","Helmet"}) do
        local box=Instance.new("Frame");box.Name=name;box.Size=UDim2.fromOffset(30,30)
        box.Position=UDim2.fromOffset((i-1)*35,0);box.BackgroundColor3=Color3.fromRGB(22,19,20)
        box.BackgroundTransparency=.2;box.BorderSizePixel=0;box.Parent=frame
        local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,5);corner.Parent=box
        local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(130,120,125);stroke.Transparency=.3;stroke.Parent=box
        local icon=Instance.new("ImageLabel");icon.Name="Icon";icon.BackgroundTransparency=1
        icon.Position=UDim2.fromOffset(3,3);icon.Size=UDim2.fromOffset(24,24);icon.ScaleType=Enum.ScaleType.Fit;icon.Parent=box
        local fallback=Instance.new("TextLabel");fallback.BackgroundTransparency=1;fallback.Size=UDim2.fromScale(1,1)
        fallback.TextColor3=Color3.new(1,1,1);fallback.TextSize=11;fallback.Font=Enum.Font.GothamBold;fallback.Parent=box
        slots[i]={image=icon,fallback=fallback}
    end
    return frame,slots
end
function F.updateGearRow(row,weapon,armor,helmet,matched)
    row.gear.Visible=S.ESPGear and matched
    if not row.gear.Visible then return end
    for i,id in ipairs({weapon,armor,helmet}) do
        local slot=row.gearSlots[i]
        if slot.id~=id or slot.catalog~=F.gearCatalog then
            local asset,tint,fallback=F.gearIcon(id)
            slot.id=id;slot.catalog=F.gearCatalog;slot.image.Image=asset;slot.image.ImageColor3=tint
            slot.image.Visible=asset~="";slot.fallback.Visible=asset=="";slot.fallback.Text=fallback
        end
    end
end
function F.protectText(player)
    local untilAt=player:GetAttribute("WarzProtectUntil")
    if type(untilAt)~="number" then return "Protect: ไม่ทราบ" end
    local left=untilAt-workspace:GetServerTimeNow()
    return left>0 and string.format("Protect %.1fs",left) or ""
end
-- Client-only player visuals and camera targeting. No shot/remotes are changed.
function F.validTarget(player)
    if player==LP or player.Parent~=P or player:GetAttribute("CSGO_Dead")==true then return end
    if S.TeamCheck and LP.Team~=nil and not LP.Neutral and not player.Neutral and player.Team==LP.Team then return end
    local char=player.Character
    local h=char and char:FindFirstChildOfClass("Humanoid")
    local watch=F.playerWatches[player]
    if not char or (watch and watch.deadCharacter==char) or F.characterDead(player,char,h) then return end
    local part=F.targetPart(char)
    if not h or h.Health<=0 or not part or not part:IsA("BasePart") then return end
    local origin=root();local cam=workspace.CurrentCamera
    if not cam then return end
    local distance=(part.Position-(origin and origin.Position or cam.CFrame.Position)).Magnitude
    if distance>S.VisualDistance then return end
    return char,h,part,distance
end
F.playerWatches={}
function F.unwatchPlayer(player)
    local w=F.playerWatches[player]
    if w then for _,c in ipairs(w.connections) do c:Disconnect() end;for _,c in ipairs(w.characterConnections) do c:Disconnect() end end
    F.playerWatches[player]=nil
end
function F.watchPlayer(player)
    if F.playerWatches[player] then return end
    local w={connections={},characterConnections={}};F.playerWatches[player]=w
    local function clearDead()
        local char=player.Character;local h=char and char:FindFirstChildOfClass("Humanoid")
        if char and F.characterDead(player,char,h) then
            w.deadCharacter=char;F.clearESP(player)
            if S.AimTarget==player then S.AimTarget=nil end
        end
    end
    local function bindCharacter(char)
        for _,c in ipairs(w.characterConnections) do c:Disconnect() end
        w.characterConnections={};w.deadCharacter=nil
        w.characterConnections[#w.characterConnections+1]=char:GetAttributeChangedSignal("WarzDead"):Connect(clearDead)
        local function bindHumanoid(h)
            if h:IsA("Humanoid") then w.characterConnections[#w.characterConnections+1]=h.Died:Connect(clearDead) end
        end
        local h=char:FindFirstChildOfClass("Humanoid");if h then bindHumanoid(h) end
        w.characterConnections[#w.characterConnections+1]=char.ChildAdded:Connect(bindHumanoid)
        -- A missing streamed Humanoid is not proof of death.
        if h and (h.Health<=0 or char:GetAttribute("WarzDead")==true) then clearDead() end
    end
    w.connections[#w.connections+1]=player.CharacterAdded:Connect(bindCharacter)
    w.connections[#w.connections+1]=player.CharacterRemoving:Connect(function()F.clearESP(player);w.deadCharacter=player.Character end)
    w.connections[#w.connections+1]=player:GetAttributeChangedSignal("CSGO_Dead"):Connect(clearDead)
    w.connections[#w.connections+1]=player:GetAttributeChangedSignal("CSGO_DeathLoadout"):Connect(clearDead)
    -- Some game respawns reuse the model; the observed generation is authoritative.
    w.connections[#w.connections+1]=player:GetAttributeChangedSignal("WarzSpawnGeneration"):Connect(function()w.deadCharacter=nil end)
    if player.Character then bindCharacter(player.Character) end
end
function F.clearESP(player)
    local row=S.ESPObjects[player]
    if row then row.highlight:Destroy();row.label:Destroy();S.ESPObjects[player]=nil end
end
function F.updateESP()
    if not S.Run or not S.Ready then return end
    local alive={}
    if S.ESPGear then F.loadGearCatalog() end
    for _,player in ipairs(P:GetPlayers()) do
        local char,h,part,distance=F.validTarget(player)
        local helmet,armor,matched,weapon
        if char then helmet,armor,matched,weapon=F.gearInfo(char) end
        if S.ESP and char and (not S.GearOnly or matched) then
            alive[player]=true
            local row=S.ESPObjects[player]
            if row and row.character~=char then F.clearESP(player);row=nil end
            if not row then
                local highlight=Instance.new("Highlight")
                highlight.Name="PlayerESP";highlight.Adornee=char
                highlight.FillColor=Color3.fromRGB(255,95,105);highlight.FillTransparency=.7
                highlight.OutlineColor=Color3.fromRGB(255,220,220);highlight.Parent=S.VisualFolder
                local label=Instance.new("BillboardGui");label.Name="PlayerLabel"
                label.Size=UDim2.fromOffset(280,100);label.StudsOffset=Vector3.new(0,3,0)
                label.Parent=S.VisualGui
                local text=Instance.new("TextLabel");text.Size=UDim2.fromOffset(280,56)
                text.BackgroundTransparency=1;text.TextColor3=Color3.new(1,1,1)
                text.TextStrokeTransparency=.25;text.TextSize=14;text.Font=Enum.Font.GothamBold
                text.Parent=label
                local gear,gearSlots=F.createGearRow(label)
                row={character=char,highlight=highlight,label=label,text=text,gear=gear,gearSlots=gearSlots};S.ESPObjects[player]=row
            end
            row.highlight.DepthMode=S.ESPThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            row.label.AlwaysOnTop=S.ESPThroughWalls
            row.label.Adornee=char:FindFirstChild("Head") or part
            local lines={string.format("%s%s\nHP %d/%d • %d studs",player.DisplayName,F.sameParty(player) and " [Party]" or "",math.floor(h.Health),math.floor(h.MaxHealth),math.floor(distance))}
            if S.ESPProtect then local t=F.protectText(player);if t~="" then lines[#lines+1]=t end end
            F.updateGearRow(row,weapon,armor,helmet,matched)
            row.text.Text=table.concat(lines,"\n")
        end
    end
    local remove={};for player in pairs(S.ESPObjects) do if not alive[player] then remove[#remove+1]=player end end
    for _,player in ipairs(remove) do F.clearESP(player) end
end
function F.aimCandidate(player,cam,center)
    if S.PartyCheck and F.sameParty(player) then return end
    local char,h,part=F.validTarget(player)
    if not char then return end
    local point,onScreen=cam:WorldToViewportPoint(part.Position)
    if not onScreen or point.Z<=0 then return end
    local pixels=(Vector2.new(point.X,point.Y)-center).Magnitude
    if pixels>S.AimFOV then return end
    if S.AimVisible then
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
        local ignore={cam};if LP.Character then ignore[#ignore+1]=LP.Character end
        params.FilterDescendantsInstances=ignore
        local hit=workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,params)
        if hit and not hit.Instance:IsDescendantOf(char) then return end
    end
    return part,pixels
end
function F.aimStep(dt)
    if not S.Run or not S.Ready then return end
    local cam=workspace.CurrentCamera;if not cam then return end
    local center=cam.ViewportSize/2
    S.AimHeld=F.aimInputActive()
    S.FOVCircle.Visible=S.AimLock and S.ShowFOV and F.inMatch()
    local blocked=F.aimBlockReason()
    if blocked then
        F.resetAim();S.AimReason=blocked;S.FOVCircle.Visible=false;return
    end
    S.AimReason=nil;S.AimDriver=nil
    S.FOVCircle.Position=UDim2.fromOffset(center.X,center.Y)
    S.FOVCircle.Size=UDim2.fromOffset(S.AimFOV*2,S.AimFOV*2)
    local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not S.AimLock or not S.AimHeld or UIS:GetFocusedTextBox() or not h or h.Health<=0 then S.AimTarget=nil;return end
    local target=S.AimTarget
    local part=target and F.aimCandidate(target,cam,center)
    if not part then
        S.AimTarget=nil;local best=S.AimFOV+1
        for _,player in ipairs(P:GetPlayers()) do
            local candidate,pixels=F.aimCandidate(player,cam,center)
            if candidate and pixels<best then best=pixels;part=candidate;S.AimTarget=player end
        end
    end
    if part then
        local aimPoint=F.aimPosition(part)
        local delta=aimPoint-cam.CFrame.Position
        if delta.Magnitude>.01 then
            local alpha=1-math.exp(-S.AimSpeed*math.clamp(dt,0,.1))
            if S.AimMethod=="Auto" or S.AimMethod=="Native" then
                if F.nativeLook(delta,alpha) then S.AimDriver="Native WarZ";return end
                if S.AimMethod=="Native" then S.AimReason="Native look input unavailable or busy";return end
                S.AimReason="Native unavailable; camera fallback"
            end
            local useMouse=S.AimMethod=="Mouse"
            if useMouse then
                if type(mousemoverel)~="function" then S.AimReason="Mouse method unavailable; select Camera";return end
                if UIS.MouseBehavior~=Enum.MouseBehavior.LockCenter then S.AimReason="Mouse method needs locked cursor; select Camera";return end
                local point=cam:WorldToViewportPoint(aimPoint)
                mousemoverel(math.clamp((point.X-center.X)*alpha,-60,60),math.clamp((point.Y-center.Y)*alpha,-60,60))
                S.AimDriver="Mouse"
            else
                S.AimDriver="Camera"
            end
        end
    end
end
function F.buildVisuals()
    local aim=T.Combat:Section({Title="Aim Lock",Box=true,Opened=true})
    aim:Toggle({Title="Enable Aim Lock",Value=S.AimLock,Desc="Hold right mouse to follow a target inside the screen-center circle. Release to stop; Automatic mode tracks without holding a key.",Callback=function(v)if not S.Ready then return end;S.AimLock=v;F.resetAim();save()end})
    aim:Dropdown({Title="Activation",Values={"Hold","Toggle","Automatic"},Value=S.AimActivation,Callback=function(v)if not S.Ready then return end;S.AimActivation=v;F.resetAim();save()end})
    UI.AimKeyStatus=aim:Paragraph({Title="Lock key",Desc=S.AimKey})
    aim:Button({Title="Set lock key",Desc="Click, then press a keyboard key / right or middle mouse. Escape cancels.",Callback=function()
        if not S.Ready then return end
        A.capture=nil;S.CaptureMenuKey=nil;F.resetAim();S.CaptureAimKey=os.clock()+10;safeDesc(UI.AimKeyStatus,"Press a key (10s); Escape cancels")
    end})
    aim:Dropdown({Title="Target part",Values={"Head","Body"},Value=S.AimPart,Callback=function(v)if not S.Ready then return end;S.AimPart=v;F.resetAim();save()end})
    aim:Dropdown({Title="Aim method",Values={"Auto","Native","Camera","Mouse"},Value=S.AimMethod,Callback=function(v)if not S.Ready then return end;S.AimMethod=v;F.resetAim();save()end})
    aim:Toggle({Title="Pause when game unlocks cursor",Value=S.AimRespectUnlock,Desc="Default ON. If status stays UiUnlock=true after closing game menus, turn OFF to test. Home/death/replay remain blocked.",Callback=function(v)if not S.Ready then return end;S.AimRespectUnlock=v;F.resetAim();save()end})
    aim:Slider({Title="Aim radius (pixels)",Step=5,Value={Min=30,Max=500,Default=S.AimFOV},Callback=function(v)if not S.Ready then return end;S.AimFOV=v;save()end})
    aim:Slider({Title="Follow speed",Step=1,Value={Min=1,Max=80,Default=S.AimSpeed},Callback=function(v)if not S.Ready then return end;S.AimSpeed=v;save()end})
    aim:Toggle({Title="Check line of sight",Value=S.AimVisible,Callback=function(v)if not S.Ready then return end;S.AimVisible=v;save()end})
    aim:Toggle({Title="Show aim circle",Value=S.ShowFOV,Callback=function(v)if not S.Ready then return end;S.ShowFOV=v;save()end})
    aim:Toggle({Title="ข้ามคนในปาร์ตี้",Value=S.PartyCheck,Callback=function(v)if not S.Ready then return end;S.PartyCheck=v;F.resetAim();save()end})
    aim:Slider({Title="ชดเชยจุดเล็งสูง–ต่ำ (studs)",Desc="ค่าติดลบเลื่อนลง • เริ่มที่ 0",Step=.05,Value={Min=-3,Max=3,Default=S.AimOffset},Callback=function(v)if not S.Ready then return end;S.AimOffset=v;save()end})
    aim:Toggle({Title="เล็งนำตามความเร็วเป้าหมาย",Value=S.AimPrediction,Callback=function(v)if not S.Ready then return end;S.AimPrediction=v;save()end})
    aim:Slider({Title="เวลาเล็งนำ (วินาที)",Desc="ประมาณจากการเคลื่อนที่ • ไม่ใช่ความเร็วกระสุนอัตโนมัติ",Step=.01,Value={Min=0,Max=.5,Default=S.AimLead},Callback=function(v)if not S.Ready then return end;S.AimLead=v;save()end})
    UI.AimStatus=aim:Paragraph({Title="Aim status",Desc="OFF"})
    local esp=T.Visuals:Section({Title="Player ESP",Box=true,Opened=true})
    esp:Toggle({Title="Enable ESP",Value=S.ESP,Desc="Highlight, display name, health and distance.",Callback=function(v)if not S.Ready then return end;S.ESP=v;F.updateESP();save()end})
    esp:Toggle({Title="Show through walls",Value=S.ESPThroughWalls,Callback=function(v)if not S.Ready then return end;S.ESPThroughWalls=v;save()end})
    esp:Toggle({Title="Skip teammates (ESP + Aim)",Value=S.TeamCheck,Desc="Uses Roblox Teams. Neutral players remain eligible; custom game factions may need additional data.",Callback=function(v)if not S.Ready then return end;S.TeamCheck=v;S.AimTarget=nil;save()end})
    esp:Slider({Title="Maximum distance (ESP + Aim)",Step=50,Value={Min=50,Max=5000,Default=S.VisualDistance},Callback=function(v)if not S.Ready then return end;S.VisualDistance=v;save()end})
    esp:Toggle({Title="แสดงเวลาคงเหลือ Protect",Value=S.ESPProtect,Callback=function(v)if not S.Ready then return end;S.ESPProtect=v;save()end})
    local gear=T.Visuals:Section({Title="Equipment filter",Box=true,Opened=true})
    gear:Toggle({Title="แสดงไอคอนปืน / เกราะ / หมวก",Value=S.ESPGear,Callback=function(v)if not S.Ready then return end;S.ESPGear=v;save()end})
    UI.GearPreset=gear:Dropdown({Title="เลือกเซ็ตสำหรับแสดงไอคอน",Values=F.GearPresetNames,Value=S.GearPreset,Callback=F.chooseGearPreset})
    gear:Paragraph({Title="เงื่อนไขเซ็ต",Desc="ตรงทั้งเกราะและหมวก • ใช้ปืนอะไรก็ได้ • คนอื่นยังมี ESP ปกติ"})
    UI.GearWeapon=gear:Dropdown({Title="ปืน (กำหนดเอง)",Values=F.gearOptions("WarzPrimarySlotId",S.GearWeapon),Value=F.gearLabel(S.GearWeapon),Callback=function(v)F.chooseGear("GearWeapon",v)end})
    UI.GearHelmet=gear:Dropdown({Title="หมวก (กำหนดเอง)",Values=F.gearOptions("WarzHelmetId",S.GearHelmet),Value=F.gearLabel(S.GearHelmet),Callback=function(v)F.chooseGear("GearHelmet",v)end})
    UI.GearArmor=gear:Dropdown({Title="เกราะ (กำหนดเอง)",Values=F.gearOptions("WarzArmorId",S.GearArmor),Value=F.gearLabel(S.GearArmor),Callback=function(v)F.chooseGear("GearArmor",v)end})
    UI.GearOnly=gear:Toggle({Title="แสดง ESP เฉพาะเซ็ตที่เลือก",Desc="ต้องตรงทุกช่องที่เลือก • Any คือไม่จำกัดช่องนั้น",Value=S.GearOnly,Callback=function(v)if not S.Ready or A.syncGear then return end;S.GearOnly=v;save()end})
    gear:Button({Title="อัปเดตรายการจากคนในเซิร์ฟเวอร์",Callback=F.refreshGear})
    UI.GearStatus=gear:Paragraph({Title="Equipment icons",Desc="ปืน / เกราะ / หมวก • เปิดสวิตช์เพื่อแสดง"})
    gear:Paragraph({Title="รายการอุปกรณ์",Desc="แค็ตตาล็อกจากดัมพ์ + อุปกรณ์ที่พบในเซิร์ฟเวอร์ • เลือกรายชิ้นจะเปลี่ยนเป็นกำหนดเอง"})

end
function F.startVisuals()
    S.VisualFolder=Instance.new("Folder");S.VisualFolder.Name="ShiroNekoShooterVisuals";S.VisualFolder.Parent=workspace
    S.VisualGui=Instance.new("ScreenGui");S.VisualGui.Name="ShiroNekoShooterOverlay"
    S.VisualGui.IgnoreGuiInset=true;S.VisualGui.ResetOnSpawn=false;S.VisualGui.Parent=LP:FindFirstChild("PlayerGui")
    local circle=Instance.new("Frame");circle.AnchorPoint=Vector2.new(.5,.5);circle.BackgroundTransparency=1;circle.Visible=false;circle.Parent=S.VisualGui
    local round=Instance.new("UICorner");round.CornerRadius=UDim.new(1,0);round.Parent=circle
    local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(100,220,255);stroke.Thickness=1;stroke.Parent=circle
    S.FOVCircle=circle
    S.Conns[#S.Conns+1]=UIS.InputBegan:Connect(function(input)
        if not S.Run or not S.Ready or UIS:GetFocusedTextBox() then return end
        if S.CaptureMenuKey then
            if input.KeyCode==Enum.KeyCode.Escape or os.clock()>S.CaptureMenuKey then S.CaptureMenuKey=nil;safeDesc(UI.MenuKeyStatus,"Current: "..S.MenuBind);return end
            if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode~=Enum.KeyCode.Unknown then
                local key=input.KeyCode.Name
                if key=="Unknown" or F.keyUsed(key,"MenuBind") then return notify("UI key","เลือกปุ่มที่ยังไม่ถูกใช้") end
                S.MenuBind=key;S.CaptureMenuKey=nil
                pcall(function()Window:SetToggleKey(Enum.KeyCode[key])end)
                save();safeDesc(UI.MenuKeyStatus,"Current: "..key);return
            end
            return
        end
        if not S.CaptureAimKey then return end
        if os.clock()>S.CaptureAimKey or input.KeyCode==Enum.KeyCode.Escape then
            S.CaptureAimKey=nil;safeDesc(UI.AimKeyStatus,S.AimKey);return
        end
        local key
        if input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3 then key=input.UserInputType.Name
        elseif input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode~=Enum.KeyCode.Unknown then key=input.KeyCode.Name end
        if not key then return end
        if F.keyUsed(key,"AimKey") then safeDesc(UI.AimKeyStatus,"Key already used by hub, medicine or loot");return end
        S.AimKey=key;S.CaptureAimKey=nil;F.resetAim();S.AimLastDown=true;save();safeDesc(UI.AimKeyStatus,key)
    end)
    S.Conns[#S.Conns+1]=UIS.WindowFocusReleased:Connect(function()S.InputFocused=false;F.resetAim()end)
    S.Conns[#S.Conns+1]=UIS.WindowFocused:Connect(function()S.InputFocused=true end)
    S.Conns[#S.Conns+1]=P.PlayerRemoving:Connect(function(player)F.clearESP(player);F.unwatchPlayer(player);if S.AimTarget==player then S.AimTarget=nil end end)
    for _,player in ipairs(P:GetPlayers()) do F.watchPlayer(player) end
    S.Conns[#S.Conns+1]=P.PlayerAdded:Connect(F.watchPlayer)
    Run:BindToRenderStep(S.VisualBinding,Enum.RenderPriority.Last.Value-3,function(dt)
        local ok,err=pcall(function()
            F.clearNativeLook()
            if A.fishing and A.phase=="Aligning water" and A.water and F.inMatch() and S.InputFocused and not UIS:GetFocusedTextBox() then
                local cam=workspace.CurrentCamera
                if cam then F.nativeLook(A.water-cam.CFrame.Position,1-math.exp(-12*math.clamp(dt,0,.1))) end
            end
            F.aimStep(dt)
        end);if not ok then S.AimTarget=nil;S.LastError="Aim: "..tostring(err) end
    end)
    S.AimPostBinding="ShiroNekoShooterAimPost_"..game:GetService("HttpService"):GenerateGUID(false)
    Run:BindToRenderStep(S.AimPostBinding,Enum.RenderPriority.Last.Value+1,function(dt)
        if not S.Run or not S.Ready or not S.AimLock or not S.AimTarget or not S.AimHeld or S.AimDriver~="Camera" or F.aimBlockReason() then return end
        local cam=workspace.CurrentCamera;local part=cam and F.aimCandidate(S.AimTarget,cam,cam.ViewportSize/2)
        if not cam or not part then return end
        local alpha=1-math.exp(-S.AimSpeed*math.clamp(dt,0,.1))
        cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position,F.aimPosition(part)),alpha)
    end)
    local elapsed=0
    S.Conns[#S.Conns+1]=Run.Heartbeat:Connect(function(dt)
        elapsed=elapsed+dt;if elapsed<.05 then return end;elapsed=0
        if S.CaptureMenuKey and os.clock()>S.CaptureMenuKey then S.CaptureMenuKey=nil;safeDesc(UI.MenuKeyStatus,"Current: "..S.MenuBind) end
        if S.CaptureAimKey and os.clock()>S.CaptureAimKey then S.CaptureAimKey=nil;safeDesc(UI.AimKeyStatus,S.AimKey) end
        local ok,err=pcall(F.updateESP);if not ok then S.LastError="ESP: "..tostring(err) end
        if os.clock()-(A.gearRefreshAt or 0)>5 then A.gearRefreshAt=os.clock();F.refreshGear() end
        safeDesc(UI.AimStatus,not S.AimLock and "OFF" or S.AimReason or S.AimTarget and ("Tracking "..S.AimTarget.DisplayName.." / "..(S.AimDriver or "Camera")) or S.AimHeld and "No eligible player in aim circle" or ((S.AimActivation=="Toggle" and "Press " or "Hold ")..S.AimKey.." to lock"))
    end)
end

function F.buildCombat()
    F.buildVisuals()
    local gunSec = T.Combat:Section({Title = "Gun Actions", Box = true, Opened = true})
    gunSec:Button({Title = "Combine Mags (Manual)", Icon = "refresh-cw", Callback = function() if not S.Ready then return end; fireRemote("CombineMags") end})
    gunSec:Toggle({Title = "Auto Combine Mags", Value = S.AutoCombineMags, Callback = function(v) if not S.Ready then return end; S.AutoCombineMags = v; save() end})

    local gunAdvanced = T.Combat:Section({Title = "Gun Mods (Advanced)", Box = true, Opened = false})
    gunAdvanced:Toggle({Title="ลดแรงดีดกล้อง",Value=S.NoRecoil,Callback=function(v)if not S.Ready then return end;S.NoRecoil=v;F.applyGunMods();save()end})
    gunAdvanced:Slider({Title="ลดแรงดีด (%)",Step=5,Value={Min=0,Max=100,Default=S.RecoilReduction},Callback=function(v)if not S.Ready then return end;S.RecoilReduction=v;save()end})
    gunAdvanced:Toggle({Title="ลดกระจายฝั่งไคลเอนต์",Value=S.NoSpread,Callback=function(v)if not S.Ready then return end;S.NoSpread=v;F.applyGunMods();save()end})
    gunAdvanced:Slider({Title="ลดกระจาย (%)",Step=5,Value={Min=0,Max=100,Default=S.SpreadReduction},Callback=function(v)if not S.Ready then return end;S.SpreadReduction=v;save()end})
    UI.GunStatus=gunAdvanced:Paragraph({Title="Gun integration",Desc="OFF • ผลโดนเป้าหมายยังขึ้นกับเซิร์ฟเวอร์"})

    local hitSec = T.Combat:Section({Title = "Hitbox Expander", Box = true, Opened = true})
    hitSec:Toggle({Title = "Enable Expander", Value = S.ExpandHitbox, Desc = "Modifies WarzHitboxConfig", Callback = function(v) if not S.Ready then return end; S.ExpandHitbox = v; save() end})
    hitSec:Slider({Title = "Hitbox Size", Step = 1, Value = {Min = 2, Max = 15, Default = S.HitboxSize}, Callback = function(v) if not S.Ready then return end; S.HitboxSize = v; save() end})
end

function F.buildSettings()
    local perfSec = T.Settings:Section({Title = "Interface & Binds", Box = true, Opened = true})
    perfSec:Dropdown({Title = "Theme", Values = {"Dark", "Light"}, Value = S.Theme, Callback = function(v) if not S.Ready then return end; WindUI:SetTheme(v); S.Theme = v; save() end})
    perfSec:Slider({Title = "Transparency", Step = 0.05, Value = {Min = 0, Max = 0.8, Default = S.Transparency}, Callback = function(v) if not S.Ready then return end; 
        S.Transparency = v; Window:SetBackgroundTransparency(v); Window:SetBackgroundImageTransparency(v); save() 
    end})
    UI.MenuKeyStatus=perfSec:Paragraph({Title="UI toggle key",Desc="Current: "..S.MenuBind})
    perfSec:Button({Title="Set UI open / close key",Desc="กดปุ่มนี้แล้วกดคีย์ใหม่ ค่าจะบันทึกและใช้เปิด/ปิดฮับตลอด",Callback=function()
        if not S.Ready then return end
        A.capture=nil;S.CaptureAimKey=nil;F.resetAim();S.CaptureMenuKey=os.clock()+10;safeDesc(UI.MenuKeyStatus,"Press a keyboard key within 10s; Escape cancels")
    end})
    
    local exit=T.Settings:Section({Title="Exit map",Box=true,Opened=true})
    exit:Button({Title="ออกจากแมพ",Desc="ใช้ Exit ของเกม • ไม่ลดเวลานับถอยหลังของเซิร์ฟเวอร์",Callback=F.requestExit})
    exit:Button({Title="ตั้งคีย์ลัด Exit",Callback=function()F.captureAction("ExitKey","Exit")end})
    UI.ExitStatus=exit:Paragraph({Title="Exit key",Desc=S.ExitKey})
    local player = T.Settings:Section({Title = "Player Movement", Box = true, Opened = true})
    player:Toggle({Title = "Anti-AFK", Value = S.AntiAFK, Callback = function(v) if not S.Ready then return end; S.AntiAFK = v; save() end})
    player:Toggle({Title = "Custom Walk Speed", Value = S.Walk, Callback = function(v) if not S.Ready then return end; S.Walk = v; save() end})
    player:Slider({Title = "Walk Speed", Step = 1, Value = {Min = 16, Max = 150, Default = S.WalkSpeed}, Callback = function(v) if not S.Ready then return end; S.WalkSpeed = v; save() end})
    player:Toggle({Title = "Fly", Value = S.Fly, Callback = function(v) if not S.Ready then return end; S.Fly = v; if not v then F.stopFly() end; save() end})

    T.Settings:Button({Title="Stop All Automation",Callback=function()if S.Ready then F.stopAllAutomation();notify("Automation","Fishing, loot and medicine stopped") end end})
    T.Settings:Button({Title="Save Config",Callback=function()if S.Ready then writeConfig();notify("Config","Saved preferences") end end})
    T.Settings:Button({Title = "Stop All & Close", Color = Color3.fromHex("#a83245"), Callback = function() if not S.Ready then return end; F.unload() end})
end

-- ==========================================
-- RUNTIME WORKERS
-- ==========================================

function F.flyStep()
    local r, h, c = root(), LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"), workspace.CurrentCamera
    if not r or not h or not c then return end
    if S.FlyRoot ~= r or not S.FlyBV or not S.FlyBV.Parent then
        F.stopFly()
        local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Parent = r
        local bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 90000; bg.Parent = r
        S.FlyBV, S.FlyBG, S.FlyRoot = bv, bg, r
    end
    h.PlatformStand = true
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + c.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - c.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + c.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - c.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d = d - Vector3.yAxis end
    S.FlyBV.Velocity = d.Magnitude > 0 and d.Unit * S.FlySpeed or Vector3.zero
end

function F.stopFly()
    if S.FlyBV then pcall(function() S.FlyBV:Destroy() end) end
    if S.FlyBG then pcall(function() S.FlyBG:Destroy() end) end
    S.FlyBV = nil; S.FlyBG = nil; S.FlyRoot = nil
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand = false end
end

function F.unload()
    if not S.Run then return end
    F.restoreGunMods()
    for player in pairs(F.playerWatches) do F.unwatchPlayer(player) end
    F.pauseFishing("Unloaded")
    A.med=false;A.loot=false;A.capture=nil
    if N.Loot and A.lootOwned then pcall(N.Loot.SetTouchHeld,false);A.lootOwned=false end
    F.clearNativeLook()
    S.Run = false; S.Ready = false
    S.AimHeld=false;S.AimTarget=nil
    pcall(function()Run:UnbindFromRenderStep(S.VisualBinding)end)
    pcall(function()if S.AimPostBinding then Run:UnbindFromRenderStep(S.AimPostBinding) end end)
    if S.VisualFolder then S.VisualFolder:Destroy() end
    if S.VisualGui then S.VisualGui:Destroy() end
    table.clear(S.ESPObjects)
    if ENV.ShiroNekoShooter and ENV.ShiroNekoShooter.Unload==F.unload then ENV.ShiroNekoShooter=nil end
    boot.Cancelled = true
    F.stopFly()
    for _, c in ipairs(S.Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() Window:Destroy() end)
    if ownsBoot() then ENV.ShiroNekoShooterBoot = nil end
end

-- Core Builder Execution
local built, err = xpcall(function()
    local builders = {
        {"Dashboard", F.buildDashboard}, {"Combat", F.buildCombat},
        {"Farming", F.buildFarming}, {"Settings", F.buildSettings}
    }
    for _, entry in ipairs(builders) do
        boot.Phase = "Building " .. entry[1]
        entry[2](); task.wait()
    end
    T.Dashboard:Select()
end, debug.traceback)

if not built then warn("[ShiroNeko] Build Error: " .. tostring(err)); F.unload(); return end

task.wait() -- allow construction callbacks to finish before new controls become active
S.Ready = true
F.applyGunMods()
ENV.ShiroNekoShooter={Unload=F.unload,Version="1.1.16",IsAlive=function() return S.Run==true end}
-- Restore saved feature toggles only after the map is actually playable.  This
-- keeps config persistence without firing automation during UI construction.
task.spawn(function()
    local untilAt=os.clock()+90
    repeat task.wait(.5) until not S.Run or F.inMatch() or os.clock()>untilAt
    if not S.Run or not F.inMatch() then return end
    if S.AutoLoot and not A.loot then F.toggleLoot() end
    if S.AutoUseItem and not A.med then F.toggleMed() end
end)
local visualsOK,visualsError=pcall(function()F.startVisuals();F.startSurvival()end)
if not visualsOK then warn("[ShiroNeko] Visual startup: "..tostring(visualsError));F.unload();return end
boot.Phase = "Ready"
if ownsBoot() then ENV.ShiroNekoShooterBoot=nil end

-- Loops and Background Tasks
task.spawn(function()
    while S.Run do
        local now = os.clock()
        
        -- Auto Ready
        if S.SessionAutomation and F.inMatch() and S.AutoReady and now - (S.LastCalls.Ready or 0) > 3 then
            S.LastCalls.Ready = now
            fireRemote("SetReady", true)
        end
        
        -- Auto Start Match
        if S.SessionAutomation and F.inMatch() and S.AutoStartMatch and now - (S.LastCalls.StartMatch or 0) > 5 then
            S.LastCalls.StartMatch = now
            fireRemote("RequestStartMatch")
        end
        
        -- Auto Combine Mags
        if S.SessionAutomation and F.inMatch() and S.AutoCombineMags and now - (S.LastCalls.Combine or 0) > 10 then
            S.LastCalls.Combine = now
            fireRemote("CombineMags")
        end

        -- UI Updates
        local elapsed = math.floor(os.clock() - S.StartClock)
        local hh, mm, ss = math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60
        safeDesc(UI.Session, string.format("%02d:%02d:%02d • WarZ Shooter Edition\nPlayers: %d", hh, mm, ss, #P:GetPlayers()))
        safeDesc(UI.Diagnostic, S.LastError and ("Error: " .. S.LastError) or "Running smoothly.")
        
        task.wait(1)
    end
end)

S.Conns[#S.Conns+1] = Run.Stepped:Connect(function()
    if not S.Run then return end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h and S.SessionAutomation and F.inMatch() and S.Walk then h.WalkSpeed = S.WalkSpeed end
    if S.SessionAutomation and F.inMatch() and S.Fly then F.flyStep() end
end)

S.Conns[#S.Conns+1] = LP.Idled:Connect(function()
    if S.SessionAutomation and F.inMatch() and S.AntiAFK then
        local VU = game:GetService("VirtualUser")
        pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.zero) end)
    end
end)

notify("ShiroNeko Hub", "Loaded successfully for WarZ Shooter! Aim waits for Match state.")
end)()
