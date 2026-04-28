-- main.lua
-- ゲーム全体の進行（マップ、イベント、キャンプ、報酬画面）およびシーンの切り替えを管理するメインモジュールです。

local EnemyLibrary = require("enemies")
local CardLibrary = require("cards")
local Map = require("map")
local DeckViewer = require("deck_viewer")
local Battle = require("battle")

local currentScene = "TITLE" 
local map
local player, master_deck, host_deck
local playerRelics, rewardOptions, introMessage = {}, {}, ""
local UI = { btns = {}, rewards = {} }
local eventData, campfireMode, campfireCards = {}, "", {}

-- 汎用ユーティリティ群
local function lerp(a, b, t) return a + (b - a) * t end
local function shuffle(t) for i = #t, 2, -1 do local j = love.math.random(i); t[i], t[j] = t[j], t[i] end end
local function isInside(mx, my, ent) return mx >= ent.x and mx <= ent.x + ent.w and my >= ent.y and my <= ent.y + ent.h end
local function createEntity(x, y, w, h, data)
    local e = data or {}; e.x, e.y, e.target_x, e.target_y = x, y, x, y; e.w, e.h, e.alpha = w, h, 0; return e
end

local relics = {
    { id = "insomnia", name = "不眠不休", desc = "E+1, 劣化+1", energy_bonus = 1, decay_bonus = 1 },
    { id = "gluttony", name = "悪食", desc = "3回攻撃で最大HP+1", attack_count = 0 },
    { id = "memory",   name = "超記憶", desc = "肉体カード1枚を魂へ" }
}

-- マップ・キャンプ用のHPバー汎用描画関数
local function drawHPBar(x, y, hp, max_hp, label, subtext)
    local w = 200; love.graphics.setColor(1, 1, 1); love.graphics.printf(label, x, y - 20, w, "center"); love.graphics.rectangle("line", x, y, w, 15)
    love.graphics.setColor(0.2, 0.8, 0.2); local fillW = w * (math.max(0, hp) / max_hp)
    if fillW > 0 then love.graphics.rectangle("fill", x, y, fillW, 15) end
    love.graphics.setColor(1, 1, 1); love.graphics.printf(math.floor(hp) .. " / " .. max_hp, x, y + 20, w, "center")
    if subtext then love.graphics.setColor(0.6, 0.4, 0.2); love.graphics.printf(subtext, x, y + 40, w, "center"); love.graphics.setColor(1, 1, 1) end
end

-- 報酬やキャンプなど、戦闘外でのカード単体描画関数
local function drawSingleCard(c, x, y, cw, ch, alpha)
    love.graphics.setColor(0.1, 0.1, 0.1, alpha); love.graphics.rectangle("fill", x, y, cw, ch, 10)
    love.graphics.setColor(1, 1, 1, alpha); love.graphics.rectangle("line", x, y, cw, ch, 10)
    love.graphics.printf(c.name, x, y+10, cw, "center"); love.graphics.print("C:"..c.cost, x+105, y+5)
    local ty = y+60
    if c.damage then love.graphics.setColor(1,0.4,0.4); love.graphics.printf("Dmg:"..c.damage, x, ty, cw, "center"); ty=ty+20 end
    if c.damage_equals_block then love.graphics.setColor(1,0.4,0.4); love.graphics.printf("Dmg:Block", x, ty, cw, "center"); ty=ty+20 end
    if c.block then love.graphics.setColor(0.4,0.7,1); love.graphics.printf("Blk:"..c.block, x, ty, cw, "center"); ty=ty+20 end
    if c.heal then love.graphics.setColor(0.2,1,0.2); love.graphics.printf("Heal:"..c.heal, x, ty, cw, "center"); ty=ty+20 end
    if c.draw_cards then love.graphics.setColor(0.2,0.8,0.8); love.graphics.printf("Draw:"..c.draw_cards, x, ty, cw, "center"); ty=ty+20 end
    if c.self_decay then love.graphics.setColor(0.6,0.4,0.2); love.graphics.printf("Decay:-"..c.self_decay, x, ty, cw, "center"); ty=ty+20 end
    if c.poison then love.graphics.setColor(0.2,0.8,0.2); love.graphics.printf("Psn:"..c.poison, x, ty, cw, "center"); ty=ty+20 end
    if c.thorns then love.graphics.setColor(1,0.6,0.2); love.graphics.printf("Thorns:"..c.thorns, x, ty, cw, "center"); ty=ty+20 end
    if c.delayed_damage then love.graphics.setColor(0.8,0.4,0.8); love.graphics.printf("Delay:"..c.delayed_damage, x, ty, cw, "center"); ty=ty+20 end
    if c.strength then love.graphics.setColor(1,0.2,0.2); love.graphics.printf("Str:+"..c.strength, x, ty, cw, "center"); ty=ty+20 end
    if c.double_buffs then love.graphics.setColor(1,0.8,0.2); love.graphics.printf("Double Buffs", x, ty, cw, "center"); ty=ty+20 end
    if c.double_debuffs then love.graphics.setColor(0.8,0.2,0.8); love.graphics.printf("Double Debuffs", x, ty, cw, "center"); ty=ty+20 end
    if c.exhaust then love.graphics.setColor(0.5,0.5,0.5); love.graphics.printf("Exhaust", x, ty, cw, "center"); ty=ty+20 end
    love.graphics.setColor(1,1,1)
end

-- ゲーム起動時やリセット時の初期状態セットアップ
function initGame()
    currentScene = "INTRO"
    map = Map.new()
    playerRelics = {}
    master_deck = { CardLibrary.Basic[1], CardLibrary.Basic[1], CardLibrary.Basic[1], CardLibrary.Basic[2], CardLibrary.Basic[2], CardLibrary.Basic[2] }
    local t1 = {}; for _, e in ipairs(EnemyLibrary) do if e.tier == 1 then table.insert(t1, e) end end
    local host = t1[love.math.random(#t1)]
    player = { hp = host.hp, max_hp = host.hp, energy = 3, max_energy = 3, block = 0, strength = 0, vulnerable = 0, poison = 0, split_buff = 0, thorns = 0, soul_impact = 0, signature_card = host.signature, mastery_kills = 0, mastery_target = 3, mastery_completed = false }
    host_deck = {}; for _, c in ipairs(host.deck) do table.insert(host_deck, c) end
    introMessage = "魂の漂流... \n【 " .. host.name .. " 】の残滓に宿る。"

    UI.btns.possess = createEntity(340, 350, 250, 80, { label = "POSSESS", fn = function()
        local enemy = Battle.getEnemy()
        player.max_hp, player.hp = enemy.max_hp, enemy.max_hp
        for _, e in ipairs(EnemyLibrary) do if e.name == enemy.name then player.signature_card = e.signature; break end end
        player.mastery_kills, player.mastery_completed, host_deck = 0, false, {}
        for _, c in ipairs(enemy.deckData) do table.insert(host_deck, c) end
        currentScene = "MAP"
    end})
    UI.btns.absorb = createEntity(690, 350, 250, 80, { label = "ABSORB", fn = function() generateRewards() end })
    UI.btns.bossReward = createEntity(515, 350, 250, 80, { label = "CLAIM REWARDS", fn = function()
        local r = relics[love.math.random(#relics)]; table.insert(playerRelics, r)
        if r.id == "memory" and #host_deck > 0 then table.insert(master_deck, host_deck[love.math.random(#host_deck)]) end
        generateRewards()
    end})
    UI.btns.skip = createEntity(540, 620, 200, 50, { label = "SKIP REWARD", fn = function() currentScene = "MAP" end })
    UI.btns.viewDeckMap = createEntity(30, 80, 200, 40, { label = "View Full Deck" })
    UI.btns.campRest = createEntity(200, 300, 200, 60, { label = "Rest (Heal 30%)" })
    UI.btns.campPatch = createEntity(200, 400, 200, 60, { label = "Patchwork (Max HP+5)" })
    UI.btns.campUpgrade = createEntity(880, 300, 200, 60, { label = "Upgrade Card" })
    UI.btns.campRemove = createEntity(880, 400, 200, 60, { label = "Remove Card" })
    UI.btns.cancelCamp = createEntity(540, 620, 200, 50, { label = "CANCEL" })
    UI.btns.eventA = createEntity(340, 400, 250, 80, { label = "Choice A" })
    UI.btns.eventB = createEntity(690, 400, 250, 80, { label = "Choice B" })
end

-- 戦闘勝利後やイベントで提示されるソウルカード報酬（3択）を生成
function generateRewards()
    UI.rewards = {}; local temp = {}; for _, v in ipairs(CardLibrary.SoulCards) do table.insert(temp, v) end; shuffle(temp)
    local cw, spacing = 200, 50; local sx = (1280/2) - ((3*cw + 2*spacing)/2)
    for i = 1, 3 do local rEnt = createEntity(sx + (i-1)*(cw+spacing), 800, cw, 280, temp[i]); rEnt.target_y = 250; table.insert(UI.rewards, rEnt) end
    currentScene = "REWARD_CARDS"
end

-- マップで選択したノードに応じたイベント、キャンプ、またはバトル初期化への遷移
function startMapNode(nodeIndex)
    map.currentNodeIndex = nodeIndex
    local nodeData = map.nodes[nodeIndex]
    
    if nodeData.type == "event" then
        if love.math.random(1, 2) == 1 then
            eventData = { text = "呪われた祭壇だ。\n最大寿命(Max HP)を削れば、霊魂の知識を得られるだろう。",
                          btnA = "祈る (Max HP-3, Soul Card+1)", fnA = function() player.max_hp = player.max_hp - 3; player.hp = math.min(player.hp, player.max_hp); generateRewards() end,
                          btnB = "立ち去る", fnB = function() currentScene = "MAP" end }
        else
            eventData = { text = "清らかな泉が湧き出ている。\n肉体の傷を癒やすか、それとも寿命を延ばすか。",
                          btnA = "飲む (Heal 15 HP)", fnA = function() player.hp = math.min(player.max_hp, player.hp + 15); currentScene = "MAP" end,
                          btnB = "水浴び (Max HP +2)", fnB = function() player.max_hp = player.max_hp + 2; currentScene = "MAP" end }
        end
        UI.btns.eventA.label = eventData.btnA; UI.btns.eventB.label = eventData.btnB; currentScene = "EVENT"; return
    elseif nodeData.type == "campfire" then currentScene = "CAMPFIRE"; return end

    local pool = {}
    for _, e in ipairs(EnemyLibrary) do
        if nodeData.type == "combat" and e.tier == nodeData.tier then table.insert(pool, e)
        elseif nodeData.type == "boss" and e.tier == "BOSS" then table.insert(pool, e) end
    end
    local enemyData = pool[love.math.random(#pool)] or EnemyLibrary[1]
    Battle.start(player, master_deck, host_deck, enemyData, playerRelics)
    currentScene = "BATTLE"
end

-- キャンプでのカード強化・削除対象を選ぶ画面を展開
function openCampfireCardSelect(mode)
    campfireMode = mode; campfireCards = {}
    for i, c in ipairs(master_deck) do table.insert(campfireCards, {deck="master", idx=i, card=c}) end
    for i, c in ipairs(host_deck) do table.insert(campfireCards, {deck="host", idx=i, card=c}) end
    currentScene = "CAMPFIRE_CARD_SELECT"
end

-- LÖVEエンジンの初期起動コールバック
function love.load()
    love.window.setMode(1280, 720)
    UI.btns.titleStart = createEntity(1280/2 - 150, 350, 300, 80, { label = "START GAME" })
    UI.btns.titleQuit = createEntity(1280/2 - 150, 480, 300, 80, { label = "EXIT" })
end

-- 毎フレームの更新処理（アニメーション補間など）
function love.update(dt)
    if currentScene == "BATTLE" then Battle.update(dt)
    elseif currentScene == "REWARD_CARDS" then 
        for _, r in ipairs(UI.rewards) do r.x = lerp(r.x, r.target_x, dt*12); r.y = lerp(r.y, r.target_y, dt*12); r.alpha = lerp(r.alpha, 1, dt*5) end
    end
end

-- シーンごとの画面描画振り分け
function love.draw()
    love.graphics.clear(0.02, 0.02, 0.03)
    if currentScene == "TITLE" then
        love.graphics.scale(2); love.graphics.printf("魂 の 漂 流", 0, 80, 1280/2, "center"); love.graphics.origin()
        local b1, b2 = UI.btns.titleStart, UI.btns.titleQuit
        love.graphics.rectangle("line", b1.x, b1.y, b1.w, b1.h); love.graphics.printf(b1.label, b1.x, b1.y+30, b1.w, "center")
        love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h); love.graphics.printf(b2.label, b2.x, b2.y+30, b2.w, "center")
    elseif currentScene == "INTRO" then
        love.graphics.printf(introMessage, 0, 300, 1280, "center")
        love.graphics.setColor(0.5, 0.5, 0.5); love.graphics.printf("- Click to Start -", 0, 500, 1280, "center"); love.graphics.setColor(1, 1, 1)
    elseif currentScene == "MAP" then
        map:draw()
        drawHPBar(30, 30, player.hp, player.max_hp, "Player HP")
        local bd = UI.btns.viewDeckMap; love.graphics.rectangle("line", bd.x, bd.y, bd.w, bd.h)
        love.graphics.printf(bd.label .. " (" .. (#master_deck + #host_deck) .. ")", bd.x, bd.y+13, bd.w, "center")
        local ry = 140; for _, r in ipairs(playerRelics) do love.graphics.setColor(1, 0.8, 0); love.graphics.print("["..r.name.."]", 30, ry); ry = ry + 20 end; love.graphics.setColor(1, 1, 1)
        if player.signature_card then love.graphics.print("Mastery: " .. player.mastery_kills .. "/" .. player.mastery_target .. " ("..player.signature_card.name..")", 30, ry + 10) end
        if map:isCleared() then love.graphics.setColor(1, 0.8, 0); love.graphics.printf("FLOOR CLEARED!\n\nClick anywhere to return to Title", 0, 300, 1280, "center"); love.graphics.setColor(1, 1, 1) end
    elseif currentScene == "EVENT" then
        love.graphics.printf("【 EVENT 】", 0, 150, 1280, "center"); love.graphics.printf(eventData.text, 0, 250, 1280, "center")
        local b1, b2 = UI.btns.eventA, UI.btns.eventB
        love.graphics.rectangle("line", b1.x, b1.y, b1.w, b1.h); love.graphics.printf(b1.label, b1.x, b1.y+30, b1.w, "center")
        love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h); love.graphics.printf(b2.label, b2.x, b2.y+30, b2.w, "center")
    elseif currentScene == "CAMPFIRE" then
        love.graphics.setColor(1, 0.6, 0.2); love.graphics.printf("=== CAMPFIRE ===", 0, 150, 1280, "center"); love.graphics.setColor(1, 1, 1)
        love.graphics.printf("燃え盛る炎が、冷たい肉体を温める...", 0, 200, 1280, "center")
        local btns = {UI.btns.campRest, UI.btns.campPatch, UI.btns.campUpgrade, UI.btns.campRemove}
        for _, b in ipairs(btns) do love.graphics.rectangle("line", b.x, b.y, b.w, b.h); love.graphics.printf(b.label, b.x, b.y+22, b.w, "center") end
        drawHPBar(1280/2 - 100, 600, player.hp, player.max_hp, "HP")
    elseif currentScene == "CAMPFIRE_CARD_SELECT" then
        love.graphics.printf("Select a card to " .. campfireMode, 0, 50, 1280, "center")
        local cw, ch, spX, spY = 140, 180, 20, 20; local startX = (1280 - (5 * cw + 4 * spX)) / 2; local startY = 120
        for i, item in ipairs(campfireCards) do
            local col, row = (i-1) % 5, math.floor((i-1) / 5)
            drawSingleCard(item.card, startX + col * (cw + spX), startY + row * (ch + spY), cw, ch, 1)
        end
        local cBtn = UI.btns.cancelCamp; love.graphics.rectangle("line", cBtn.x, cBtn.y, cBtn.w, cBtn.h); love.graphics.printf(cBtn.label, cBtn.x, cBtn.y+15, cBtn.w, "center")
    elseif currentScene == "BATTLE" then
        Battle.draw()
    elseif currentScene == "REWARD_CHOICE" then
        local btns = Battle.getEnemy().isBoss and {UI.btns.bossReward} or {UI.btns.possess, UI.btns.absorb}
        for _, b in ipairs(btns) do love.graphics.rectangle("line", b.x, b.y, b.w, b.h); love.graphics.printf(b.label, b.x, b.y+30, b.w, "center") end
    elseif currentScene == "REWARD_CARDS" then
        for _, r in ipairs(UI.rewards) do drawSingleCard(r, r.x, r.y, r.w, r.h, r.alpha) end
        local s = UI.btns.skip; love.graphics.rectangle("line", s.x, s.y, s.w, s.h); love.graphics.printf(s.label, s.x, s.y+15, s.w, "center")
    end
    if DeckViewer.active then DeckViewer.draw() end
end

-- マウスクリック時のシーン別入力判定
function love.mousepressed(mx, my, button)
    if button ~= 1 then return end
    if DeckViewer.active then DeckViewer.mousepressed(mx, my, button); return end

    if currentScene == "TITLE" then
        if isInside(mx, my, UI.btns.titleStart) then initGame() elseif isInside(mx, my, UI.btns.titleQuit) then love.event.quit() end
    elseif currentScene == "INTRO" then currentScene = "MAP"
    elseif currentScene == "MAP" then
        if map:isCleared() then currentScene = "TITLE"; return end 
        if isInside(mx, my, UI.btns.viewDeckMap) then DeckViewer.openMerged(master_deck, host_deck); return end
        for i, n in ipairs(map.nodes) do if map:isNodeSelectable(i) then local dx, dy = mx - n.x, my - n.y; if (dx*dx + dy*dy) <= 35*35 then n.cleared = true; startMapNode(i); break end end end
    elseif currentScene == "EVENT" then
        if isInside(mx, my, UI.btns.eventA) then eventData.fnA() elseif isInside(mx, my, UI.btns.eventB) then eventData.fnB() end
    elseif currentScene == "CAMPFIRE" then
        if isInside(mx, my, UI.btns.campRest) then player.hp = math.min(player.max_hp, player.hp + player.max_hp * 0.3); currentScene = "MAP"
        elseif isInside(mx, my, UI.btns.campPatch) then player.max_hp = player.max_hp + 5; player.hp = player.hp + 5; currentScene = "MAP"
        elseif isInside(mx, my, UI.btns.campUpgrade) then openCampfireCardSelect("UPGRADE")
        elseif isInside(mx, my, UI.btns.campRemove) then openCampfireCardSelect("REMOVE") end
    elseif currentScene == "CAMPFIRE_CARD_SELECT" then
        if isInside(mx, my, UI.btns.cancelCamp) then currentScene = "CAMPFIRE"; return end
        local cw, ch, spX, spY = 140, 180, 20, 20; local startX = (1280 - (5 * cw + 4 * spX)) / 2; local startY = 120
        for i, item in ipairs(campfireCards) do
            local col, row = (i-1) % 5, math.floor((i-1) / 5)
            local x, y = startX + col * (cw + spX), startY + row * (ch + spY)
            if mx >= x and mx <= x + cw and my >= y and my <= y + ch then
                if campfireMode == "UPGRADE" then
                    item.card.damage = (item.card.damage and item.card.damage + 3) or nil
                    item.card.block = (item.card.block and item.card.block + 3) or nil
                    item.card.name = item.card.name .. "+"
                elseif campfireMode == "REMOVE" then
                    if item.deck == "master" then table.remove(master_deck, item.idx) else table.remove(host_deck, item.idx) end
                end
                currentScene = "MAP"; break
            end
        end
    elseif currentScene == "BATTLE" then
        local nextScene = Battle.mousepressed(mx, my, button)
        if nextScene then currentScene = nextScene end
    elseif currentScene == "REWARD_CHOICE" then
        if Battle.getEnemy().isBoss and isInside(mx, my, UI.btns.bossReward) then UI.btns.bossReward.fn()
        elseif not Battle.getEnemy().isBoss and isInside(mx, my, UI.btns.possess) then UI.btns.possess.fn()
        elseif not Battle.getEnemy().isBoss and isInside(mx, my, UI.btns.absorb) then UI.btns.absorb.fn() end
    elseif currentScene == "REWARD_CARDS" then
        if isInside(mx, my, UI.btns.skip) then UI.btns.skip.fn() end
        for i, r in ipairs(UI.rewards) do if isInside(mx, my, r) then table.insert(master_deck, r); currentScene = "MAP"; break end end
    end
end

-- マウスドラッグ終了時の処理（戦闘画面の場合はbattleモジュールへ委譲）
function love.mousereleased(mx, my, button)
    if currentScene == "BATTLE" then Battle.mousereleased(mx, my, button) end
end