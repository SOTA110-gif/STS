-- battle.lua
-- 戦闘中のドロー、ターン進行、カードのドラッグ操作、各種効果処理など
-- メインループから肥大化しやすいバトルロジックを分離した専用モジュールです。

local Battle = {}
local Enemy = require("enemy")
local DeckViewer = require("deck_viewer")

-- === ローカル状態変数 ===
local state = "PLAYING"
local player, enemy, playerRelics, master_deck, host_deck
local battle_deck, hand, discard, exhaust_pile
local draggedCard, draggedCardIdx
local mastery_achieved_this_battle = false
local UI = { btns = {} }

-- 汎用ユーティリティ関数
local function lerp(a, b, t) return a + (b - a) * t end
local function shuffle(t) for i = #t, 2, -1 do local j = love.math.random(i); t[i], t[j] = t[j], t[i] end end
local function isInside(mx, my, ent) return mx >= ent.x and mx <= ent.x + ent.w and my >= ent.y and my <= ent.y + ent.h end
local function createEntity(x, y, w, h, data)
    local e = data or {}; e.x, e.y, e.target_x, e.target_y = x, y, x, y; e.w, e.h, e.alpha = w, h, 0; return e
end

-- HPバーの描画ヘルパー
local function drawHPBar(x, y, hp, max_hp, label, subtext)
    local w = 200
    love.graphics.setColor(1, 1, 1); love.graphics.printf(label, x, y - 20, w, "center")
    love.graphics.rectangle("line", x, y, w, 15)
    love.graphics.setColor(0.2, 0.8, 0.2)
    local fillW = w * (math.max(0, hp) / max_hp)
    if fillW > 0 then love.graphics.rectangle("fill", x, y, fillW, 15) end
    love.graphics.setColor(1, 1, 1); love.graphics.printf(math.floor(hp) .. " / " .. max_hp, x, y + 20, w, "center")
    if subtext then love.graphics.setColor(0.6, 0.4, 0.2); love.graphics.printf(subtext, x, y + 40, w, "center"); love.graphics.setColor(1, 1, 1) end
end

-- 戦闘画面用のカード単体描画ヘルパー（ドラッグ中のハイライトにも対応）
local function drawSingleCard(c, x, y, cw, ch, alpha, isDragged)
    if isDragged then love.graphics.setColor(0.3, 0.3, 0.5, 0.9) else love.graphics.setColor(0.1, 0.1, 0.1, alpha) end
    love.graphics.rectangle("fill", x, y, cw, ch, 10)
    love.graphics.setColor(1, 1, 1, isDragged and 1 or alpha); love.graphics.rectangle("line", x, y, cw, ch, 10)
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

-- 山札からカードを手札に引く。山札が空の場合は捨て札をシャッフルして再構成する。
local function drawCard()
    if #battle_deck == 0 and #discard > 0 then for i = #discard, 1, -1 do table.insert(battle_deck, table.remove(discard, i)) end; shuffle(battle_deck) end
    if #battle_deck > 0 and #hand < 8 then table.insert(hand, createEntity(1200, 700, 140, 180, table.remove(battle_deck, 1))) end
end

-- 毒やトゲなど、直接攻撃以外の手段（パッシブ）で敵を倒した際にもマスタリー条件を満たせるかをチェックする
local function checkPassiveMastery(kill_type)
    if enemy.hp <= 0 and state ~= "WIN" then
        state = "WIN"
        if player.signature_card and not player.mastery_completed then
            local isMatch = false
            if kill_type == "poison" and player.signature_card.poison then isMatch = true end
            if kill_type == "thorns" and player.signature_card.thorns then isMatch = true end
            if kill_type == "delay" and player.signature_card.delayed_damage then isMatch = true end
            if isMatch then
                player.mastery_kills = player.mastery_kills + 1
                if player.mastery_kills >= 3 then
                    mastery_achieved_this_battle = true
                    player.mastery_completed = true
                    table.insert(master_deck, player.signature_card)
                end
            end
        end
    end
end

-- ターン終了時の処理を一括管理（敵の攻撃、バフの消化、プレイヤーの劣化・毒ダメージなど）
local function executeEndTurn()
    if state ~= "PLAYING" then return end
    if enemy.poison > 0 then enemy:takeDamage(enemy.poison); enemy.poison = enemy.poison - 1; checkPassiveMastery("poison") end
    if state == "PLAYING" then
        local inc = enemy:getActualIntentDamage(player)
        if inc > 0 then
            if player.block >= inc then player.block = player.block - inc else inc = inc - player.block; player.block = 0; player.hp = math.max(0, player.hp - inc) end
            if player.thorns > 0 then enemy:takeDamage(player.thorns); checkPassiveMastery("thorns") end
        end
    end
    local decay_total = 1
    for _, r in ipairs(playerRelics) do if r.id == "insomnia" then decay_total = decay_total + r.decay_bonus end end
    player.max_hp = player.max_hp - decay_total; player.hp = math.min(player.hp, player.max_hp)
    if player.poison > 0 then player.hp = player.hp - player.poison; player.poison = player.poison - 1 end
    if player.max_hp <= 0 or player.hp <= 0 then state = "LOSE" end
    
    player.vulnerable = math.max(0, player.vulnerable - 1)
    enemy.vulnerable = math.max(0, enemy.vulnerable - 1)
    player.split_buff = 0
    if state == "PLAYING" then enemy:planNextAction() end
    
    for i=#hand,1,-1 do table.insert(discard, table.remove(hand, i)) end
    player.energy = player.max_energy
    for _, r in ipairs(playerRelics) do if r.id == "insomnia" then player.energy = player.energy + r.energy_bonus end end
    player.block = 0
    if player.soul_impact > 0 then enemy:takeDamage(player.soul_impact); player.soul_impact = 0; checkPassiveMastery("delay") end
    for i=1,4 do drawCard() end
end

-- 戦闘開始時の初期化処理（メインループから呼ばれる）
function Battle.start(p_ref, m_deck, h_deck, enemyData, relics)
    player, master_deck, host_deck, playerRelics = p_ref, m_deck, h_deck, relics
    enemy = Enemy.new(enemyData.name, enemyData.hp, enemyData.isBoss); enemy.deckData = enemyData.deck
    state, mastery_achieved_this_battle, draggedCard = "PLAYING", false, nil
    
    player.energy = player.max_energy
    for _, r in ipairs(playerRelics) do if r.id == "insomnia" then player.energy = player.energy + r.energy_bonus end end
    player.block, player.strength, player.vulnerable, player.split_buff, player.thorns, player.soul_impact = 0, 0, 0, 0, 0, 0
    
    battle_deck, discard, exhaust_pile, hand = {}, {}, {}, {}
    -- ディープコピーで山札を作成
    for _, c in ipairs(master_deck) do local nc={}; for k,v in pairs(c) do nc[k]=v end; table.insert(battle_deck, nc) end
    for _, c in ipairs(host_deck) do local nc={}; for k,v in pairs(c) do nc[k]=v end; table.insert(battle_deck, nc) end
    shuffle(battle_deck)
    for i=1, 4 do drawCard() end

    UI.btns.endTurn = createEntity(1100, 450, 120, 40, { label = "End Turn" })
    UI.btns.viewDraw = createEntity(30, 650, 120, 40, { label = "Draw Pile" })
    UI.btns.viewDiscard = createEntity(1130, 600, 120, 40, { label = "Discard" })
    UI.btns.viewExhaust = createEntity(1130, 650, 120, 40, { label = "Exhaust" })
end

-- 手札のアニメーション（Lerp）とドラッグ追従の更新処理
function Battle.update(dt)
    local function updateEnt(e) e.x = lerp(e.x, e.target_x, dt*12); e.y = lerp(e.y, e.target_y, dt*12); e.alpha = lerp(e.alpha, 1, dt*5) end
    local cw, sp = 140, 20; local sx = (1280/2) - ((#hand*cw + (#hand-1)*sp)/2)
    for i, c in ipairs(hand) do if c ~= draggedCard then c.target_x = sx + (i-1)*(cw+sp); c.target_y = 520 end; updateEnt(c) end
    if draggedCard then draggedCard.target_x = love.mouse.getX() - draggedCard.w/2; draggedCard.target_y = love.mouse.getY() - draggedCard.h/2 end
end

-- 戦闘画面全体（敵、プレイヤーHP、ステータス、手札、ボタン）の描画
function Battle.draw()
    enemy:draw(player)
    local decay_total = 1; for _, r in ipairs(playerRelics) do if r.id == "insomnia" then decay_total = decay_total + r.decay_bonus end end
    drawHPBar(540, 430, player.hp, player.max_hp, "Player", "(Max HP -"..decay_total..")")
    
    love.graphics.print("Energy: " .. player.energy, 430, 410)
    local sy = 430
    if player.block > 0 then love.graphics.setColor(0.4, 0.6, 1); love.graphics.print("Block: " .. player.block, 430, sy); sy=sy+20 end
    if player.vulnerable > 0 then love.graphics.setColor(0.8, 0.2, 0.8); love.graphics.print("Vuln: " .. player.vulnerable, 430, sy); sy=sy+20 end
    if player.poison > 0 then love.graphics.setColor(0.2, 0.8, 0.2); love.graphics.print("Poison: " .. player.poison, 430, sy); sy=sy+20 end
    if player.thorns > 0 then love.graphics.setColor(1, 0.6, 0.2); love.graphics.print("Thorns: " .. player.thorns, 430, sy); sy=sy+20 end
    if player.soul_impact > 0 then love.graphics.setColor(0.8, 0.4, 0.8); love.graphics.print("Delay: " .. player.soul_impact, 430, sy); sy=sy+20 end
    if player.split_buff > 0 then love.graphics.setColor(0.2, 1, 0.2); love.graphics.print("Split Active!", 430, sy) end
    love.graphics.setColor(1, 1, 1)

    local bd, bdi, bex = UI.btns.viewDraw, UI.btns.viewDiscard, UI.btns.viewExhaust
    love.graphics.rectangle("line", bd.x, bd.y, bd.w, bd.h); love.graphics.printf(bd.label..": "..#battle_deck, bd.x, bd.y+10, bd.w, "center")
    love.graphics.rectangle("line", bdi.x, bdi.y, bdi.w, bdi.h); love.graphics.printf(bdi.label..": "..#discard, bdi.x, bdi.y+10, bdi.w, "center")
    love.graphics.rectangle("line", bex.x, bex.y, bex.w, bex.h); love.graphics.printf(bex.label..": "..#exhaust_pile, bex.x, bex.y+10, bex.w, "center")

    for _, c in ipairs(hand) do if c ~= draggedCard then drawSingleCard(c, c.x, c.y, c.w, c.h, c.alpha, false) end end
    if draggedCard then drawSingleCard(draggedCard, draggedCard.x, draggedCard.y, draggedCard.w, draggedCard.h, 1, true) end

    if state == "PLAYING" then local b = UI.btns.endTurn; love.graphics.rectangle("line", b.x, b.y, b.w, b.h); love.graphics.printf(b.label, b.x, b.y+10, b.w, "center")
    elseif state == "WIN" then love.graphics.setColor(1, 1, 0); love.graphics.printf("VICTORY! Click to continue", 0, 400, 1280, "center"); love.graphics.setColor(1, 1, 1)
    elseif state == "LOSE" then love.graphics.setColor(1, 0, 0); love.graphics.printf("BODY DESTROYED... Click to Return to Title", 0, 400, 1280, "center"); love.graphics.setColor(1, 1, 1) end
end

-- UIクリック判定と、メインループにシーン遷移を促す戻り値の送信
function Battle.mousepressed(mx, my, button)
    if state == "WIN" then return "REWARD_CHOICE" end
    if state == "LOSE" then return "TITLE" end
    
    if state == "PLAYING" then
        if isInside(mx, my, UI.btns.endTurn) then executeEndTurn(); return nil end
        if isInside(mx, my, UI.btns.viewDraw) then DeckViewer.openSingle(battle_deck, "Draw Pile"); return nil end
        if isInside(mx, my, UI.btns.viewDiscard) then DeckViewer.openSingle(discard, "Discard Pile"); return nil end
        if isInside(mx, my, UI.btns.viewExhaust) then DeckViewer.openSingle(exhaust_pile, "Exhaust Pile"); return nil end
        for i = #hand, 1, -1 do if isInside(mx, my, hand[i]) then draggedCard = hand[i]; draggedCardIdx = i; break end end
    end
    return nil
end

-- ドラッグ終了時のカード使用判定および各種効果（バフ・デバフ含む）の適用
function Battle.mousereleased(mx, my, button)
    if not draggedCard then return end
    if my < 450 and player.energy >= draggedCard.cost then
        local c = table.remove(hand, draggedCardIdx)
        player.energy = player.energy - c.cost
        local times = (player.split_buff > 0 and not c.split_buff) and (1 + player.split_buff) or 1
        player.split_buff = 0
        
        for _=1, times do
            if c.double_buffs then
                if player.strength > 0 then player.strength = player.strength * 2 end
                if player.thorns > 0 then player.thorns = player.thorns * 2 end
            end
            if c.double_debuffs then
                if enemy.poison > 0 then enemy.poison = enemy.poison * 2 end
                if enemy.vulnerable > 0 then enemy.vulnerable = enemy.vulnerable * 2 end
            end

            if c.poison then enemy.poison = enemy.poison + c.poison end
            if c.vulnerable then enemy.vulnerable = enemy.vulnerable + c.vulnerable end
            if c.thorns then player.thorns = player.thorns + c.thorns end
            if c.delayed_damage then player.soul_impact = player.soul_impact + c.delayed_damage end
            if c.heal then player.hp = math.min(player.max_hp, player.hp + c.heal) end
            
            local dmg_val = c.damage
            if c.damage_equals_block then dmg_val = player.block end
            
            if dmg_val then
                enemy:takeDamage(dmg_val + player.strength)
                for _, r in ipairs(playerRelics) do if r.id == "gluttony" then r.attack_count = r.attack_count + 1; if r.attack_count >= 3 then player.max_hp = player.max_hp + 1; player.hp = math.min(player.max_hp, player.hp+1); r.attack_count = 0 end end end
                if enemy.hp <= 0 and state ~= "WIN" then
                    state = "WIN"
                    if player.signature_card and c.name == player.signature_card.name and not player.mastery_completed then
                        player.mastery_kills = player.mastery_kills + 1
                        if player.mastery_kills >= 3 then mastery_achieved_this_battle, player.mastery_completed = true, true; table.insert(master_deck, player.signature_card) end
                    end
                end
            end
            if c.block then player.block = player.block + c.block end
            if c.energy_gain then player.energy = player.energy + c.energy_gain end
            if c.draw_cards then for k=1, c.draw_cards do drawCard() end end
            if c.split_buff then player.split_buff = player.split_buff + c.split_buff end
            if c.self_decay then player.max_hp = player.max_hp - c.self_decay; player.hp = math.min(player.hp, player.max_hp); if player.max_hp <= 0 and state ~= "WIN" then state = "LOSE" end end
        end
        if c.exhaust then table.insert(exhaust_pile, c) else table.insert(discard, c) end
    end
    draggedCard, draggedCardIdx = nil, nil
end

function Battle.getEnemy() return enemy end

return Battle