-- ОТЛАДОЧНЫЙ клиент: лог событий и поле ввода. Заменишь настоящим UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("SozRemotes")
local tableState = remotes:WaitForChild("TableState")
local submitWord = remotes:WaitForChild("SubmitWord")
local joinPractice = remotes:WaitForChild("JoinPractice")

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.8, 0.5)
label.Position = UDim2.fromScale(0.1, 0.05)
label.BackgroundTransparency = 0.4
label.TextSize = 20
label.TextWrapped = true
label.TextYAlignment = Enum.TextYAlignment.Top
label.Parent = gui

local box = Instance.new("TextBox")
box.Size = UDim2.fromScale(0.8, 0.08)
box.Position = UDim2.fromScale(0.1, 0.6)
box.PlaceholderText = "Сөз..."
box.TextSize = 24
box.ClearTextOnFocus = false
box.Parent = gui

local lines = {}
local function log(text)
	table.insert(lines, text)
	if #lines > 12 then
		table.remove(lines, 1)
	end
	label.Text = table.concat(lines, "\n")
end

box.FocusLost:Connect(function(enterPressed)
	if enterPressed and box.Text ~= "" then
		submitWord:FireServer(box.Text)
		box.Text = ""
	end
end)

tableState.OnClientEvent:Connect(function(p)
	if p.type == "start" then
		log("Старт: " .. p.startWord)
	elseif p.type == "turn" then
		log(("Ход: %s | буква: %s | круг %d | %d с"):format(p.who, p.letter, p.round, p.turnTime))
	elseif p.type == "word" then
		log(p.by .. ": " .. p.word)
	elseif p.type == "reject" then
		log("✗ " .. p.reason)
	elseif p.type == "timeout" then
		log(("⏱ %s теряет жизнь, осталось %d"):format(p.who, p.lives))
	elseif p.type == "eliminated" then
		log("Выбыл: " .. p.who)
	elseif p.type == "end" then
		log("Конец. Победитель: " .. tostring(p.winner))
	end
end)

task.wait(1)
joinPractice:FireServer("easy", 1)
