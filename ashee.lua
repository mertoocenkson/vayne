
local ScriptVersion = "v1.0"
--- Engine ---
local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function EnemiesAround(pos, range, team)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local m = Game.Hero(i)
		if m and m.team == 200 and not m.dead and m.pos:DistanceTo(pos, m.pos) < 125 then
			Count = Count + 1
		end
	end
	return Count
end

local function AlliesAround(pos, range, team)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local m = Game.Hero(i)
		if m and m.team == 100 and not m.dead and m.pos:DistanceTo(pos, m.pos) < 600 then
			Count = Count + 1
		end
	end
	return Count
end

local function GetDistance(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

local function GetDistance2D(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function GetTarget(range)
	local target = nil
	if Orb == 1 then
		target = EOW:GetTarget(range)
	elseif Orb == 2 then
		target = _G.SDK.TargetSelector:GetTarget(range)
	elseif Orb == 3 then
		target = GOS:GetTarget(range)
	end
	return target
end

local intToMode = {
   	[0] = "",
   	[1] = "Combo",
   	[2] = "Harass",
   	[3] = "LastHit",
   	[4] = "Clear"
}

local function GetMode()
	if Orb == 1 then
		return intToMode[EOW.CurrentMode]
	elseif Orb == 2 then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"	
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	else
		return GOS.GetMode()
	end
end

local function EnableOrb(bool)
	if Orb == 1 then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif Orb == 2 then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end
--- Engine ---
--- Ashe ---
class "Ashe"

function Ashe:__init()
	if _G.EOWLoaded then
		Orb = 1
	elseif _G.SDK and _G.SDK.Orbwalker then
		Orb = 2
	end
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Ashe:LoadSpells()
	Q = { range = myHero:GetSpellData(_Q).range, delay = myHero:GetSpellData(_Q).delay, speed = myHero:GetSpellData(_Q).speed, width = myHero:GetSpellData(_Q).width, icon = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/1/1d/Ranger%27s_Focus.png" }
	W = { range = myHero:GetSpellData(_W).range, delay = myHero:GetSpellData(_W).delay, speed = myHero:GetSpellData(_W).speed, width = myHero:GetSpellData(_W).width, icon = "https://vignette1.wikia.nocookie.net/leagueoflegends/images/5/5d/Volley.png" }
	R = { range = myHero:GetSpellData(_R).range, delay = myHero:GetSpellData(_R).delay, speed = myHero:GetSpellData(_R).speed, width = myHero:GetSpellData(_R).width, icon = "https://vignette3.wikia.nocookie.net/leagueoflegends/images/2/28/Enchanted_Crystal_Arrow.png" }
end

function Ashe:LoadMenu()
	Romanov = MenuElement({type = MENU, id = "Romanov", name = "Romanov Ashe"})
	--- Version ---
	Romanov:MenuElement({name = "Ashe", drop = {ScriptVersion}, leftIcon = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/AsheSquare.png"})
	--- Combo ---
	Romanov:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
	Romanov.Combo:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	Romanov.Combo:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
	Romanov.Combo:MenuElement({id = "R", name = "[R] Smart Combo [?]", value = true, leftIcon = R.icon, tooltip = "It'll cast R when total combo DMG will kill target"})
	Romanov.Combo:MenuElement({id = "RAA", name = "Auto Attacks After Ult", value = 5, min = 1, max = 15})
	--- Clear ---
	Romanov:MenuElement({type = MENU, id = "Clear", name = "Clear Settings"})
	Romanov.Clear:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("A"), toggle = true})
	Romanov.Clear:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	Romanov.Clear:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
	Romanov.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear [%]", value = 0, min = 0, max = 100})
	--- Harass ---
	Romanov:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
	Romanov.Harass:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("S"), toggle = true})
	Romanov.Harass:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	Romanov.Harass:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
	Romanov.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass [%]", value = 0, min = 0, max = 100})
	--- Misc ---
	Romanov:MenuElement({type = MENU, id = "Misc", name = "Misc Settings"})
	Romanov.Misc:MenuElement({id = "Rkey", name = "Semi-Manual [R] Key [?]", key = string.byte("T"), tooltip = "Select manually your target before pressing the key"})
	Romanov.Misc:MenuElement({id = "Raoe", name = "Auto Use [R] AoE", value = true})
	Romanov.Misc:MenuElement({id = "Rally", name = "Min Near Allies to [R] AoE", value = 2, min = 1, max = 5})
	Romanov.Misc:MenuElement({id = "Rene", name = "Enemies to [R] AoE", value = 3, min = 1, max = 5})
	Romanov.Misc:MenuElement({id = "Rmax", name = "Max Distance to [R] AoE", value = 3600, min = 200, max = 20000, step = 200})
	Romanov.Misc:MenuElement({id = "Wks", name = "Killsecure [W]", value = true, leftIcon = W.icon})
	Romanov.Misc:MenuElement({id = "Rks", name = "Killsecure [R]", value = true, leftIcon = R.icon})
	--- Draw ---
	Romanov:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
	Romanov.Draw:MenuElement({id = "W", name = "Draw [W] Range", value = true, leftIcon = W.icon})
	Romanov.Draw:MenuElement({id = "CT", name = "Clear Toggle", value = true})
	Romanov.Draw:MenuElement({id = "HT", name = "Harass Toggle", value = true})
	Romanov.Draw:MenuElement({id = "DMG", name = "Draw Combo Damage", value = true})
end

function Ashe:Tick()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Clear" then
		self:Clear()
	end
		self:Misc()
end

function Ashe:Combo()
	local target = GetTarget(3000)
	if not target then return end
	if Romanov.Combo.W:Value() and Ready(_W)and myHero.pos:DistanceTo(target.pos) < 1200 and target:GetCollision(W.width,W.speed,W.delay) == 0 then
		self:CastW(target)
	end
	if Romanov.Combo.R:Value() and Ready(_R) and OnScreen(target) then
		local AA = CalcPhysicalDamage(myHero, target, myHero.totalDamage)
		if self:GetComboDamage(target) + AA * (Romanov.Combo.RAA:Value()) > target.health then
			self:CastR(target)
		end
	end
	if Romanov.Combo.Q:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) < myHero.range then
		Control.CastSpell(HK_Q)
	end
end

function Ashe:Harass()
	local target = GetTarget(1200)
	if Romanov.Harass.Key:Value() == false then return end
	if myHero.mana/myHero.maxMana < Romanov.Harass.Mana:Value() then return end
	if not target then return end
	if Romanov.Harass.Q:Value() and Ready(_Q)and myHero.pos:DistanceTo(target.pos) < myHero.range then
		Control.CastSpell(HK_Q)
	end
	if Romanov.Harass.W:Value() and Ready(_W)and myHero.pos:DistanceTo(target.pos) < 1200 and target:GetCollision(W.width,W.speed,W.delay) == 0  then
		self:CastW(target)
	end
end

function Ashe:Clear()
	if Romanov.Clear.Key:Value() == false then return end
	if myHero.mana/myHero.maxMana < Romanov.Clear.Mana:Value() then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion.team ~= myHero.team then
			if  Romanov.Clear.Q:Value() and Ready(_Q) and myHero.pos:DistanceTo(minion.pos) < myHero.range then
				Control.CastSpell(HK_Q)
			end
			if  Romanov.Clear.W:Value() and Ready(_W) and myHero.pos:DistanceTo(minion.pos) < 1200 then
				self:CastW(minion)
			end
		end
	end
end

function Ashe:Misc()
	local target = GetTarget(20000)
	if not target then return end
	if Romanov.Misc.Rks:Value() and Ready(_R) and OnScreen(target) then
		local Rdmg = CalcMagicalDamage(myHero, target, (200 * myHero:GetSpellData(_R).level + myHero.ap))
		if Rdmg > target.health then
			self:CastR(target)
		end
	end
	if Romanov.Misc.Wks:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) < 1200 then
		local Wdmg = CalcPhysicalDamage(myHero, target, (5 + 15 * myHero:GetSpellData(_W).level + myHero.totalDamage))
		if Wdmg > target.health then
			self:CastW(target)
		end
	end
	if Romanov.Misc.Rkey:Value() and Ready(_R) then
		self:CastR(target)
	end
	if Romanov.Misc.Raoe:Value() and Ready(_R) and Romanov.Misc.Rene:Value() <=  EnemiesAround(target.pos,125,200) and Romanov.Misc.Rally:Value() <=  AlliesAround(target.pos,600,100) then
		if myHero.pos:DistanceTo(target.pos) > Romanov.Misc.Rmax:Value() then return end
		self:CastR(target)
	end
end

function Ashe:CastW(target)
	local Wdata = {speed = 2000, delay = 0.25,range = 1100 }
	local Wspell = Prediction:SetSpell(Wdata, TYPE_LINEAR, true)
	local pred = Wspell:GetPrediction(target,myHero.pos)
	if  myHero.pos:DistanceTo(target.pos) < myHero.range then
		if myHero.attackData.state == STATE_WINDDOWN then
			if pred and pred.hitChance >= 0.25 and pred:mCollision() == 0 and pred:hCollision() == 0 then
				EnableOrb(false)
				Control.CastSpell(HK_W, pred.castPos)
				EnableOrb(true)
			end
		end
	end
	if  myHero.pos:DistanceTo(target.pos) > myHero.range then
		if pred and pred.hitChance >= 0.25 and pred:mCollision() == 0 and pred:hCollision() == 0 then
			EnableOrb(false)
			Control.CastSpell(HK_W, pred.castPos)
			EnableOrb(true)
		end
	end
end

function Ashe:CastR(target)
	local Rdata = {speed = 1600, delay = 0.25,range = 20000 }
	local Rspell = Prediction:SetSpell(Rdata, TYPE_LINE, true)
	local pred = Rspell:GetPrediction(target,myHero.pos)
	if OnScreen(target) then
		if pred and pred.hitChance >= 0.25 and pred:hCollision() == 0 then
			EnableOrb(false)
			Control.CastSpell(HK_R, pred.castPos)
			EnableOrb(true)
		end
	end 
	if not OnScreen(target) then
		if pred and pred.hitChance >= 0.25 and pred:hCollision() == 0 then
			EnableOrb(false)
			Control.SetCursorPos(pred.castPos:ToMM().x,pred.castPos:ToMM().y)
			Control.KeyDown(HK_R)
			Control.KeyUp(HK_R)
			EnableOrb(true)
		end
	end
end

function Ashe:GetComboDamage(unit)
	local Total = 0
	local Wdmg = CalcPhysicalDamage(myHero, unit, (5 + 15 * myHero:GetSpellData(_W).level + myHero.totalDamage))
	local Rdmg = CalcMagicalDamage(myHero, unit, (200 * myHero:GetSpellData(_R).level + myHero.ap))
	if Ready(_W) then
		Total = Total + Wdmg
	end
	if Ready(_R) then
		Total = Total + Rdmg
	end
	return Total
end

function Ashe:Draw()
	if Romanov.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, 1200, 3,  Draw.Color(255,255, 162, 000)) end
	if Romanov.Draw.CT:Value() then
		local textPos = myHero.pos:To2D()
		if Romanov.Clear.Key:Value() then
			Draw.Text("Clear: On", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if Romanov.Draw.HT:Value() then
		local textPos = myHero.pos:To2D()
		if Romanov.Harass.Key:Value() then
			Draw.Text("Harass: On", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if Romanov.Draw.DMG:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead then
				if OnScreen(enemy) then
				local rectPos = enemy.hpBar
					if self:GetComboDamage(enemy) < enemy.health then
						Draw.Rect(rectPos.x , rectPos.y ,(tostring(math.floor(self:GetComboDamage(enemy)/enemy.health*100)))*((enemy.health/enemy.maxHealth)),10, Draw.Color(150, 000, 000, 255)) 
					else
						Draw.Rect(rectPos.x , rectPos.y ,((enemy.health/enemy.maxHealth)*100),10, Draw.Color(150, 255, 255, 000)) 
					end
				end
			end
		end
	end
end

Callback.Add("Load", function()
	if not _G.Prediction_Loaded then return end
	if _G[myHero.charName] then
		_G[myHero.charName]()
		print("Romanov "..myHero.charName.." "..ScriptVersion.." Loaded")
		print("PM me for suggestions/fix problems")
		print("Discord: Romanov#6333")
	else print ("Romanov doens't support "..myHero.charName.." shutting down...") return
	end
end)
