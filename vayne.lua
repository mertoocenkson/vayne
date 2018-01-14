require 'DamageLib'
require '2DGeometry'
require 'MapPositionGOS'
require 'Collision'

if FileExist(COMMON_PATH .. "RomanovPred.lua") then
	require 'RomanovPred'
end

local Version = "v2.0"
--- Engine ---
local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function MinionsAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function HeroesAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team == team and not hero.dead and hero.pos:DistanceTo(pos, hero.pos) < range then
			Count = Count + 1
		end
	end
	return Count
end

local function GetDistance(p1,p2)
    local p2 = p2 or myHero.pos
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

local function GetDistance2D(p1,p2)
    local p2 = p2 or myHero
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function GetTarget(range)
	local target = nil
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = GOS:GetTarget(range)
	end
	return target
end

local function GetMode()
	if _G.EOWLoaded then
		if EOW.CurrentMode == 1 then
			return "Combo"
		elseif EOW.CurrentMode == 2 then
			return "Harass"
		elseif EOW.CurrentMode == 3 then
			return "Lasthit"
		elseif EOW.CurrentMode == 4 then
			return "Clear"
		end
	elseif _G.SDK and _G.SDK.Orbwalker then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"	
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "Lasthit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_NONE] then
			return "None"
		end
	else
		return GOS.GetMode()
	end
end

local function EnableOrb(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif _G.SDK.Orbwalker then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end

local function ForceTarget(target)
	if _G.EOWLoaded then
		EOW:ForceTarget(target)
	elseif _G.SDK.Orbwalker then
		_G.SDK.Orbwalker.ForceTarget = target	
	else
		_G.GOS.ForceTarget = target
	end		
end

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local function NoPotion()
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end

local function isOnScreen(obj)
	return obj.pos:To2D().onScreen;
end
--- Engine ---

--- Predictions ---
-- Romanov --
function RomanovCast(hotkey,slot,target,from)
	local pred = RomanovPredPos(from,target,slot.speed,slot.delay,slot.width)
	if RomanovHitchance(from,target,slot.speed,slot.delay,slot.range,slot.width) >= 2 then
		EnableOrb(false)
		Control.CastSpell(hotkey, pred)
		DelayAction(function() EnableOrb(true) end, 0.25)
	end
end
-- Romanov --
--- Predictions

--- Vayne ---
class "Vayne"

local VayneVersion = "v1.00"

function Vayne:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Vayne:LoadSpells()
	Q = { range = 850, delay = 0.25, cost = 30, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/8d/Tumble.png" }
	W = { icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/12/Silver_Bolts.png" }
    E = { range = 550, delay = 0.25, cost = 90, speed = 500, width = myHero:GetSpellData(_E).width, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/66/Condemn.png" }
	R = { range = 1200, delay = 0.25, cost = 80, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b4/Final_Hour.png" }
end

function Vayne:LoadMenu()
	RomanovVayne = MenuElement({type = MENU, id = "RomanovVayne", name = "Romanov's Signature "..Version})
	--- Version ---
	RomanovVayne:MenuElement({name = "Vayne", drop = {VayneVersion}, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b0/Vayne_OriginalCircle.png"})
	--- Combo ---
	RomanovVayne:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
    RomanovVayne.Combo:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
    RomanovVayne.Combo:MenuElement({id = "Dist", name = "[Q] Secure Min Dist", value = 400, min = 0, max = 550})
	RomanovVayne.Combo:MenuElement({id = "W", name = "Focus [W] target", value = true, leftIcon = W.icon})
	RomanovVayne.Combo:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovVayne.Combo:MenuElement({id = "R", name = "Use [R]", value = true, leftIcon = R.icon})
    RomanovVayne.Combo:MenuElement({id = "X", name = "[R] Enemies", value = 3, min = 1, max = 5})
    --- Clear ---
	RomanovVayne:MenuElement({type = MENU, id = "Clear", name = "Clear Settings"})
	RomanovVayne.Clear:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("A"), toggle = true})
    RomanovVayne.Clear:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
    RomanovVayne.Clear:MenuElement({id = "E", name = "Use [E] jungle", value = true, leftIcon = E.icon})
    RomanovVayne.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear [%]", value = 0, min = 0, max = 100})
    RomanovVayne.Clear:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
	--- Harass ---
	RomanovVayne:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
	RomanovVayne.Harass:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("S"), toggle = true})
    RomanovVayne.Harass:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
    RomanovVayne.Harass:MenuElement({id = "Dist", name = "[Q] Secure Min Dist", value = 450, min = 0, max = 550})
	RomanovVayne.Harass:MenuElement({id = "W", name = "Focus [W] target", value = true, leftIcon = W.icon})
    RomanovVayne.Harass:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovVayne.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass [%]", value = 0, min = 0, max = 100})
    RomanovVayne.Harass:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
    --- Flee ---
    RomanovVayne:MenuElement({type = MENU, id = "Flee", name = "Flee Settings"})
    RomanovVayne.Flee:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovVayne.Flee:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
	--- Interrupter ---
    RomanovVayne:MenuElement({type = MENU, id = "Interrupter", name = "Interrupter Settings"})
	RomanovVayne.Interrupter:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
	--- Antigapclose ---
    RomanovVayne:MenuElement({type = MENU, id = "Antigapclose", name = "Antigapcloser Settings"})
	RomanovVayne.Antigapclose:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
	--- Draw ---
	RomanovVayne:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
	RomanovVayne.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", value = true, leftIcon = Q.icon})
	RomanovVayne.Draw:MenuElement({id = "CT", name = "Clear Toggle", value = true})
	RomanovVayne.Draw:MenuElement({id = "HT", name = "Harass Toggle", value = true})
end

function Vayne:Tick()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Clear" then
		self:Clear()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
		self:Interrupter()
		self:Antigapclose()
end

function Vayne:Codemn(target)
    local vec = Vector(target.pos) - Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * -425
    if MapPosition:intersectsWall(LineSegment(target,vec)) and GetDistance(target.pos) < 550 then
		Control.CastSpell(HK_E, target)
    end
end

function Vayne:Interrupter()
	if RomanovVayne.Interrupter.E:Value() and Ready(_E) then
		for i=1, Game.HeroCount() do
        	local target = Game.Hero(i)      
        	if target and target.isEnemy and not target.dead and GetDistance(target.pos) < 550 then
				if RomanovHitchance(myHero,target,E.speed,E.delay,E.range,E.width) == 6 then
					Control.CastSpell(HK_E, target)
				end
			end
        end
    end
end

function Vayne:Antigapclose()
	if RomanovVayne.Antigapclose.E:Value() and Ready(_E) then
		for i=1, Game.HeroCount() do
        	local target = Game.Hero(i)      
			if target and target.isEnemy and not target.dead and GetDistance(target.pos) < E.range then
				if target.pathing.isDashing and GetDistance(target.pathing.endPos) < 300 then
					Control.CastSpell(HK_E, target)
				end
			end
        end
    end
end

function Vayne:Mark(target)
    for i = 1, target.buffCount do
        local buff = target:GetBuff(i)
		if buff and buff.name:lower() == "vaynesilvereddebuff" and buff.expireTime > 0 then
			return buff.count
		end
	end
end

function Vayne:Focus()
    for i=1, Game.HeroCount() do
        local target = Game.Hero(i)      
        if target and target.isEnemy and not target.dead and GetDistance(target.pos) < 550 then
            if self:Mark(target) == 2 then
                ForceTarget(target)
            end
        end
    end
end

function Vayne:Combo()
	local target = GetTarget(850)
    if target == nil then return end
    
    if RomanovVayne.Combo.R:Value() and Ready(_R) and GetDistance(target.pos) < 850 and HeroesAround(1200) >= RomanovVayne.Combo.X:Value() then
        Control.CastSpell(HK_R)
    end
    --[[if RomanovVayne.Combo.W:Value() then
        self:Focus()
    end]]
    if RomanovVayne.Combo.E:Value() and Ready(_E) and GetDistance(target.pos) < 550 then
        self:Codemn(target)
    end
    if GetDistance(target.pos) < myHero.range and myHero.attackData.state ~= STATE_WINDDOWN then return end
    if RomanovVayne.Combo.Q:Value() and Ready(_Q) and GetDistance(target.pos) < Q.range then
		local vec = Vector(myHero.pos):Extended(Vector(mousePos), 300)
        if GetDistance(vec,target.pos) < myHero.range and GetDistance(vec,target.pos) >= RomanovVayne.Combo.Dist:Value() then
            Control.CastSpell(HK_Q,vec)
        end
    end
end

function Vayne:Harass()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	local target = GetTarget(Q.range)
	if target == nil then return end
    if RomanovVayne.Harass.Key:Value() == false then return end
	if PercentMP(myHero) < RomanovVayne.Harass.Mana:Value() and not (blue and RomanovVayne.Harass.Ignore:Value()) then return end
    
    --[[if RomanovVayne.Harass.W:Value() then
        self:Focus()
    end]]
    if RomanovVayne.Harass.E:Value() and Ready(_E) and GetDistance(target.pos) < 550 then
        self:Codemn(target)
    end
    if GetDistance(target.pos) < myHero.range and myHero.attackData.state ~= STATE_WINDDOWN then return end
    if RomanovVayne.Harass.Q:Value() and Ready(_Q) and GetDistance(target.pos) < Q.range then
		local vec = Vector(myHero.pos):Extended(Vector(mousePos), 300)
        if GetDistance(vec,target.pos) < myHero.range and GetDistance(vec,target.pos) >= RomanovVayne.Harass.Dist:Value() then
            Control.CastSpell(HK_Q,vec)
        end
    end
end

function Vayne:Clear()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
    if RomanovVayne.Clear.Key:Value() == false then return end
    if myHero.mana/myHero.maxMana < RomanovVayne.Clear.Mana:Value() and not (blue and RomanovVayne.Clear.Ignore:Value()) then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if GetDistance(minion.pos) < myHero.range and myHero.attackData.state ~= STATE_WINDDOWN then return end
		if minion and minion.team == 300 - myHero.team then
			if RomanovVayne.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < Q.range then
                    Control.CastSpell(HK_Q, Game.cursorPos())
                end
			end
		elseif minion and minion.team == 300 then
            if RomanovVayne.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < Q.range then
                    Control.CastSpell(HK_Q, Game.cursorPos())
                end
			end
			if RomanovVayne.Clear.E:Value() and Ready(_E) and GetDistance(minion.pos) < E.range then
                if GetDistance(minion.pos) < E.range then
                    self:Codemn(minion)
                end
			end
		end
	end
end

function Vayne:Flee()
	local target = GetTarget(Q.range)

    if target and RomanovVayne.Flee.E:Value() and Ready(_E) and GetDistance(target.pos) < E.range then
		Control.CastSpell(HK_E, target)
    end
    if RomanovVayne.Flee.Q:Value() and Ready(_Q) then
		Control.CastSpell(HK_Q, Game.cursorPos())
    end
end

function Vayne:Draw()
	if RomanovVayne.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, 850, 3,  Draw.Color(255,000, 075, 180)) end
	if RomanovVayne.Draw.CT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovVayne.Clear.Key:Value() then
			Draw.Text("Clear: On", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if RomanovVayne.Draw.HT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovVayne.Harass.Key:Value() then
			Draw.Text("Harass: On", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
end
--- Vayne ---

--- Utility ---
class "Utility"

function Utility:__init()
	self:Menu()
	Callback.Add("Tick", function() self:Tick() end)
end

function Utility:Menu()
	RomanovVayne:MenuElement({type = MENU, id = "Leveler", name = "Auto Leveler Settings"})
	RomanovVayne.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
	RomanovVayne.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
	RomanovVayne.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 1, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

	RomanovVayne:MenuElement({type = MENU, id = "Activator", name = "Activator Settings"})
	RomanovVayne.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RomanovVayne.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RomanovVayne.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RomanovVayne.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RomanovVayne.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RomanovVayne.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RomanovVayne.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RomanovVayne.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RomanovVayne.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RomanovVayne.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RomanovVayne.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RomanovVayne.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RomanovVayne.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RomanovVayne.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RomanovVayne.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RomanovVayne.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RomanovVayne.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RomanovVayne.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RomanovVayne.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RomanovVayne.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RomanovVayne.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RomanovVayne.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RomanovVayne.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RomanovVayne.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RomanovVayne.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RomanovVayne.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RomanovVayne.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RomanovVayne.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RomanovVayne.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RomanovVayne.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RomanovVayne.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end
end

function Utility:Tick()
	self:AutoLevel()
	self:Activator()
end

function Utility:AutoLevel()
	if RomanovVayne.Leveler.Enabled:Value() == false then return end
	local Sequence = {
	[1] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
	[2] = { HK_Q, HK_E, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
	[3] = { HK_W, HK_Q, HK_E, HK_W, HK_W, HK_R, HK_W, HK_Q, HK_W, HK_Q, HK_R, HK_Q, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_E },
	[4] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_E, HK_W, HK_E, HK_R, HK_E, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
	[5] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_Q, HK_E, HK_Q, HK_R, HK_Q, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_W },
	[6] = { HK_E, HK_W, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
	}
	local Slot = nil
	local Tick = 0
	local SkillPoints = myHero.levelData.lvlPts
	local level = myHero.levelData.lvl
	local Check = Sequence[RomanovVayne.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RomanovVayne.Leveler.Block:Value() and level == 1 then return end
		if GetTickCount() - Tick > 800 and Check ~= nil then
			Control.KeyDown(HK_LUS)
			Control.KeyDown(Check)
			Slot = Check
			Tick = GetTickCount()
		end
	end
	if Control.IsKeyDown(HK_LUS) then
		Control.KeyUp(HK_LUS)
	end
	if Slot and Control.IsKeyDown(Slot) then
		Control.KeyUp(Slot)
	end
end

function Utility:Activator()
	local target = GetTarget(1575)
	if target == nil then return end
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Banner = items[3060]
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RomanovVayne.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RomanovVayne.Activator.P.Pot:Value() and PercentHP(myHero) < RomanovVayne.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RomanovVayne.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RomanovVayne.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RomanovVayne.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RomanovVayne.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RomanovVayne.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RomanovVayne.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RomanovVayne.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovVayne.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovVayne.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RomanovVayne.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovVayne.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovVayne.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		if target then
			for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i);
				if buff.count > 0 then
					if ((buff.type == 5 and RomanovVayne.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RomanovVayne.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RomanovVayne.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RomanovVayne.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RomanovVayne.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RomanovVayne.Activator.CS.Root:Value())
					or (buff.type == 21 and  RomanovVayne.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RomanovVayne.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RomanovVayne.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RomanovVayne.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RomanovVayne.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RomanovVayne.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RomanovVayne.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RomanovVayne.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RomanovVayne.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RomanovVayne.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RomanovVayne.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RomanovVayne.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RomanovVayne.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RomanovVayne.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RomanovVayne.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RomanovVayne.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RomanovVayne.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RomanovVayne.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RomanovVayne.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RomanovVayne.Activator.S.Smite:Value() then
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovVayne.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovVayne.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovVayne.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovVayne.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RomanovVayne.Activator.S.Ignite:Value() then
				local IgDamage = 70 + 20 * myHero.levelData.lvl
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
end
--- Utility ---

Callback.Add("Load", function()
	if _G[myHero.charName] then
		_G[myHero.charName]()
		Utility()
		print("Romanov Repository "..Version..": "..myHero.charName.." Loaded")
		print("PM me for suggestions/fix problems")
		print("Discord: Romanov#6333")
	else print ("Romanov Repository doens't support "..myHero.charName.." shutting down...") return
	end
end)
