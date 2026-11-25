-- Экранная казахская клавиатура. Не использует системную: никаких автозамен и проблем с раскладкой.
-- Использование:
--   local kb = Keyboard.new(screenGui)
--   kb.Submitted:Connect(function(text) ... end)
--   kb:setEnabled(false) -- когда не твой ход

local Keyboard = {}
Keyboard.__index = Keyboard

-- Верхний ряд: специфические казахские буквы
local ROWS = {
	{ "ә", "і", "ң", "ғ", "ү", "ұ", "қ", "ө", "һ" },
	{ "й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ" },
	{ "ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э" },
	{ "я", "ч", "с", "м", "и", "т", "ь", "б", "ю" },
}
local KAZAKH_ONLY = { ["ә"] = true, ["і"] = true, ["ң"] = true, ["ғ"] = true, ["ү"] = true, ["ұ"] = true, ["қ"] = true, ["ө"] = true, ["һ"] = true }

local MAX_LEN = 24
-- Arimo имеет широкое покрытие Unicode. ПРОВЕРЬ на устройстве, что ә ғ қ ң ө ұ ү һ і отображаются.
local FONT = Enum.Font.Arimo

local COLOR_KEY = Color3.fromRGB(70, 74, 92)
local COLOR_KAZAKH = Color3.fromRGB(46, 120, 96)
local COLOR_ACTION = Color3.fromRGB(190, 70, 70)
local COLOR_SEND = Color3.fromRGB(50, 110, 200)

function Keyboard.new(parent)
	local self = setmetatable({ _text = "", _enabled = true, _buttons = {} }, Keyboard)

	local changed = Instance.new("BindableEvent")
	local submitted = Instance.new("BindableEvent")
	self._changedEvent, self._submittedEvent = changed, submitted
	self.Changed = changed.Event
	self.Submitted = submitted.Event

	local frame = Instance.new("Frame")
	frame.Name = "KazakhKeyboard"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 0.995)
	frame.Size = UDim2.fromScale(0.98, 0.46)
	frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	self.frame = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = frame

	-- Поле с набираемым словом
	local display = Instance.new("TextLabel")
	display.Size = UDim2.new(0.96, 0, 0.13, 0)
	display.LayoutOrder = 0
	display.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	display.TextColor3 = Color3.fromRGB(20, 20, 28)
	display.Font = FONT
	display.TextScaled = true
	display.Text = ""
	display.Parent = frame
	self._display = display

	local function makeRow(order, widthScale)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(widthScale or 0.98, 0, 0.165, 0)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = frame
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.Padding = UDim.new(0.005, 0)
		l.Parent = row
		return row
	end

	local function makeButton(row, text, width, color, onClick)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(width, 0, 1, 0)
		b.BackgroundColor3 = color
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = FONT
		b.TextScaled = true
		b.Text = text
		b.AutoButtonColor = true
		b.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.15, 0)
		corner.Parent = b
		b.Activated:Connect(function()
			if self._enabled then
				onClick()
			end
		end)
		table.insert(self._buttons, b)
		return b
	end

	-- Буквы
	for i, letters in ROWS do
		local row = makeRow(i)
		for _, letter in letters do
			makeButton(row, letter, 1 / 12 - 0.006, KAZAKH_ONLY[letter] and COLOR_KAZAKH or COLOR_KEY, function()
				self:_append(letter)
			end)
		end
	end

	-- Нижний ряд: стереть / отправить
	local actions = makeRow(#ROWS + 1)
	makeButton(actions, "Өшіру", 0.32, COLOR_ACTION, function()
		self:_backspace()
	end)
	makeButton(actions, "Жіберу", 0.64, COLOR_SEND, function()
		self:_submit()
	end)

	return self
end

function Keyboard:_refresh()
	self._display.Text = self._text
	self._changedEvent:Fire(self._text)
end

function Keyboard:_append(letter)
	if utf8.len(self._text) >= MAX_LEN then
		return
	end
	self._text ..= letter
	self:_refresh()
end

function Keyboard:_backspace()
	local pos = utf8.offset(self._text, -1)
	if pos then
		self._text = self._text:sub(1, pos - 1)
		self:_refresh()
	end
end

function Keyboard:_submit()
	if #self._text == 0 then
		return
	end
	local text = self._text
	self._text = ""
	self:_refresh()
	self._submittedEvent:Fire(text)
end

function Keyboard:getText()
	return self._text
end

function Keyboard:clear()
	self._text = ""
	self:_refresh()
end

function Keyboard:setEnabled(enabled)
	self._enabled = enabled
	for _, b in self._buttons do
		b.TextTransparency = enabled and 0 or 0.6
	end
end

function Keyboard:destroy()
	self.frame:Destroy()
	self._changedEvent:Destroy()
	self._submittedEvent:Destroy()
end

return Keyboard
