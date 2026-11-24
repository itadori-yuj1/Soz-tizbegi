-- Бот: берёт слова из того же словаря, но «думает» как человек:
-- случайная задержка и шанс не ответить вовсе (тогда теряет жизнь по таймеру).

local Bot = {}

Bot.LEVELS = {
	easy = { delayMin = 4.0, delayMax = 6.5, failChance = 0.30 },
	medium = { delayMin = 2.8, delayMax = 4.5, failChance = 0.12 },
	hard = { delayMin = 1.8, delayMax = 3.2, failChance = 0.03 },
}

-- Возвращает задержку ответа в секундах или nil, если бот решил «не успеть»
function Bot.plan(level, turnTime, rng)
	local cfg = Bot.LEVELS[level]
	if not cfg or rng:NextNumber() < cfg.failChance then
		return nil
	end
	local delay = rng:NextNumber(cfg.delayMin, cfg.delayMax)
	return math.min(delay, turnTime - 0.8)
end

function Bot.chooseWord(dict, letter, used, rng)
	return dict:pickRandom(letter, used, rng)
end

return Bot
