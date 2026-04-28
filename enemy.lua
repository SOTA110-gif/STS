-- enemy.lua
-- 戦闘中の敵キャラクターの振る舞い（AI）、ステータス管理、描画を担当するクラスです。

local Enemy = {}

-- 敵インスタンスの生成と初期化
function Enemy.new(name, hp, isBoss)
    local e = {
        name = name, hp = hp, max_hp = hp, intent_damage = 0,
        vulnerable = 0, strength = 0, poison = 0, turnCount = 0, isBoss = isBoss or false
    }

    -- プレイヤーの防御力や弱体状態（vulnerable）を加味した、実際の予定ダメージを計算
    function e:getActualIntentDamage(player)
        if self.intent_damage == 0 then return 0 end
        local dmg = self.intent_damage + self.strength
        if player.vulnerable > 0 then dmg = math.floor(dmg * 1.5) end
        return dmg
    end

    -- ボス専用の特殊な行動パターン、または通常敵のランダム行動を決定するAIルーチン
    function e:planNextAction()
        self.turnCount = self.turnCount + 1
        if self.name == "腐肉の集合体" then
            local mod = self.turnCount % 3
            if mod == 1 then self.intent_damage = 0; self.strength = self.strength + 2 
            elseif mod == 2 then self.intent_damage = 8 
            else self.intent_damage = 15 end 
        else self.intent_damage = love.math.random(5, 10) end
    end

    -- 敵のグラフィック、HPバー、意図（次の行動）、各種状態異常を描画
    function e:draw(player)
        local cx, cy = 1280 / 2, 200
        local radius = self.isBoss and 80 or 50
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.printf(self.name, cx - 150, cy - 120, 300, "center")
        love.graphics.rectangle("line", cx - 100, cy + radius + 10, 200, 15)
        love.graphics.rectangle("fill", cx - 100, cy + radius + 10, 200 * (self.hp / self.max_hp), 15)
        love.graphics.printf(math.floor(self.hp) .. " / " .. self.max_hp, cx - 100, cy + radius + 30, 200, "center")
        local actual_dmg = self:getActualIntentDamage(player)
        local intent_text = actual_dmg > 0 and "Next: Attack " .. actual_dmg or "Next: Buffing..."
        love.graphics.printf(intent_text, cx - 100, cy - radius - 50, 200, "center")
        local sy = cy - 20
        if self.vulnerable > 0 then love.graphics.setColor(0.8, 0.2, 0.8); love.graphics.print("Vuln: " .. self.vulnerable, cx + radius + 20, sy); sy = sy + 20 end
        if self.poison > 0 then love.graphics.setColor(0.2, 0.8, 0.2); love.graphics.print("Poison: " .. self.poison, cx + radius + 20, sy); sy = sy + 20 end
        if self.strength > 0 then love.graphics.setColor(1, 0.2, 0.2); love.graphics.print("Str: " .. self.strength, cx + radius + 20, sy) end
        love.graphics.setColor(1, 1, 1)
    end

    -- ダメージ計算（HPが0未満にならないように補正）
    function e:takeDamage(amount) self.hp = math.max(0, self.hp - amount) end
    
    e:planNextAction()
    return e
end

return Enemy