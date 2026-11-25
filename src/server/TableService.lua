-- Лобби со столами. Генерирует столы со стульями в Workspace.SozLobby.
-- Правила старта: >= 2 игроков за столом -> отсчёт (3 с, если стол полный; иначе 8 с).
-- Любое изменение состава перезапускает отсчёт. Во время партии пустые места закрыты.
--
-- Позже столы можно нарисовать вручную в Studio: достаточно модели с Seat'ами и
-- заменить _buildTable на разбор готовых моделей.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TableGame = require(script.Parent.TableGame)

local TableService = {}
TableService.__index = TableService

local function playerFromSeat(seat)
	local hum = seat.Occupant
	if not hum then
		return nil
	end
	return Players:GetPlayerFromCharacter(hum.Parent)
end

function TableService.new(dict, remote, gameOf)
	local self = setmetatable({
		dict = dict,
		remote = remote,
		gameOf = gameOf, -- общий реестр [Player] = TableGame (его ведёт и Main)
		seatedAt = {}, -- [Player] = tbl
		tables = {},
	}, TableService)
	self:_build()
	return self
end

function TableService:isSeated(player)
	return self.seatedAt[player] ~= nil
end

-- ===== построение лобби =====

function TableService:_build()
	local folder = Instance.new("Folder")
	folder.Name = "SozLobby"
	folder.Parent = workspace

	for i, capacity in Config.LOBBY_LAYOUT do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local center = Vector3.new((col - 1) * 26, 0, -40 - row * 26)
		self:_buildTable(i, capacity, center, folder)
	end
end

function TableService:_buildTable(index, capacity, center, folder)
	local model = Instance.new("Model")
	model.Name = "Table" .. index
	model.Parent = folder

	local function part(name, size, cf, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end

	local upright = CFrame.Angles(0, 0, math.pi / 2) -- цилиндр Roblox лежит вдоль X; ставим вертикально
	part("Top", Vector3.new(0.6, 8, 8), CFrame.new(center + Vector3.new(0, 3.3, 0)) * upright, Color3.fromRGB(139, 90, 43), Enum.PartType.Cylinder)
	part("Leg", Vector3.new(3, 1.4, 1.4), CFrame.new(center + Vector3.new(0, 1.5, 0)) * upright, Color3.fromRGB(110, 70, 30), Enum.PartType.Cylinder)

	local seats = {}
	for k = 1, capacity do
		local angle = (k - 1) / capacity * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 5.5, 1.2, math.sin(angle) * 5.5)
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. k
		seat.Size = Vector3.new(2.4, 0.6, 2.4)
		seat.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) -- лицом к столу
		seat.Anchored = true
		seat.Color = Color3.fromRGB(180, 60, 60)
		seat.Parent = model
		seats[k] = seat
	end

	-- Табличка над столом
	local signPart = part("Sign", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 9, 0)), Color3.new(1, 1, 1))
	signPart.Transparency = 1
	signPart.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 3)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 200, 60)
	label.Font = Enum.Font.Arimo
	label.TextScaled = true
	label.Parent = gui

	local tbl = {
		index = index,
		capacity = capacity,
		seats = seats,
		seatPlayer = {}, -- [Seat] = Player
		state = "idle", -- idle | countdown | playing
		token = 0,
		game = nil,
		lastWord = nil,
		label = label,
	}
	self.tables[index] = tbl
	self:_updateSign(tbl)

	for _, seat in seats do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_onSeat(tbl, seat)
		end)
	end
end

-- ===== места и состав =====

function TableService:_seated(tbl)
	local out = {}
	for _, seat in tbl.seats do
		local p = tbl.seatPlayer[seat]
		if p then
			out[#out + 1] = p
		end
	end
	return out
end

function TableService:_notify(tbl, payload)
	for _, p in self:_seated(tbl) do
		self.remote:FireClient(p, payload)
	end
end

function TableService:_updateSign(tbl, countdown, word)
	if word ~= nil then
		tbl.lastWord = word
	end
	local text = ("%d/%d"):format(#self:_seated(tbl), tbl.capacity)
	if tbl.state == "playing" then
		text ..= "\n" .. (tbl.lastWord or "")
	elseif countdown then
		text ..= "\n" .. tostring(countdown)
	end
	tbl.label.Text = text
end

function TableService:_onSeat(tbl, seat)
	local old = tbl.seatPlayer[seat]
	local new = playerFromSeat(seat)
	if old == new then
		return
	end

	-- Тот, кто сейчас в тренировочной партии, за стол сесть не может
	if new and self.gameOf[new] and self.gameOf[new] ~= tbl.game then
		local hum = seat.Occupant
		if hum then
			hum.Sit = false
		end
		return
	end

	tbl.seatPlayer[seat] = new
	if old then
		self.seatedAt[old] = nil
		if tbl.game then
			tbl.game:removePlayer(old)
		end
		self.remote:FireClient(old, { type = "lobbyLeft" })
	end
	if new then
		self.seatedAt[new] = tbl
	end
	self:_refresh(tbl)
end

function TableService:_refresh(tbl)
	if tbl.state == "playing" then
		self:_updateSign(tbl)
		return
	end

	local n = #self:_seated(tbl)
	tbl.token += 1
	local token = tbl.token

	if n < 2 then
		tbl.state = "idle"
		self:_notify(tbl, { type = "lobby", seated = n, capacity = tbl.capacity })
		self:_updateSign(tbl)
		return
	end

	tbl.state = "countdown"
	local delay = (n == tbl.capacity) and Config.COUNTDOWN_FULL or Config.COUNTDOWN_PARTIAL
	task.spawn(function()
		for t = delay, 1, -1 do
			if tbl.token ~= token then
				return
			end
			self:_notify(tbl, { type = "lobby", seated = n, capacity = tbl.capacity, countdown = t })
			self:_updateSign(tbl, t)
			task.wait(1)
		end
		if tbl.token ~= token then
			return
		end
		self:_startGame(tbl)
	end)
end

-- ===== партия =====

function TableService:_startGame(tbl)
	local players = self:_seated(tbl)
	if #players < 2 then
		self:_refresh(tbl)
		return
	end

	local seats = {}
	for _, p in players do
		seats[#seats + 1] = { player = p, name = p.DisplayName, lives = Config.LIVES, alive = true }
	end

	local game = TableGame.new(self.dict, seats, self.remote)
	tbl.state = "playing"
	tbl.game = game
	for _, p in players do
		self.gameOf[p] = game
	end
	for _, seat in tbl.seats do
		if not tbl.seatPlayer[seat] then
			seat.Disabled = true -- пока идёт партия, подсесть нельзя
		end
	end

	game.onWord = function(word)
		self:_updateSign(tbl, nil, word)
	end
	game.onEnd = function(g)
		for _, p in players do
			if self.gameOf[p] == g then
				self.gameOf[p] = nil
			end
		end
		tbl.game = nil
		tbl.state = "idle"
		tbl.lastWord = nil
		for _, seat in tbl.seats do
			seat.Disabled = false
		end
		self:_updateSign(tbl)
		-- пауза, чтобы игроки увидели результат, затем снова отсчёт, если они остались за столом
		task.delay(Config.POST_GAME_DELAY, function()
			if tbl.state == "idle" then
				self:_refresh(tbl)
			end
		end)
	end

	self:_updateSign(tbl, nil, "")
	task.spawn(game.run, game)
end

return TableService
