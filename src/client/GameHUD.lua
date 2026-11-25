-- Интерфейс партии: игроки и жизни, буква, таймер, последние слова, меню, экран результата.
-- Клавиатура рисуется отдельным модулем (Keyboard) в нижних ~46% экрана,
-- поэтому весь HUD укладывается в верхние ~52%.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HUD = {}
HUD.__index = HUD

local FONT = Enum.Font.Arimo -- проверь, что казахские буквы отображаются
local WHITE = Color3.new(1, 1, 1)

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(radius or 0.2, 0) }, parent)
end

function HUD.new(gui)
	local self = setmetatable({
		_gui = gui,
		_seats = {},
		_active = nil,
		_maxLives = 3,
		_chain = {},
		_deadline = nil,
		_turnTime = 1,
		_toastToken = 0,
	}, HUD)

	local root = make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	self.root = root

	-- Игроки (сверху)
	self._players = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.96, 0.12),
		BackgroundTransparency = 1,
	}, root)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.01, 0),
	}, self._players)

	-- Текущая буква
	self._tile = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromScale(0.14, 0.2),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		TextColor3 = Color3.fromRGB(40, 30, 10),
		Font = FONT,
		TextScaled = true,
		Text = "",
	}, root)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, self._tile)
	corner(self._tile, 0.15)

	-- Таймер
	self._barBack = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.5, 0.035),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	}, root)
	corner(self._barBack, 0.5)
	self._barFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 200, 90) }, self._barBack)
	corner(self._barFill, 0.5)
	self._barText = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		Font = FONT,
		TextScaled = true,
		Text = "",
		ZIndex = 2,
	}, self._barBack)

	-- Последние слова
	self._words = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.425),
		Size = UDim2.fromScale(0.9, 0.05),
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		Font = FONT,
		TextScaled = true,
		Text = "",
	}, root)

	-- Всплывающее сообщение
	self._toast = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.6, 0.045),
		BackgroundColor3 = Color3.fromRGB(190, 70, 70),
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		TextTransparency = 1,
		Font = FONT,
		TextScaled = true,
		Text = "",
	}, root)
	corner(self._toast, 0.3)

	-- Баннер ожидания (виден и вне партии)
	self._banner = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.7, 0.09),
		BackgroundColor3 = Color3.fromRGB(28, 28, 36),
		BackgroundTransparency = 0.2,
		TextColor3 = Color3.fromRGB(255, 200, 60),
		Font = FONT,
		TextScaled = true,
		Text = "",
		Visible = false,
	}, gui)
	corner(self._banner, 0.25)

	self._conn = RunService.RenderStepped:Connect(function()
		self:_tick()
	end)

	return self
end

-- ===== таймер =====

function HUD:_tick()
	if not self._deadline then
		return
	end
	local remaining = math.max(0, self._deadline - workspace:GetServerTimeNow())
	local ratio = math.clamp(remaining / self._turnTime, 0, 1)
	self._barFill.Size = UDim2.fromScale(ratio, 1)
	self._barFill.BackgroundColor3 = Color3.fromHSV(0.33 * ratio, 0.75, 0.9) -- зелёный -> красный
	self._barText.Text = tostring(math.ceil(remaining))
end

function HUD:_stopTimer()
	self._deadline = nil
	self._barText.Text = ""
end

-- ===== игроки и жизни =====

function HUD:setSeats(seats)
	self._seats = seats
	for _, child in self._players:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, s in seats do
		self._maxLives = math.max(self._maxLives, s.lives)
		local active = (s.name == self._active) and s.alive
		local card = make("Frame", {
			Size = UDim2.fromScale(0.22, 1),
			LayoutOrder = i,
			BackgroundColor3 = active and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(60, 64, 84),
			BackgroundTransparency = s.alive and 0 or 0.65,
		}, self._players)
		corner(card, 0.15)
		make("TextLabel", {
			Position = UDim2.fromScale(0.03, 0.04),
			Size = UDim2.fromScale(0.94, 0.5),
			BackgroundTransparency = 1,
			TextColor3 = active and Color3.fromRGB(40, 30, 10) or WHITE,
			Font = FONT,
			TextScaled = true,
			Text = s.name,
		}, card)
		local lives = make("Frame", {
			Position = UDim2.fromScale(0, 0.58),
			Size = UDim2.fromScale(1, 0.36),
			BackgroundTransparency = 1,
		}, card)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.06, 0),
		}, lives)
		for k = 1, self._maxLives do
			local dot = make("Frame", {
				Size = UDim2.fromScale(0.2, 0.8),
				LayoutOrder = k,
				BackgroundColor3 = (k <= s.lives) and Color3.fromRGB(230, 70, 80) or Color3.fromRGB(95, 95, 105),
			}, lives)
			make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, dot)
			corner(dot, 0.5)
		end
	end
end

-- ===== события партии =====

function HUD:onStart(startWord, seats)
	self._chain = { startWord }
	self._active = nil
	self._maxLives = 3
	self.root.Visible = true
	self._words.Text = startWord
	self._tile.Text = ""
	self:_stopTimer()
	self:setSeats(seats)
end

function HUD:onTurn(p)
	self._active = p.who
	self._turnTime = p.turnTime
	self._deadline = p.deadline
	self._tile.Text = p.letter
	self:setSeats(p.seats)
end

function HUD:onWord(by, word)
	self:_stopTimer()
	table.insert(self._chain, word)
	local recent = {}
	for i = math.max(1, #self._chain - 2), #self._chain do
		table.insert(recent, self._chain[i])
	end
	self._words.Text = table.concat(recent, "  >  ")
end

function HUD:onTimeout(who, lives)
	self:_stopTimer()
	for _, s in self._seats do
		if s.name == who then
			s.lives = lives
		end
	end
	self:setSeats(self._seats)
	self:toast(who .. ": уақыт бітті")
end

function HUD:onEliminated(who)
	for _, s in self._seats do
		if s.name == who then
			s.alive = false
		end
	end
	self:setSeats(self._seats)
end

function HUD:setBanner(text)
	self._banner.Visible = text ~= nil
	self._banner.Text = text or ""
end

function HUD:toast(text)
	self._toastToken += 1
	local token = self._toastToken
	self._toast.Text = text
	self._toast.TextTransparency = 0
	self._toast.BackgroundTransparency = 0.1
	task.delay(1.4, function()
		if self._toastToken ~= token then
			return
		end
		local info = TweenInfo.new(0.35)
		TweenService:Create(self._toast, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

-- ===== меню и результат =====

function HUD:showMenu(onPick, onBack)
	self:hideOverlay()
	self.root.Visible = false
	local menu = make("Frame", {
		Name = "Menu",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 26, 38),
	}, self._gui)
	self._overlay = menu
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.8, 0.18),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 200, 60),
		Font = FONT,
		TextScaled = true,
		Text = "Сөз Тізбегі",
	}, menu)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.6, 0.07),
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		Font = FONT,
		TextScaled = true,
		Text = "Жаттығу (бот)",
	}, menu)
	local levels = { { "easy", "Оңай" }, { "medium", "Орташа" }, { "hard", "Қиын" } }
	for i, lv in levels do
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.4 + (i - 1) * 0.17),
			Size = UDim2.fromScale(0.4, 0.14),
			BackgroundColor3 = Color3.fromRGB(50, 110, 200),
			TextColor3 = WHITE,
			Font = FONT,
			TextScaled = true,
			Text = lv[2],
		}, menu)
		corner(b, 0.2)
		b.Activated:Connect(function()
			onPick(lv[1])
		end)
	end
	if onBack then
		local back = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.91),
			Size = UDim2.fromScale(0.3, 0.08),
			BackgroundColor3 = Color3.fromRGB(70, 74, 92),
			TextColor3 = WHITE,
			Font = FONT,
			TextScaled = true,
			Text = "Артқа",
		}, menu)
		corner(back, 0.2)
		back.Activated:Connect(onBack)
	end
end

function HUD:showEnd(won, winnerName, buttons)
	self:hideOverlay()
	self:_stopTimer()
	local o = make("Frame", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 10,
	}, self._gui)
	self._overlay = o
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.8, 0.2),
		BackgroundTransparency = 1,
		TextColor3 = won and Color3.fromRGB(255, 200, 60) or WHITE,
		Font = FONT,
		TextScaled = true,
		Text = won and "Жеңіс!" or "Ойын бітті",
		ZIndex = 11,
	}, o)
	if not won and winnerName then
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.37),
			Size = UDim2.fromScale(0.6, 0.08),
			BackgroundTransparency = 1,
			TextColor3 = WHITE,
			Font = FONT,
			TextScaled = true,
			Text = "Жеңімпаз: " .. winnerName,
			ZIndex = 11,
		}, o)
	end
	local function button(y, text, color, cb)
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.4, 0.14),
			BackgroundColor3 = color,
			TextColor3 = WHITE,
			Font = FONT,
			TextScaled = true,
			Text = text,
			ZIndex = 11,
		}, o)
		corner(b, 0.2)
		b.Activated:Connect(cb)
	end
	for i, b in buttons do
		button(0.5 + (i - 1) * 0.19, b.text, b.color, b.cb)
	end
end

function HUD:hideOverlay()
	if self._overlay then
		self._overlay:Destroy()
		self._overlay = nil
	end
end

function HUD:hideHUD()
	self.root.Visible = false
end

return HUD
