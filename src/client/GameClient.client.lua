-- Клиент: лобби (столы) -> партия -> результат. Плюс «Жаттығу» (партия с ботом).
-- Связывает RemoteEvent'ы, HUD и клавиатуру.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keyboard = require(script.Parent.Keyboard)
local GameHUD = require(script.Parent.GameHUD)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SozRemotes")
local tableState = remotes:WaitForChild("TableState")
local submitWord = remotes:WaitForChild("SubmitWord")
local joinPractice = remotes:WaitForChild("JoinPractice")

local gui = Instance.new("ScreenGui")
gui.Name = "SozTizbegi"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local hud = GameHUD.new(gui)
local keyboard = Keyboard.new(gui)
keyboard.frame.Visible = false

local REJECT_TEXT = {
	format = "Тек қазақ әріптері",
	letter = "Басқа әріп керек",
	unknown = "Сөздікте жоқ",
	used = "Бұл сөз болды",
}

-- mode: nil (лобби) | "practice" | "table"
local mode = nil
local lastLevel = "easy"
local inGame = false
local practiceButton

local function refreshPracticeButton()
	practiceButton.Visible = (mode == nil) and not inGame
end

-- Кнопка «Жаттығу» (в лобби)
practiceButton = Instance.new("TextButton")
practiceButton.AnchorPoint = Vector2.new(1, 0)
practiceButton.Position = UDim2.fromScale(0.98, 0.03)
practiceButton.Size = UDim2.fromScale(0.18, 0.09)
practiceButton.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
practiceButton.TextColor3 = Color3.new(1, 1, 1)
practiceButton.Font = Enum.Font.Arimo
practiceButton.TextScaled = true
practiceButton.Text = "Жаттығу"
practiceButton.Parent = gui
Instance.new("UICorner").Parent = practiceButton

local function startPractice(level)
	lastLevel = level
	mode = "practice"
	hud:hideOverlay()
	hud:setBanner(nil)
	keyboard:clear()
	keyboard:setEnabled(false)
	refreshPracticeButton()
	joinPractice:FireServer(level, 1)
end

local function openMenu()
	hud:showMenu(startPractice, function()
		hud:hideOverlay()
	end)
end

local function backToLobby()
	mode = nil
	inGame = false
	hud:hideOverlay()
	hud:hideHUD()
	hud:setBanner(nil)
	keyboard.frame.Visible = false
	refreshPracticeButton()
end

practiceButton.Activated:Connect(openMenu)

keyboard.Submitted:Connect(function(text)
	submitWord:FireServer(text)
end)

tableState.OnClientEvent:Connect(function(p)
	if p.type == "lobby" then
		-- сидим за столом, ждём игроков / идёт отсчёт
		if not inGame then
			mode = "table"
			refreshPracticeButton()
			if p.countdown then
				hud:setBanner(("Ойын %d с кейін басталады (%d/%d)"):format(p.countdown, p.seated, p.capacity))
			else
				hud:setBanner(("Ойыншылар күтілуде: %d/%d"):format(p.seated, p.capacity))
			end
		end
	elseif p.type == "lobbyLeft" then
		if mode == "table" then
			backToLobby()
		end
	elseif p.type == "start" then
		inGame = true
		hud:hideOverlay()
		hud:setBanner(nil)
		keyboard:clear()
		keyboard:setEnabled(false)
		keyboard.frame.Visible = true
		refreshPracticeButton()
		hud:onStart(p.startWord, p.seats)
	elseif p.type == "turn" then
		hud:onTurn(p)
		keyboard:setEnabled(p.whoId == player.UserId)
	elseif p.type == "word" then
		hud:onWord(p.by, p.word)
	elseif p.type == "reject" then
		hud:toast(REJECT_TEXT[p.reason] or "Қате")
	elseif p.type == "timeout" then
		hud:onTimeout(p.who, p.lives)
	elseif p.type == "eliminated" then
		hud:onEliminated(p.who)
	elseif p.type == "end" then
		inGame = false
		keyboard:setEnabled(false)
		keyboard.frame.Visible = false
		local won = p.winner == player.DisplayName
		local buttons
		if mode == "practice" then
			buttons = {
				{ text = "Қайта ойнау", color = Color3.fromRGB(50, 110, 200), cb = function() startPractice(lastLevel) end },
				{ text = "Мәзір", color = Color3.fromRGB(70, 74, 92), cb = backToLobby },
			}
		else
			buttons = {
				{ text = "Жалғастыру", color = Color3.fromRGB(50, 110, 200), cb = function() hud:hideOverlay() hud:hideHUD() end },
			}
		end
		hud:showEnd(won, p.winner, buttons)
		refreshPracticeButton()
	end
end)

refreshPracticeButton()
