local unpack, tinsert, pairs, select, random = unpack, table.insert, pairs, select, math.random
local hooksecurefunc, CreateFrame, GetItemInfo, PlaySoundFile, UnitName, GetLocale, IsInInstance, GetLootMethod = hooksecurefunc, CreateFrame, GetItemInfo, PlaySoundFile, UnitName, GetLocale, IsInInstance, GetLootMethod

local playerName = UnitName('player')
local locale = GetLocale()
local options = {
  unlock_anchor = false,
  texture = 1,
}
local textures = {
  [1] = "LootToast",     -- Это текстура с WoW 9.1.5
  [2] = "LootToast_old", -- Это текстура с WoW 5.4.8
}

local YOU_RECEIVED_LABEL, YOU_WON_LABEL
if locale == 'deDE' then
  YOU_RECEIVED_LABEL = "Ihr habt erhalten:"
  YOU_WON_LABEL = "Gewonnen!"
elseif locale == 'enGB' then
  YOU_RECEIVED_LABEL = "You receive"
  YOU_WON_LABEL = "You Won!"
elseif locale == 'enUS' then
  YOU_RECEIVED_LABEL = "You receive"
  YOU_WON_LABEL = "You Won!"
elseif locale == 'esES' then
  YOU_RECEIVED_LABEL = "Has recibido:"
  YOU_WON_LABEL = "Has ganado"
elseif locale == 'esMX' then
  YOU_RECEIVED_LABEL = "Recibiste"
  YOU_WON_LABEL = "¡Has ganado!"
elseif locale == 'frFR' then
  YOU_RECEIVED_LABEL = "Vous avez reçu"
  YOU_WON_LABEL = "Gagné !"
elseif locale == 'itIT' then
  YOU_RECEIVED_LABEL = "Ottieni:"
  YOU_WON_LABEL = "Hai vinto!"
elseif locale == 'koKR' then
  YOU_RECEIVED_LABEL = "다음을 획득했습니다."
  YOU_WON_LABEL = "획득!"
elseif locale == 'ptBR' then
  YOU_RECEIVED_LABEL = "Você recebeu"
  YOU_WON_LABEL = "Você venceu!"
elseif locale == 'ruRU' then
  YOU_RECEIVED_LABEL = "Ваша добыча"
  YOU_WON_LABEL = "Вы выиграли!"
elseif locale == 'zhCN' then
  YOU_RECEIVED_LABEL = "你获得了"
  YOU_WON_LABEL = "你获得了："
elseif locale == 'zhTW' then
  YOU_RECEIVED_LABEL = "你獲得"
  YOU_WON_LABEL = "你贏得了："
end

local LOOT_WON_ALERT_FRAMES = {}
local LOOT_ROLL_TYPE_NEED = 1
local LOOT_ROLL_TYPE_GREED = 2
local LOOT_ROLL_TYPE_DISENCHANT = 3
local LOOT_BORDER_BY_QUALITY = {
  [ITEM_QUALITY_UNCOMMON] = {0.17968750, 0.23632813, 0.74218750, 0.96875000},
  [ITEM_QUALITY_RARE] = {0.86718750, 0.92382813, 0.00390625, 0.23046875},
  [ITEM_QUALITY_EPIC] = {0.92578125, 0.98242188, 0.00390625, 0.23046875},
  --[ITEM_QUALITY_LEGENDARY] = {0.80859375, 0.86523438, 0.00390625, 0.23046875},
}

local expectations_list = {}
local patterns = {
  won = {
    [LOOT_ROLL_TYPE_NEED] = LOOT_ROLL_YOU_WON_NO_SPAM_NEED,
    [LOOT_ROLL_TYPE_GREED] = LOOT_ROLL_YOU_WON_NO_SPAM_GREED,
    [LOOT_ROLL_TYPE_DISENCHANT] = LOOT_ROLL_YOU_WON_NO_SPAM_DE,
  },
  rolled = {
    [LOOT_ROLL_TYPE_NEED] = LOOT_ROLL_ROLLED_NEED,
    [LOOT_ROLL_TYPE_GREED] = LOOT_ROLL_ROLLED_GREED,
    [LOOT_ROLL_TYPE_DISENCHANT] = LOOT_ROLL_ROLLED_DE,
  },
}

function AlertFrame_OnEvent_Hook(self, event, ...)
  if event == "VARIABLES_LOADED" then
    AlertFrame_OnEvent_Hook(self, "ZONE_CHANGED_NEW_AREA")
    AlertFrame_OnEvent_Hook(self, "PARTY_LOOT_METHOD_CHANGED")
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    self.instanceType = select(2, IsInInstance())
    LootWonAlertFrame_UpdateEnabledState()
  elseif event == "PARTY_LOOT_METHOD_CHANGED" then
    self.lootMethod = GetLootMethod()
    LootWonAlertFrame_UpdateEnabledState()
  elseif event == "CHAT_MSG_LOOT" then
    LootWonAlertFrame_HandleChatMessage(self, ...)
  end
end

-- [[ AlertFrameTemplate functions ]] --
AlertFrame:Hide()
AlertFrame:SetSize(10, 10)
AlertFrame:SetPoint('BOTTOM', 0, 128)
AlertFrame:RegisterEvent("VARIABLES_LOADED")
AlertFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
AlertFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
AlertFrame:HookScript('OnEvent', AlertFrame_OnEvent_Hook)

hooksecurefunc('AlertFrame_AnimateIn', function(frame)
  frame.glow:Show()
  frame.shine:Show()
end)

function AlertFrame_OnClick(self, button, down)
  if button == 'RightButton' then
    self.animIn:Stop()
    if self.glow then
      self.glow.animIn:Stop()
    end
    if self.shine then
      self.shine.animIn:Stop()
    end
    self.waitAndAnimOut:Stop()
    self:Hide()
    return true
  end

  return false
end

function AlertFrame_FixAnchors()
  local alertAnchor = AlertFrame
  alertAnchor = AlertFrame_SetLootAnchors(alertAnchor)
  alertAnchor = AlertFrame_SetLootWonAnchors(alertAnchor)
  alertAnchor = AlertFrame_SetAchievementAnchors(alertAnchor)
  alertAnchor = AlertFrame_SetDungeonCompletionAnchors(alertAnchor)
end

function AlertFrame_SetLootAnchors(alertAnchor)
  for i=1, NUM_GROUP_LOOT_FRAMES do
    local frame = _G["GroupLootFrame"..i]
    if frame:IsShown() then
      frame:SetPoint('BOTTOM', alertAnchor, 'TOP', 0, 10)
      alertAnchor = frame
    end
  end
  return alertAnchor
end

function AlertFrame_SetLootWonAnchors(alertAnchor)
  for i=1, #LOOT_WON_ALERT_FRAMES do
    local frame = LOOT_WON_ALERT_FRAMES[i]
    if frame:IsShown() then
      frame:SetPoint('BOTTOM', alertAnchor, 'TOP', 0, 10)
      alertAnchor = frame
    end
  end
  return alertAnchor
end

function AlertFrame_SetAchievementAnchors(alertAnchor)
  -- skip work if there hasn't been an achievement toast yet
  if AchievementAlertFrame1 then
    for i = 1, MAX_ACHIEVEMENT_ALERTS do
      local frame = _G["AchievementAlertFrame"..i]
      if frame and frame:IsShown() then
        frame:SetPoint("BOTTOM", alertAnchor, "TOP", 0, 10)
        alertAnchor = frame
      end
    end
  end
  return alertAnchor
end

function AlertFrame_SetDungeonCompletionAnchors(alertAnchor)
  local frame = DungeonCompletionAlertFrame1
  if frame:IsShown() then
    frame:SetPoint("BOTTOM", alertAnchor, "TOP", 0, 10)
    alertAnchor = frame
  end
  return alertAnchor
end

-- [[ LootWonAlertFrameTemplate ]] --
function LootWonAlertFrame_Create()
  local frame = CreateFrame('Button', "LootWonAlertFrame"..#LOOT_WON_ALERT_FRAMES+1, UIParent, 'AlertFrameTemplate')
  frame:SetSize(276, 96)
  frame:SetFrameStrata('DIALOG')
  frame:Hide()
  frame:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
  frame.animIn = frame:CreateAnimationGroup()
  frame.animIn.animIn1 = frame.animIn:CreateAnimation('Alpha')
  frame.animIn.animIn1:SetChange(-1)
  frame.animIn.animIn1:SetDuration(0)
  frame.animIn.animIn1:SetOrder(1)
  frame.animIn.animIn2 = frame.animIn:CreateAnimation('Alpha')
  frame.animIn.animIn2:SetChange(1)
  frame.animIn.animIn2:SetDuration(0.2)
  frame.animIn.animIn2:SetOrder(2)
  frame.waitAndAnimOut = frame:CreateAnimationGroup()
  frame.waitAndAnimOut.animOut = frame.waitAndAnimOut:CreateAnimation('Alpha')
  frame.waitAndAnimOut.animOut:SetStartDelay(4.05)
  frame.waitAndAnimOut.animOut:SetChange(-1)
  frame.waitAndAnimOut.animOut:SetDuration(1.5)
  frame.waitAndAnimOut.animOut:SetScript('OnFinished', function(self)
    self:GetRegionParent():Hide()
  end)

  frame.lootItem = CreateFrame('Frame', 'LootItemExtended', frame)
  frame.lootItem:SetSize(52, 52)
  frame.lootItem:SetPoint('TOPLEFT', 22, -23)
  frame.lootItem.Icon = frame.lootItem:CreateTexture(nil, 'BORDER')
  frame.lootItem.Icon:SetSize(52, 52)
  frame.lootItem.Icon:SetPoint('TOPLEFT')
  frame.lootItem.IconBorder = frame.lootItem:CreateTexture(nil, 'ARTWORK', nil, 1)
  frame.lootItem.IconBorder:SetSize(58, 58)
  frame.lootItem.IconBorder:SetTexture('Interface\\AddOns\\LootWonAlert\\media\\'..textures[options.texture])
  frame.lootItem.IconBorder:SetTexCoord(0.34082, 0.397461, 0.53125, 0.644531)
  frame.lootItem.IconBorder:SetPoint('CENTER', frame.lootItem.Icon, 'CENTER')
  frame.lootItem.Count = frame.lootItem:CreateFontString(nil, 'ARTWORK', 'NumberFontNormalLarge')
  frame.lootItem.Count:Hide()
  frame.lootItem.Count:SetJustifyH('RIGHT')
  frame.lootItem.Count:SetPoint('BOTTOMRIGHT', frame.lootItem.Icon, -4, 6)
  frame.Background = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
  frame.Background:SetTexture('Interface\\AddOns\\LootWonAlert\\media\\'..textures[options.texture])
  frame.Background:SetSize(276, 96)
  frame.Background:SetPoint('CENTER')
  frame.Background:SetTexCoord(0.28222656, 0.55175781, 0.57812500, 0.95312500)
  frame.Label = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
  frame.Label:SetJustifyH('LEFT')
  frame.Label:SetSize(167, 16)
  frame.Label:SetPoint('TOPLEFT', frame.lootItem.Icon, 'TOPRIGHT', 7, 5)
  frame.ItemName = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalMed3')
  frame.ItemName:SetJustifyH('LEFT')
  frame.ItemName:SetJustifyV('MIDDLE')
  frame.ItemName:SetSize(167, 33)
  frame.ItemName:SetPoint('TOPLEFT', frame.lootItem.Icon, 'TOPRIGHT', 10, -19)
  frame.RollTypeIcon = frame:CreateTexture(nil, 'ARTWORK')
  frame.RollTypeIcon:SetTexture([[Interface\Buttons\UI-GroupLoot-Dice-Up]])
  frame.RollTypeIcon:SetSize(22, 22)
  frame.RollTypeIcon:SetPoint('TOPRIGHT', -20, -18)
  frame.RollValue = frame:CreateFontString(nil, 'ARTWORK', 'GameFontGreen')
  frame.RollValue:SetJustifyH('RIGHT')
  frame.RollValue:SetPoint('RIGHT', frame.RollTypeIcon, 'LEFT', -3, 2)

  frame.glow = frame:CreateTexture(nil, 'OVERLAY')
  frame.glow:Hide()
  frame.glow:SetTexture('Interface\\AddOns\\LootWonAlert\\media\\'..textures[options.texture])
  --frame.glow:SetTexCoord(0.0009765625, 0.2802734375, 0.001953125, 0.21484375)
  frame.glow:SetTexCoord(0.00097656, 0.28027344, 0.00390625, 0.42968750)
  frame.glow:SetBlendMode('ADD')
  frame.glow:SetSize(286, 109)
  frame.glow:SetPoint('CENTER', 0, 0)
  frame.glow.animIn = frame.glow:CreateAnimationGroup()
  frame.glow.animIn.animIn1 = frame.glow.animIn:CreateAnimation('Alpha')
  frame.glow.animIn.animIn1:SetChange(1)
  frame.glow.animIn.animIn1:SetDuration(0.2)
  frame.glow.animIn.animIn1:SetOrder(1)
  frame.glow.animIn.animIn2 = frame.glow.animIn:CreateAnimation('Alpha')
  frame.glow.animIn.animIn2:SetChange(-1)
  frame.glow.animIn.animIn2:SetDuration(0.5)
  frame.glow.animIn.animIn2:SetOrder(2)
  frame.glow.animIn:SetScript('OnFinished', function(self)
    self:GetParent():Hide()
  end)

  frame.shine = frame:CreateTexture(nil, 'OVERLAY')
  frame.shine:Hide()
  frame.shine:SetTexture('Interface\\AddOns\\LootWonAlert\\media\\'..textures[options.texture])
  frame.shine:SetTexCoord(0.56347656, 0.73046875, 0.57421875, 0.86718750)
  frame.shine:SetBlendMode('ADD')
  frame.shine:SetSize(171, 75)
  frame.shine:SetPoint('BOTTOMLEFT', -10, 12)
  frame.shine.animIn = frame.shine:CreateAnimationGroup()
  frame.shine.animIn.animIn1 = frame.shine.animIn:CreateAnimation('Alpha')
  frame.shine.animIn.animIn1:SetChange(1)
  frame.shine.animIn.animIn1:SetDuration(0.1)
  frame.shine.animIn.animIn1:SetOrder(1)
  frame.shine.animIn.animIn2 = frame.shine.animIn:CreateAnimation('Translation')
  frame.shine.animIn.animIn2:SetOffset(165, 0)
  frame.shine.animIn.animIn2:SetDuration(0.425)
  frame.shine.animIn.animIn2:SetOrder(2)
  frame.shine.animIn.animIn3 = frame.shine.animIn:CreateAnimation('Alpha')
  frame.shine.animIn.animIn3:SetStartDelay(0.175)
  frame.shine.animIn.animIn3:SetChange(-1)
  -- frame.shine.animIn.animIn3:SetDuration(0.25)
  frame.shine.animIn.animIn3:SetDuration(0.135)
  frame.shine.animIn.animIn3:SetOrder(2)
  frame.shine.animIn:SetScript('OnFinished', function(self)
    self:GetParent():Hide()
  end)

  frame:SetScript('OnHide', AlertFrame_FixAnchors)
  frame:SetScript('OnEnter', function(self)
    AlertFrame_StopOutAnimation(self)
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetHyperlink(self.hyperlink)
    GameTooltip:Show()
  end)
  frame:SetScript('OnLeave', function(self)
    AlertFrame_ResumeOutAnimation(self)
    GameTooltip:Hide()
  end)
  frame:SetScript('OnClick', LootWonAlertFrame_OnClick)

  return frame
end

function LootWonAlertFrame_ShowAlert(itemLink, quantity, rollType, roll)
  local frame
  for i=1, #LOOT_WON_ALERT_FRAMES do
    local lootWon = LOOT_WON_ALERT_FRAMES[i]
    if not lootWon:IsShown() then
      frame = lootWon
      break
    end
  end

  if not frame then
    frame = LootWonAlertFrame_Create()
    tinsert(LOOT_WON_ALERT_FRAMES, frame)
  end

  LootWonAlertFrame_SetUp(frame, itemLink, quantity, rollType, roll)
  AlertFrame_AnimateIn(frame)
  AlertFrame_FixAnchors()
end

-- NOTE - This may also be called for an externally created frame. (E.g. bonus roll has its own frame)
function LootWonAlertFrame_SetUp(self, itemLink, quantity, rollType, roll)
  local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
  self.Label:SetText(rollType == LOOT_ROLL_TYPE_DISENCHANT and YOU_RECEIVED_LABEL or YOU_WON_LABEL)
  self.ItemName:SetText(itemName)
  local color = ITEM_QUALITY_COLORS[itemRarity]
  self.ItemName:SetVertexColor(color.r, color.g, color.b)

  local coords = LOOT_BORDER_BY_QUALITY[itemRarity]
  local desaturate = false
  if not coords then
    coords = {0.73242188, 0.78906250, 0.57421875, 0.80078125}
    desaturate = true
  end

  self.lootItem.IconBorder:SetTexCoord(unpack(coords))
  self.lootItem.IconBorder:SetDesaturated(desaturate)
  self.lootItem.Icon:SetTexture(itemTexture)
  if quantity > 1 then
    quantity = quantity > 9999 and '*' or quantity
    self.lootItem.Count:SetText(quantity)
    self.lootItem.Count:Show()
  else
    self.lootItem.Count:SetText('')
    self.lootItem.Count:Hide()
  end

  if rollType == LOOT_ROLL_TYPE_NEED then
    self.RollTypeIcon:SetTexture([[Interface\Buttons\UI-GroupLoot-Dice-Up]])
    self.RollValue:SetText(roll)
    self.RollTypeIcon:Show()
    self.RollValue:Show()
  elseif rollType == LOOT_ROLL_TYPE_GREED then
    self.RollTypeIcon:SetTexture([[Interface\Buttons\UI-GroupLoot-Coin-Up]])
    self.RollValue:SetText(roll)
    self.RollTypeIcon:Show()
    self.RollValue:Show()
  else
    self.RollTypeIcon:Hide()
    self.RollValue:Hide()
  end

  self.hyperlink = itemLink
  PlaySoundFile([[Interface\AddOns\LootWonAlert\media\UI_EpicLoot_Toast_01.ogg]])
end

function LootWonAlertFrame_OnClick(self, button, down)
  if AlertFrame_OnClick(self, button, down) then
    return
  end
  HandleModifiedItemClick(self.hyperlink)
end

function LootWonAlertFrame_UpdateEnabledState()
  if (AlertFrame.instanceType == 'party' or AlertFrame.instanceType == 'raid') and
     (AlertFrame.lootMethod == 'group' or AlertFrame.lootMethod == 'needbeforegreed') then
    AlertFrame:RegisterEvent("CHAT_MSG_LOOT")
  else
    AlertFrame:UnregisterEvent("CHAT_MSG_LOOT")
  end
end

function LootWonAlertFrame_HandleChatMessage(self, ...)
  local message = ...
  local itemLink, rollType, roll, quantity

  if expectations_list.disenchart_result then
    itemLink, quantity = message:cmatch(LOOT_ITEM_SELF_MULTIPLE)
    if not itemLink then
      itemLink = message:cmatch(LOOT_ITEM_SELF)
    end
    if itemLink and expectations_list[itemLink] then
      rollType = LOOT_ROLL_TYPE_DISENCHANT
      quantity = tonumber(quantity) or 1
      expectations_list[itemLink] = nil
      expectations_list.disenchart_result = false
      LootWonAlertFrame_ShowAlert(itemLink, quantity, rollType)
      return
    end
    return
  end

  itemLink = message:cmatch(LOOT_ROLL_YOU_WON)
  if itemLink and expectations_list[itemLink] then
    rollType, roll = expectations_list[itemLink][1], expectations_list[itemLink][2]
    if rollType == LOOT_ROLL_TYPE_DISENCHANT then
      expectations_list.disenchart_result = true
      return
    else
      expectations_list[itemLink] = nil
      LootWonAlertFrame_ShowAlert(itemLink, 1, rollType, roll)
      return
    end
  end

  for rollType, pattern in pairs(patterns.rolled) do
    local roll, itemLink, player = message:cmatch(pattern)
    if roll and player == playerName then
      expectations_list[itemLink] = {rollType, roll}
      return
    end
  end

  for rollType, pattern in pairs(patterns.won) do
    local roll, itemLink = message:cmatch(pattern)
    if roll then
      LootWonAlertFrame_ShowAlert(itemLink, 1, rollType, roll)
      return
    end
  end
end

local function GetRandomItem()
  local id, itemQuality
  while not itemQuality or itemQuality < ITEM_QUALITY_UNCOMMON do
    id = random(1, 55000)
    itemQuality = select(3, GetItemInfo(id))
  end
  return id
end
function LootWonAlertFrame_Test(itemID)
  LootWonAlertFrame_ShowAlert(itemID or GetRandomItem(), 1, random(1, 2), random(1, 100))
end

if options.unlock_anchor then
  local AlertFrameExtended = CreateFrame('Frame', 'AlertFrameExtended', UIParent)
  AlertFrameExtended:SetSize(10, 10)
  AlertFrameExtended:SetMovable(true)
  AlertFrameExtended:SetPoint('BOTTOM', 0, 128)

  local frame = LootWonAlertFrame_Create() -- create first frame
  tinsert(LOOT_WON_ALERT_FRAMES, frame)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:RegisterForDrag('LeftButton')
  frame:SetScript("OnDragStart", function(self) AlertFrameExtended:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) AlertFrameExtended:StopMovingOrSizing() end)

  function AlertFrame_SetLootWonAnchors(alertAnchor)
    local old_alertAnchor = alertAnchor
    alertAnchor = AlertFrameExtended
    for i=1, #LOOT_WON_ALERT_FRAMES do
      local frame = LOOT_WON_ALERT_FRAMES[i]
      if frame:IsShown() then
        frame:SetPoint('BOTTOM', alertAnchor, 'TOP', 0, 10)
        alertAnchor = frame
      end
    end
    return old_alertAnchor
  end
end
