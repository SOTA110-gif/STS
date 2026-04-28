-- button.lua
local Button = {}

-- 新しいボタンを作るための関数
function Button.new(x, y, width, height, text, onClickFunc)
    local btn = {
        x = x,
        y = y,
        w = width,
        h = height,
        text = text,
        onClick = onClickFunc -- 押されたときに実行する処理
    }

    -- ボタンを描画する機能
    function btn:draw()
        love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
        love.graphics.print(self.text, self.x + 10, self.y + 15)
    end

    -- クリックされたか判定する機能
    function btn:checkClick(mx, my)
        if mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h then
            self.onClick() -- 登録された処理を実行
            return true
        end
        return false
    end

    return btn
end

return Button