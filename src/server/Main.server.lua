-- Точка входа сервера: создаёт RemoteEvent'ы, грузит словарь, запускает тренировочные партии.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Dictionary = require(script.Parent.Dictionary)
local TableGame = require(script.Parent.TableGame)
local Bot = require(script.Parent.BotAI)

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "SozRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local tableState = makeRemote("TableState") -- сервер -> клиент
local submitWord = makeRemote("SubmitWord") -- клиент -> сервер
local joinPractice = makeRemote("JoinPractice") -- клиент -> сервер

-- Словарь
local dict = Dictionary.new(ServerStorage:WaitForChild("WordData"))
print(("[Сөз Тізбегі] слов в словаре: %d"):format(dict.total))

-- Партии
local gameOf = {} -- [Player] = TableGame

-- Простейший лимит: не больше 6 отправок слова в секунду
local submitLog = {}
local function allowSubmit(player)
	local now = os.clock()
	local e = submitLog[player]
	if not e or now - e.t >= 1 then
		submitLog[player] = { t = now, n = 1 }
		return true
	end
	e.n += 1
	return e.n <= 6
end

submitWord.OnServerEvent:Connect(function(player, text)
	local g = gameOf[player]
	if g and allowSubmit(player) then
		g:submit(player, text)
	end
end)

joinPractice.OnServerEvent:Connect(function(player, level, botCount)
	if gameOf[player] then
		return
	end
	if type(level) ~= "string" or not Bot.LEVELS[level] then
		level = "easy"
	end
	botCount = (type(botCount) == "number") and math.clamp(math.floor(botCount), 1, 3) or 1

	local seats = {
		{ player = player, name = player.DisplayName, lives = Config.LIVES, alive = true },
	}
	for i = 1, botCount do
		seats[#seats + 1] = { bot = level, name = "Бот " .. i, lives = Config.LIVES, alive = true }
	end

	local g = TableGame.new(dict, seats, tableState)
	g.onEnd = function(game_)
		for _, seat in game_.seats do
			if seat.player then
				gameOf[seat.player] = nil
			end
		end
		gameOf[player] = nil
	end
	gameOf[player] = g
	task.spawn(g.run, g)
end)

Players.PlayerRemoving:Connect(function(player)
	local g = gameOf[player]
	if g then
		g:removePlayer(player)
		gameOf[player] = nil
	end
	submitLog[player] = nil
end)
