-- Клиент: меню -> партия с ботом -> экран результата.
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

local lastLevel = "easy"
local showMenu

local function startPractice(level)
	lastLevel = level
	hud:hideOverlay()
	keyboard:clear()
	keyboard:setEnabled(false)
	keyboard.frame.Visible = true
	joinPractice:FireServer(level, 1)
end

function showMenu()
	keyboard.frame.Visible = false
	hud:hideHUD()
	hud:showMenu(startPractice)
end

keyboard.Submitted:Connect(function(text)
	submitWord:FireServer(text)
end)

tableState.OnClientEvent:Connect(function(p)
	if p.type == "start" then
		hud:onStart(p.startWord, p.seats)
	elseif p.type == "turn" then
		hud:onTurn(p)
		keyboard:setEnabled(p.who == player.DisplayName)
	elseif p.type == "word" then
		hud:onWord(p.by, p.word)
	elseif p.type == "reject" then
		hud:toast(REJECT_TEXT[p.reason] or "Қате")
	elseif p.type == "timeout" then
		hud:onTimeout(p.who, p.lives)
	elseif p.type == "eliminated" then
		hud:onEliminated(p.who)
	elseif p.type == "end" then
		keyboard:setEnabled(false)
		keyboard.frame.Visible = false
		local won = p.winner == player.DisplayName
		hud:showEnd(won, p.winner, function()
			startPractice(lastLevel)
		end, showMenu)
	end
end)

showMenu()
