-- map.lua
-- プレイヤーが進行するルート（ノードの繋がり）の定義、選択判定、および描画を管理します。

local Map = {}

-- 全10マスの固定マップ構造の初期化
function Map.new()
    local m = { nodes = {}, currentNodeIndex = 0 }
    
    m.nodes = {
        { id=1,  x=100, y=360, type="combat", tier=1, paths={2, 3}, cleared=false },
        { id=2,  x=200, y=260, type="combat", tier=1, paths={4}, cleared=false },
        { id=3,  x=200, y=460, type="event",  tier=1, paths={5}, cleared=false },
        { id=4,  x=300, y=260, type="combat", tier=1, paths={6}, cleared=false },
        { id=5,  x=300, y=460, type="combat", tier=1, paths={6}, cleared=false },
        { id=6,  x=400, y=360, type="event",  tier=1, paths={7, 8}, cleared=false },
        { id=7,  x=500, y=260, type="combat", tier=1, paths={9}, cleared=false },
        { id=8,  x=500, y=460, type="combat", tier=1, paths={9}, cleared=false },
        { id=9,  x=600, y=360, type="event",  tier=1, paths={10,11}, cleared=false },
        { id=10, x=700, y=260, type="combat", tier=1, paths={12}, cleared=false },
        { id=11, x=700, y=460, type="combat", tier=1, paths={12}, cleared=false },
        { id=12, x=800, y=360, type="event",  tier=1, paths={13}, cleared=false },
        { id=13, x=920, y=360, type="campfire",tier=1,paths={14}, cleared=false },
        { id=14, x=1050,y=360, type="boss",   tier="BOSS", paths={}, cleared=false }
    }
    
    -- 指定されたノードが現在の現在地から移動可能（線で繋がっているか）を判定
    function m:isNodeSelectable(index)
        local node = self.nodes[index]
        if node.cleared then return false end
        if self.currentNodeIndex == 0 then return node.x == 100 end
        local current = self.nodes[self.currentNodeIndex]
        for _, pathId in ipairs(current.paths) do if pathId == node.id then return true end end
        return false
    end

    -- ボス（最終ノード）をクリアしたかを判定
    function m:isCleared() return self.nodes[14].cleared end
    
    -- 進行ルート（線）と各ノード（種類ごとのアイコン）を描画
    function m:draw()
        love.graphics.setColor(0.5, 0.5, 0.5)
        for _, node in ipairs(self.nodes) do
            for _, pathId in ipairs(node.paths) do
                local target = self.nodes[pathId]; love.graphics.line(node.x, node.y, target.x, target.y)
            end
        end
        for i, node in ipairs(self.nodes) do
            if node.cleared then love.graphics.setColor(0.2, 0.2, 0.2)
            elseif self:isNodeSelectable(i) then love.graphics.setColor(0.8, 0.8, 1)
            else love.graphics.setColor(0.4, 0.4, 0.4) end
            love.graphics.circle("fill", node.x, node.y, 30)
            love.graphics.setColor(1, 1, 1)
            local label = "Cmb"
            if node.type == "event" then label = "?"
            elseif node.type == "campfire" then label = "Rest"
            elseif node.type == "boss" then label = "BOSS" end
            love.graphics.printf(label, node.x - 30, node.y - 8, 60, "center")
        end
    end
    return m
end
return Map