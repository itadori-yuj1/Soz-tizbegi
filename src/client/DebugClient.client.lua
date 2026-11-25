-- ОТЛАДОЧНЫЙ клиент: лог событий + экранная клавиатура. Заменишь настоящим UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keyboard = require(script.Parent.Keyboard)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SozRemotes")
local tableState = remotes:WaitForChild("TableState")
local submitWord = remotes:WaitForChild("SubmitWord")
local joinPractice = remotes:WaitForChild("JoinPractice")

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.96, 0.4)
label.Position = UDim2.fromScale(0.02, 0.03)
label.BackgroundTransparency = 0.4
label.Font = Enum.Font.Arimo
label.TextSize = 20
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Parent = gui

local keyboard = Keyboard.new(gui)
keyboard:setEnabled(false)
keyboard.Submitted:Connect(function(text)
	submitWord:FireServer(text)
end)

local lines = {}
local function log(text)
	table.insert(lines, text)
	if #lines > 10 then
		table.remove(lines, 1)
	end
	label.Text = table.concat(lines, "\n")
end

tableState.OnClientEvent:Connect(function(p)
	if p.type == "start" then
		log("Старт: " .. p.startWord)
	elseif p.type == "turn" then
		log(("Ход: %s | буква: %s | круг %d | %d с"):format(p.who, p.letter, p.round, p.turnTime))
		keyboard:setEnabled(p.who == player.DisplayName)
	elseif p.type == "word" then
		log(p.by .. ": " .. p.word)
	elseif p.type == "reject" then
		log("✗ " .. p.reason)
	elseif p.type == "timeout" then
		log(("⏱ %s теряет жизнь, осталось %d"):format(p.who, p.lives))
	elseif p.type == "eliminated" then
		log("Выбыл: " .. p.who)
	elseif p.type == "end" then
		keyboard:setEnabled(false)
		log("Конец. Победитель: " .. tostring(p.winner))
	end
end)

task.wait(1)
joinPractice:FireServer("easy", 1)
