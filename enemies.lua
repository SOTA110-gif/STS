-- enemies.lua
-- 各階層で出現する敵のステータス、憑依した際のプレイヤーの「宿体デッキ」を定義し。

local CardLibrary = require("cards")

local Enemies = {
    { id = "green_slime", name = "Slime", hp = 30, tier = 1, signature = CardLibrary.Slime[4], deck = { CardLibrary.Slime[1], CardLibrary.Slime[1], CardLibrary.Slime[2], CardLibrary.Slime[3], CardLibrary.Slime[4] } },
    { id = "goblin_mugger", name = "Goblin Mugger", hp = 25, tier = 1, signature = CardLibrary.Goblin[4], deck = { CardLibrary.Goblin[1], CardLibrary.Goblin[1], CardLibrary.Goblin[2], CardLibrary.Goblin[3], CardLibrary.Goblin[4] } },
    { id = "skeleton", name = "Skeleton", hp = 35, tier = 1, signature = CardLibrary.Skeleton[4], deck = { CardLibrary.Skeleton[1], CardLibrary.Skeleton[1], CardLibrary.Skeleton[2], CardLibrary.Skeleton[3], CardLibrary.Skeleton[4] } },
    { id = "skeleton_archer", name = "Skeleton Archer", hp = 28, tier = 1, signature = CardLibrary.Skeleton[5], deck = { CardLibrary.Skeleton[1], CardLibrary.Skeleton[1], CardLibrary.Skeleton[1], CardLibrary.Skeleton[3], CardLibrary.Skeleton[5] } },
    { id = "insect_swarm", name = "Giant Insect", hp = 32, tier = 1, signature = CardLibrary.Insect[3], deck = { CardLibrary.Insect[1], CardLibrary.Insect[1], CardLibrary.Insect[2], CardLibrary.Insect[3], CardLibrary.Insect[3] } },
    { id = "insect_beetle", name = "Horned Beetle", hp = 40, tier = 1, signature = CardLibrary.Insect[4], deck = { CardLibrary.Insect[1], CardLibrary.Insect[1], CardLibrary.Insect[2], CardLibrary.Insect[4], CardLibrary.Insect[4] } },
    { id = "boss_amalgam", name = "腐肉の集合体", hp = 100, tier = "BOSS", isBoss = true, signature = CardLibrary.SoulCards[5], deck = { CardLibrary.Slime[1], CardLibrary.Slime[5], CardLibrary.Goblin[4], CardLibrary.SoulCards[1] } }
}

return Enemies