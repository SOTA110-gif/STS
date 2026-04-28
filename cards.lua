-- cards.lua
-- ゲーム内に登場するすべてのカードの基礎データ（名前、コスト、各種効果の数値）を管理します。
-- 新しいカードや効果を追加する際はこのテーブルを拡張します。

local Cards = {
    Basic = {
        { name = "Strike", cost = 1, damage = 6 },
        { name = "Defend", cost = 1, block = 5 }
    },
    Slime = {
        { name = "Tackle", cost = 1, damage = 5 },
        { name = "Slime Guard", cost = 1, block = 6 },
        { name = "Split", cost = 1, split_buff = 1 }, 
        { name = "Acid Spray", cost = 1, damage = 3, poison = 3 },
        { name = "Explosion", cost = 1, damage = 15, self_decay = 2 } 
    },
    Goblin = {
        { name = "Quick Strike", cost = 0, damage = 4 },
        { name = "Acrobatics", cost = 1, block = 5, draw_cards = 2 },
        { name = "Adrenaline", cost = 0, energy_gain = 2, self_decay = 2 },
        { name = "Backstab", cost = 2, damage = 14, vulnerable = 1 } 
    },
    Skeleton = {
        { name = "Bone Strike", cost = 1, damage = 5 },
        { name = "Bone Wall", cost = 1, block = 8 },
        { name = "Iron Wave", cost = 1, damage = 5, block = 5 },
        { name = "Shield Bash", cost = 2, damage_equals_block = true },
        { name = "Piercing Arrow", cost = 1, damage = 6, vulnerable = 2 }
    },
    Insect = {
        { name = "Bite", cost = 1, damage = 4 },
        { name = "Poison Sting", cost = 1, damage = 3, poison = 4 },
        { name = "Spiked Shell", cost = 1, damage = 3, block = 4, thorns = 2 },
        { name = "Pheromone", cost = 1, strength = 2 }
    },
    SoulCards = {
        { name = "Phantom Slash", cost = 1, damage = 10 },
        { name = "Ethereal Wall", cost = 1, block = 9 },
        { name = "Haste", cost = 0, draw_cards = 2, exhaust = true },
        { name = "Flesh Repair", cost = 2, heal = 10, exhaust = true },
        { name = "Soul Impact", cost = 2, delayed_damage = 15 },
        { name = "Blessing", cost = 2, draw_cards = 1, double_buffs = true, exhaust = true },
        { name = "Curse", cost = 1, double_debuffs = true, exhaust = true }
    }
}
return Cards