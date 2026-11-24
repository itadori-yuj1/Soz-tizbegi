-- Словарь: грузится один раз при старте сервера, индексируется по первой букве.
-- Данные лежат в ServerStorage.WordData: любые ModuleScript, каждый возвращает массив строк.
-- Можно разбивать по буквам (WordsA, WordsB…), чтобы не упираться в размер скрипта.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KazakhRules"))

local Dictionary = {}
Dictionary.__index = Dictionary

function Dictionary.new(dataFolder)
	local self = setmetatable({
		set = {}, -- [слово] = true
		byFirst = {}, -- [буква] = { слова }
		total = 0,
	}, Dictionary)

	for _, mod in dataFolder:GetChildren() do
		if mod:IsA("ModuleScript") then
			for _, raw in require(mod) do
				local word = Rules.normalize(raw)
				if word and not self.set[word] then
					self.set[word] = true
					local first = Rules.firstLetter(word)
					local list = self.byFirst[first]
					if not list then
						list = {}
						self.byFirst[first] = list
					end
					list[#list + 1] = word
					self.total += 1
				end
			end
		end
	end

	return self
end

function Dictionary:has(word)
	return self.set[word] == true
end

function Dictionary:startCount(letter)
	local list = self.byFirst[letter]
	return list and #list or 0
end

-- Есть ли ещё неиспользованное слово на эту букву
function Dictionary:hasUnused(letter, used)
	local list = self.byFirst[letter]
	if not list then
		return false
	end
	for _, w in list do
		if not used[w] then
			return true
		end
	end
	return false
end

-- Случайное неиспользованное слово на букву (для бота и стартового слова)
function Dictionary:pickRandom(letter, used, rng)
	local list = self.byFirst[letter]
	if not list then
		return nil
	end
	for _ = 1, 24 do
		local w = list[rng:NextInteger(1, #list)]
		if not used[w] then
			return w
		end
	end
	local free = {}
	for _, w in list do
		if not used[w] then
			free[#free + 1] = w
		end
	end
	if #free == 0 then
		return nil
	end
	return free[rng:NextInteger(1, #free)]
end

return Dictionary
