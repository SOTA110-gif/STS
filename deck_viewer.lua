-- deck_viewer.lua
-- 山札や捨て札、デッキ全体を一覧で確認し、ページ切り替えを行うUIモジュールです。

local DeckViewer = {
    active = false, cards = {}, title = "", page = 1, maxPage = 1,
    closeBtn = {x = 1100, y = 30, w = 120, h = 40, label = "CLOSE"},
    prevBtn  = {x = 500, y = 650, w = 100, h = 40, label = "< PREV"},
    nextBtn  = {x = 680, y = 650, w = 100, h = 40, label = "NEXT >"}
}

-- マウス座標がUI要素の短形内にあるか判定
local function isInside(mx, my, ent)
    return mx >= ent.x and mx <= ent.x + ent.w and my >= ent.y and my <= ent.y + ent.h
end

-- 戦闘中の単一パイル（山札、捨て札、廃棄札）を閲覧モードで開く
function DeckViewer.openSingle(cards, title)
    DeckViewer.cards = {}
    for _, c in ipairs(cards or {}) do
        local copy = { _source = "Pile" }; for k,v in pairs(c) do copy[k] = v end
        table.insert(DeckViewer.cards, copy)
    end
    DeckViewer.title = title or "Pile"
    DeckViewer.page = 1
    DeckViewer.maxPage = math.max(1, math.ceil(#DeckViewer.cards / 10))
    DeckViewer.active = true
end

-- マップ画面用の「魂」と「肉体」の2つのデッキを結合し、色分け表示して開く
function DeckViewer.openMerged(soul_cards, host_cards)
    DeckViewer.cards = {}
    for _, c in ipairs(soul_cards or {}) do
        local copy = { _source = "Soul" }; for k,v in pairs(c) do copy[k] = v end
        table.insert(DeckViewer.cards, copy)
    end
    for _, c in ipairs(host_cards or {}) do
        local copy = { _source = "Host" }; for k,v in pairs(c) do copy[k] = v end
        table.insert(DeckViewer.cards, copy)
    end
    DeckViewer.title = "Full Deck Overview"
    DeckViewer.page = 1
    DeckViewer.maxPage = math.max(1, math.ceil(#DeckViewer.cards / 10))
    DeckViewer.active = true
end

-- UIを閉じる
function DeckViewer.close() DeckViewer.active = false end

-- 全画面を覆う半透明背景と、カード一覧、ページネーションを描画
function DeckViewer.draw()
    love.graphics.setColor(0, 0, 0, 0.95); love.graphics.rectangle("fill", 0, 0, 1280, 720); love.graphics.setColor(1, 1, 1)
    love.graphics.printf(DeckViewer.title .. " (" .. #DeckViewer.cards .. " Cards)", 0, 40, 1280, "center")

    local startIdx = (DeckViewer.page - 1) * 10 + 1
    local endIdx = math.min(startIdx + 9, #DeckViewer.cards)
    local cw, ch, spX, spY = 140, 180, 20, 40
    local startX = (1280 - (5 * cw + 4 * spX)) / 2; local startY = 120

    for i = startIdx, endIdx do
        local c = DeckViewer.cards[i]
        local row, col = math.floor((i - startIdx) / 5), (i - startIdx) % 5
        local x, y = startX + col * (cw + spX), startY + row * (ch + spY)

        local isSoul, isHost = (c._source == "Soul"), (c._source == "Host")
        if isSoul then love.graphics.setColor(0.1, 0.15, 0.25, 1) elseif isHost then love.graphics.setColor(0.25, 0.1, 0.1, 1) else love.graphics.setColor(0.1, 0.1, 0.1, 1) end
        love.graphics.rectangle("fill", x, y, cw, ch, 10)

        if isSoul then love.graphics.setColor(1, 0.8, 0, 1); love.graphics.printf("[ SOUL ]", x, y - 20, cw, "center")
        elseif isHost then love.graphics.setColor(1, 0.4, 0.4, 1); love.graphics.printf("[ HOST ]", x, y - 20, cw, "center")
        else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.rectangle("line", x, y, cw, ch, 10)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(c.name, x, y+10, cw, "center"); love.graphics.print("C:"..c.cost, x+105, y+5)

        local ty = y+50
        if c.damage then love.graphics.setColor(1,0.4,0.4); love.graphics.printf("Dmg:"..c.damage, x, ty, cw, "center"); ty=ty+20 end
        if c.damage_equals_block then love.graphics.setColor(1,0.4,0.4); love.graphics.printf("Dmg:Block", x, ty, cw, "center"); ty=ty+20 end
        if c.block then love.graphics.setColor(0.4,0.7,1); love.graphics.printf("Blk:"..c.block, x, ty, cw, "center"); ty=ty+20 end
        if c.draw_cards then love.graphics.setColor(0.2,0.8,0.8); love.graphics.printf("Draw:"..c.draw_cards, x, ty, cw, "center"); ty=ty+20 end
        if c.energy_gain then love.graphics.setColor(1,0.8,0.2); love.graphics.printf("Ene:+"..c.energy_gain, x, ty, cw, "center"); ty=ty+20 end
        if c.heal then love.graphics.setColor(0.2,1,0.2); love.graphics.printf("Heal:"..c.heal, x, ty, cw, "center"); ty=ty+20 end
        if c.self_decay then love.graphics.setColor(0.6,0.4,0.2); love.graphics.printf("Dec:-"..c.self_decay, x, ty, cw, "center"); ty=ty+20 end
        if c.poison then love.graphics.setColor(0.2,0.8,0.2); love.graphics.printf("Psn:"..c.poison, x, ty, cw, "center"); ty=ty+20 end
        if c.vulnerable then love.graphics.setColor(0.8,0.2,0.8); love.graphics.printf("Vuln:"..c.vulnerable, x, ty, cw, "center"); ty=ty+20 end
        if c.thorns then love.graphics.setColor(1,0.6,0.2); love.graphics.printf("Thorns:"..c.thorns, x, ty, cw, "center"); ty=ty+20 end
        if c.delayed_damage then love.graphics.setColor(0.8,0.4,0.8); love.graphics.printf("Delay:"..c.delayed_damage, x, ty, cw, "center"); ty=ty+20 end
        if c.strength then love.graphics.setColor(1,0.2,0.2); love.graphics.printf("Str:+"..c.strength, x, ty, cw, "center"); ty=ty+20 end
        if c.double_buffs then love.graphics.setColor(1,0.8,0.2); love.graphics.printf("Double Buffs", x, ty, cw, "center"); ty=ty+20 end
        if c.double_debuffs then love.graphics.setColor(0.8,0.2,0.8); love.graphics.printf("Double Debuffs", x, ty, cw, "center"); ty=ty+20 end
        if c.exhaust then love.graphics.setColor(0.5,0.5,0.5); love.graphics.printf("Exhaust", x, ty, cw, "center"); ty=ty+20 end
        love.graphics.setColor(1,1,1)
    end

    local cb = DeckViewer.closeBtn
    love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h); love.graphics.printf(cb.label, cb.x, cb.y+15, cb.w, "center")
    if DeckViewer.page > 1 then local pb = DeckViewer.prevBtn; love.graphics.rectangle("line", pb.x, pb.y, pb.w, pb.h); love.graphics.printf(pb.label, pb.x, pb.y+15, pb.w, "center") end
    if DeckViewer.page < DeckViewer.maxPage then local nb = DeckViewer.nextBtn; love.graphics.rectangle("line", nb.x, nb.y, nb.w, nb.h); love.graphics.printf(nb.label, nb.x, nb.y+15, nb.w, "center") end
    love.graphics.printf("Page " .. DeckViewer.page .. " / " .. DeckViewer.maxPage, 0, 680, 1280, "center")
end

-- ビュワー内のボタンクリックのハンドリング
function DeckViewer.mousepressed(mx, my, button)
    if isInside(mx, my, DeckViewer.closeBtn) then DeckViewer.close(); return true end
    if DeckViewer.page > 1 and isInside(mx, my, DeckViewer.prevBtn) then DeckViewer.page = DeckViewer.page - 1; return true end
    if DeckViewer.page < DeckViewer.maxPage and isInside(mx, my, DeckViewer.nextBtn) then DeckViewer.page = DeckViewer.page + 1; return true end
    return true
end

return DeckViewer