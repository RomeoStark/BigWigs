------------------------------
--      Are you local?      --
------------------------------

local thane = AceLibrary("Babble-Boss-2.0")("Thane Korth'azz")
local mograine = AceLibrary("Babble-Boss-2.0")("Highlord Mograine")
local zeliek = AceLibrary("Babble-Boss-2.0")("Sir Zeliek")
local blaumeux = AceLibrary("Babble-Boss-2.0")("Lady Blaumeux")
local boss = AceLibrary("Babble-Boss-2.0")("The Four Horsemen")

local L = AceLibrary("AceLocale-2.0"):new("BigWigs"..boss)

local times = nil

----------------------------
--      Localization      --
----------------------------

L:RegisterTranslations("enUS", function() return {
	cmd = "Horsemen",

	mark_cmd = "mark",
	mark_name = "Mark Alerts",
	mark_desc = "Warn for marks",

	shieldwall_cmd  = "shieldwall",
	shieldwall_name = "Shieldwall Alerts",
	shieldwall_desc = "Warn for shieldwall",

	void_cmd = "void",
	void_name = "Void Zone Alerts",
	void_desc = "Warn on Lady Blaumeux casting Void Zone.",

	meteor_cmd = "meteor",
	meteor_name = "Meteor Alerts",
	meteor_desc = "Warn on Thane casting Meteor.",

	wrath_cmd = "wrath",
	wrath_name = "Holy Wrath Alerts",
	wrath_desc = "Warn on Zeliek casting Wrath.",

	markbar = "Mark",
	markwarn1 = "Mark (%d)!",
	markwarn2 = "Mark (%d) - 5 sec",
	marktrigger = "is afflicted by Mark of ",

	voidtrigger = "Lady Blaumeux casts Void Zone.",
	voidwarn = "Void Zone Incoming",
	voidbar = "Void Zone",

	meteortrigger = "Thane Korth'azz's Meteor hits ",
	meteorwarn = "Meteor!",
	meteorbar = "Meteor",

	wrathtrigger = "Sir Zeliek's Holy Wrath hits ",
	wrathwarn = "Holy Wrath!",
	wrathbar = "Holy Wrath",

	startwarn = "The Four Horsemen Engaged! Mark in ~17 sec",

	shieldwallbar = "%s - Shield Wall",
	shieldwalltrigger = "(.*) gains Shield Wall.",
	shieldwallwarn = "%s - Shield Wall for 20 sec",
	shieldwallwarn2 = "%s - Shield Wall GONE!",
} end )

L:RegisterTranslations("deDE", function() return {
	mark_name = "Mark Alerts", -- ?
	mark_desc = "Warn for marks", -- ?

	shieldwall_name = "Schildwall",
	shieldwall_desc = "Warnung vor Schildwall.",

	markbar = "Mark", -- ?
	markwarn1 = "Mark (%d)!", -- ?
	markwarn2 = "Mark (%d) - 5 Sekunden", -- ?

	startwarn = "The Four Horsemen angegriffen! Mark in 30 Sekunden", -- ?

	shieldwallbar = "%s - Schildwall",
	shieldwalltrigger = " bekommt 'Schildwall'.",
	shieldwallwarn = "%s - Schildwall f\195\188r 20 Sekunden",
	shieldwallwarn2 = "%s - Schildwall Vorbei!",
} end )

L:RegisterTranslations("zhCN", function() return {
	mark_name = "标记警报",
	mark_desc = "标记警报",

	shieldwall_name = "盾墙警报",
	shieldwall_desc = "盾墙警报",

	markbar = "标记",
	markwarn1 = "标记(%d)！",
	markwarn2 = "标记(%d) - 5秒",

	startwarn = "四骑士已激活 - 30秒后标记",

	shieldwallbar = "%s - 盾墙",
	shieldwalltrigger = "获得了盾墙",
	shieldwallwarn = "%s - 20秒盾墙效果",
	shieldwallwarn2 = "%s - 盾墙消失了！",
} end )

----------------------------------
--      Module Declaration      --
----------------------------------

BigWigsHorsemen = BigWigs:NewModule(boss)
BigWigsHorsemen.zonename = AceLibrary("Babble-Zone-2.0")("Naxxramas")
BigWigsHorsemen.enabletrigger = { thane, mograine, zeliek, blaumeux }
BigWigsHorsemen.toggleoptions = {"mark", "shieldwall", "meteor", "void", "wrath", "bosskill"}
BigWigsHorsemen.revision = tonumber(string.sub("$Revision$", 12, -3))

------------------------------
--      Initialization      --
------------------------------

function BigWigsHorsemen:OnEnable()
	self.started = nil
	self.marks = 1
	self.deaths = 0

	times = {}

	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "SkillEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "MarkEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "MarkEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "MarkEvent")

	self:RegisterEvent("BigWigs_RecvSync")
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenShieldWall", 3)
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenStart", 10)
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenMark", 8)
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenVoid", 5)
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenWrath", 5)
	self:TriggerEvent("BigWigs_ThrottleSync", "HorsemenMeteor", 5)
end

function BigWigsHorsemen:PLAYER_REGEN_ENABLED()
	local go = self:Scan()
	local running = self:IsEventScheduled("Horsemen_CheckWipe")
	if (not go) then
		self:TriggerEvent("BigWigs_RebootModule", self)
	elseif (not running) then
		self:ScheduleRepeatingEvent("Horsemen_CheckWipe", self.PLAYER_REGEN_ENABLED, 2, self)
	end
end

function BigWigsHorsemen:PLAYER_REGEN_DISABLED()
	local go = self:Scan()
	local running = self:IsEventScheduled("Horsemen_CheckStart")
	if (go) then
		self:CancelScheduledEvent("Horsemen_CheckStart")
		self:TriggerEvent("BigWigs_SendSync", "HorsemenStart")
	elseif not running then
		self:ScheduleRepeatingEvent("Horsemen_CheckStart", self.PLAYER_REGEN_DISABLED, .5, self)
	end
end

function BigWigsHorsemen:Scan()
	if ( ( UnitName("target") == thane or UnitName("target") == mograine or UnitName("target") == zeliek or UnitName("target") == blaumeux )  and UnitAffectingCombat("target")) then
		return true
	elseif ( ( UnitName("playertarget") == thane or UnitName("playertarget") == mograine or UnitName("playertarget") == zeliek or UnitName("playertarget") == blaumeux ) and UnitAffectingCombat("playertarget")) then
		return true
	else
		local i
		for i = 1, GetNumRaidMembers(), 1 do
			if ( ( UnitName("raid"..i.."target") == thane or UnitName("raid"..i.."target") == mograine or UnitName("raid"..i.."target") == zeliek or UnitName("raid"..i.."target") == blaumeux ) and UnitAffectingCombat("raid"..i.."target")) then
				return true
			end
		end
	end
	return false
end

function BigWigsHorsemen:MarkEvent( msg )
	if string.find(msg, L["marktrigger"]) then
		local t = GetTime()
		if not times["mark"] or (times["mark"] and (times["mark"] + 8) < t) then
			self:TriggerEvent("BigWigs_SendSync", "HorsemenMark")
			times["mark"] = t
		end
	end
end

function BigWigsHorsemen:SkillEvent( msg )
	local t = GetTime()
	if string.find(msg, L["meteortrigger"]) then
		if not times["meteor"] or (times["meteor"] and (times["meteor"] + 8) < t) then
			self:TriggerEvent("BigWigs_SendSync", "HorsemenMeteor")
			times["meteor"] = t
		end
	elseif string.find(msg, L["wrathtrigger"]) then
		if not times["wrath"] or (times["wrath"] and (times["wrath"] + 8) < t) then
			self:TriggerEvent("BigWigs_SendSync", "HorsemenWrath")
			times["wrath"] = t
		end
	elseif msg == L["voidtrigger"] then
		if not times["void"] or (times["void"] and (times["void"] + 8) < t) then
			self:TriggerEvent("BigWigs_SendSync", "HorsemenVoid" )
			times["void"] = t
		end
	end
end

function BigWigsHorsemen:BigWigs_RecvSync(sync, rest)
	if sync == "HorsemenStart" and not self.started then
		self.started = true
		if self.db.profile.mark then
			self:TriggerEvent("BigWigs_Message", L["startwarn"], "Yellow")
			self:TriggerEvent("BigWigs_StartBar", self, L["markbar"], 17, "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde", "Yellow", "Orange", "Red")
			self:ScheduleEvent("bwhorsemenmark2", "BigWigs_Message", 12, string.format( L["markwarn2"], self.marks ), "Orange")
		end
	elseif sync == "HorsemenMark" then
		if self.db.profile.mark then
			self:TriggerEvent("BigWigs_Message", string.format( L["markwarn1"], self.marks ), "Red")
		end
		self.marks = self.marks + 1
		if self.db.profile.mark then 
			self:TriggerEvent("BigWigs_StartBar", self, L["markbar"], 12, "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde", "Orange", "Red")
			self:ScheduleEvent("bwhorsemenmark2", "BigWigs_Message", 7, string.format( L["markwarn2"], self.marks ), "Orange")
		end
	elseif sync == "HorsemenMeteor" then
		if self.db.profile.meteor then
			self:TriggerEvent("BigWigs_Message", L["meteorwarn"], "Red")
			self:TriggerEvent("BigWigs_StartBar", self, L["meteorbar"], 12, "Interface\\Icons\\Spell_Fire_Fireball02", "Orange", "Red")
		end
	elseif sync == "HorsemenWrath" then
		if self.db.profile.meteor then
			self:TriggerEvent("BigWigs_Message", L["wrathwarn"], "Red")
			self:TriggerEvent("BigWigs_StartBar", self, L["wrathbar"], 12, "Interface\\Icons\\Spell_Holy_Excorcism", "Orange", "Red")
		end
	elseif sync == "HorsemenVoid" then
		if self.db.profile.void then
			self:TriggerEvent("BigWigs_Message", L["voidwarn"], "Red")
			self:TriggerEvent("BigWigs_StartBar", self, L["voidbar"], 12, "Interface\\Icons\\Spell_Frost_IceStorm", "Orange", "Red")
		end
	elseif sync == "HorsemenShieldWall" and self.db.profile.shieldwall and rest then
		self:TriggerEvent("BigWigs_Message", string.format(L["shieldwallwarn"], rest), "White")
		self:ScheduleEvent("BigWigs_Message", 20, string.format(L["shieldwallwarn2"], rest), "Green")
		self:TriggerEvent("BigWigs_StartBar", self, string.format(L["shieldwallbar"], rest), 20, "Interface\\Icons\\Ability_Warrior_ShieldWall", "Yellow", "Orange", "Red")
	end
end

function BigWigsHorsemen:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS( msg )
	local _,_, mob = string.find(msg, L["shieldwalltrigger"])
	if mob then self:TriggerEvent("BigWigs_SendSync", "HorsemenShieldWall "..mob) end
end

function BigWigsHorsemen:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF(msg)
	if msg == L["voidtrigger"] then
		self:TriggerEvent("BigWigs_SendSync", "HorsemenVoid" )
	end	
end

function BigWigsHorsemen:CHAT_MSG_COMBAT_HOSTILE_DEATH( msg )
	if msg == string.format(UNITDIESOTHER, thane ) or
		msg == string.format(UNITDIESOTHER, zeliek) or 
		msg == string.format(UNITDIESOTHER, mograine) or
		msg == string.format(UNITDIESOTHER, blaumeux) then
		self.deaths = self.deaths + 1
		if self.deaths == 4 then
			if self.db.profile.bosskill then self:TriggerEvent("BigWigs_Message", string.format(AceLibrary("AceLocale-2.0"):new("BigWigs")("%s have been defeated"), boss), "Green", nil, "Victory") end
			self.core:ToggleModuleActive(self, false)
		end
	end
end

