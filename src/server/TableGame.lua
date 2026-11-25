-- Одна партия за столом. Вся логика на сервере: ходы, таймер, жизни, проверка слов.
-- Клиент только шлёт SubmitWord и получает события TableState.
--
-- Места (seats): { player = Player?, bot = "easy"|"medium"|"hard"?, name, lives, alive }
-- События для клиентов (type): start, turn, word, reject (только отправителю), timeout, eliminated, end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("KazakhRules"))
local Bot = require(script.Parent.BotAI)

local TableGame = {}
TableGame.__index = TableGame

function TableGame.new(dict, seats, tableStateRemote)
	local self = setmetatable({
		dict = dict,
		seats = seats,
		remote = tableStateRemote,
		rng = Random.new(),
		used = {},
		chain = {},
		round = 1,
		letter = nil,
		current = nil,
		deadline = 0,
		turnResult = nil, -- nil | "word" | "left"
		turnToken = 0,
		running = false,
		exhausted = false,
		onEnd = nil,
		onWord = nil,
	}, TableGame)

	-- Буква играбельна, если на неё достаточно слов в словаре и остались неиспользованные
	self._isPlayable = function(letter)
		return dict:startCount(letter) >= Config.MIN_START_COUNT and dict:hasUnused(letter, self.used)
	end

	return self
end

-- ===== вспомогательное =====

function TableGame:_snapshot()
	local out = {}
	for i, seat in self.seats do
		out[i] = {
			name = seat.name,
			lives = seat.lives,
			alive = seat.alive,
			bot = seat.bot ~= nil,
			userId = seat.player and seat.player.UserId or nil,
		}
	end
	return out
end

function TableGame:_broadcast(payload)
	for _, seat in self.seats do
		if seat.player then
			self.remote:FireClient(seat.player, payload)
		end
	end
end

function TableGame:_aliveCount()
	local n = 0
	for _, seat in self.seats do
		if seat.alive then
			n += 1
		end
	end
	return n
end

function TableGame:_humanCount()
	local n = 0
	for _, seat in self.seats do
		if seat.player and seat.alive then
			n += 1
		end
	end
	return n
end

function TableGame:_nextAliveIndex(idx)
	local n = #self.seats
	for step = 1, n do
		local i = (idx + step - 1) % n + 1
		if self.seats[i].alive then
			return i
		end
	end
	return idx
end

function TableGame:_turnTime()
	return math.max(Config.TURN_TIME_MIN, Config.TURN_TIME_BASE - (self.round - 1) * Config.TURN_TIME_STEP)
end

function TableGame:_randomPlayableLetter()
	local pool = {}
	for letter in self.dict.byFirst do
		if self._isPlayable(letter) then
			pool[#pool + 1] = letter
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[self.rng:NextInteger(1, #pool)]
end

-- Выбор следующей буквы после слова (правило «предпоследней буквы» и его обобщение)
function TableGame:_advanceLetter(word)
	self.letter = Rules.nextLetter(word, self._isPlayable) or self:_randomPlayableLetter()
	if not self.letter then
		self.exhausted = true -- слова закончились
	end
end

function TableGame:_pickStartWord()
	local letters = {}
	for letter in self.dict.byFirst do
		letters[#letters + 1] = letter
	end
	for _ = 1, 50 do
		local l = letters[self.rng:NextInteger(1, #letters)]
		local w = self.dict:pickRandom(l, self.used, self.rng)
		if w and utf8.len(w) >= 3 and Rules.nextLetter(w, self._isPlayable) then
			return w
		end
	end
	return self.dict:pickRandom(letters[1], self.used, self.rng)
end

-- ===== принятие слова =====

function TableGame:_accept(seat, word)
	self.turnResult = "word"
	self.used[word] = true
	self.chain[#self.chain + 1] = word
	self:_advanceLetter(word)
	self:_broadcast({ type = "word", by = seat.name, word = word, nextLetter = self.letter })
	if self.onWord then
		self.onWord(word)
	end
end

-- Вызывается из RemoteEvent SubmitWord (игрок -> сервер)
function TableGame:submit(player, raw)
	if not self.running or self.turnResult then
		return
	end
	local seat = self.current
	if not seat or seat.player ~= player then
		return -- не твой ход
	end
	if workspace:GetServerTimeNow() > self.deadline + Config.GRACE then
		return
	end

	local function reject(reason)
		self.remote:FireClient(player, { type = "reject", reason = reason })
	end

	local word = Rules.normalize(raw)
	if not word then
		return reject("format")
	end
	if Rules.firstLetter(word) ~= self.letter then
		return reject("letter")
	end
	if not self.dict:has(word) then
		return reject("unknown")
	end
	if self.used[word] then
		return reject("used")
	end
	-- Неверное слово НЕ сбрасывает таймер и не отнимает жизнь: игрок просто пробует ещё раз.
	self:_accept(seat, word)
end

function TableGame:_scheduleBot(seat, token, turnTime)
	local delay = Bot.plan(seat.bot, turnTime, self.rng)
	if not delay then
		return -- бот «не успеет»
	end
	task.delay(delay, function()
		if not self.running or self.turnToken ~= token or self.turnResult then
			return
		end
		local word = Bot.chooseWord(self.dict, self.letter, self.used, self.rng)
		if word then
			self:_accept(seat, word)
		end
	end)
end

function TableGame:removePlayer(player)
	for _, seat in self.seats do
		if seat.player == player then
			seat.player = nil
			seat.alive = false
			if self.current == seat and not self.turnResult then
				self.turnResult = "left"
			end
		end
	end
	if self:_humanCount() == 0 then
		self.running = false
	end
end

-- ===== игровой цикл =====

function TableGame:_playTurn(seat)
	local turnTime = self:_turnTime()
	self.current = seat
	self.turnResult = nil
	self.turnToken += 1
	local token = self.turnToken
	self.deadline = workspace:GetServerTimeNow() + turnTime

	self:_broadcast({
		type = "turn",
		who = seat.name,
		whoId = seat.player and seat.player.UserId or nil,
		letter = self.letter,
		deadline = self.deadline, -- в workspace:GetServerTimeNow(): клиент считает остаток сам
		turnTime = turnTime,
		round = self.round,
		seats = self:_snapshot(),
	})

	if seat.bot then
		self:_scheduleBot(seat, token, turnTime)
	end

	while self.running and not self.turnResult and workspace:GetServerTimeNow() < self.deadline + Config.GRACE do
		task.wait(0.05)
	end

	if not self.running then
		return
	end
	if self.turnResult == "word" then
		task.wait(Config.BETWEEN_TURNS)
		return
	end
	if self.turnResult == "left" then
		return
	end

	-- Таймер истёк: минус жизнь. Буква остаётся прежней для следующего игрока.
	seat.lives -= 1
	self:_broadcast({ type = "timeout", who = seat.name, lives = seat.lives })
	if seat.lives <= 0 then
		seat.alive = false
		self:_broadcast({ type = "eliminated", who = seat.name })
	end
	task.wait(Config.BETWEEN_TURNS)
end

function TableGame:run()
	self.running = true

	local startWord = self:_pickStartWord()
	self.used[startWord] = true
	self.chain[1] = startWord
	self:_advanceLetter(startWord)
	self:_broadcast({ type = "start", startWord = startWord, seats = self:_snapshot() })
	if self.onWord then
		self.onWord(startWord)
	end
	task.wait(1)

	local idx = 0
	while self.running and not self.exhausted and self:_aliveCount() > 1 do
		local nextIdx = self:_nextAliveIndex(idx)
		if nextIdx <= idx then
			self.round += 1 -- прошли полный круг
		end
		idx = nextIdx
		self:_playTurn(self.seats[idx])
	end

	self:_finish()
end

function TableGame:_finish()
	local winner = nil
	if self:_aliveCount() == 1 then
		for _, seat in self.seats do
			if seat.alive then
				winner = seat
			end
		end
	end
	self.running = false
	self:_broadcast({ type = "end", winner = winner and winner.name or nil, words = #self.chain })
	if self.onEnd then
		self.onEnd(self, winner)
	end
end

return TableGame
