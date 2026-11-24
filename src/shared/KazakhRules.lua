-- Правила казахского языка: нормализация слов и выбор следующей буквы.
-- Важно: string.lower в Luau не умеет в кириллицу, поэтому свой маппинг через кодпоинты.

local Config = require(script.Parent.Config)

local KazakhRules = {}

-- 42 буквы казахского алфавита (кириллица)
local ALPHABET = {}
for _, cp in utf8.codes("аәбвгғдеёжзийкқлмнңоөпрстуұүфхһцчшщъыіьэюя") do
	ALPHABET[cp] = true
end

-- Заглавные -> строчные
local UPPER_TO_LOWER = {}
for cp = 0x0410, 0x042F do -- А-Я
	UPPER_TO_LOWER[cp] = cp + 32
end
UPPER_TO_LOWER[0x0401] = 0x0451 -- Ё -> ё
for _, cp in { 0x04D8, 0x0492, 0x049A, 0x04A2, 0x04E8, 0x04B0, 0x04AE, 0x04BA } do
	UPPER_TO_LOWER[cp] = cp + 1 -- Ә Ғ Қ Ң Ө Ұ Ү Һ
end
UPPER_TO_LOWER[0x0406] = 0x0456 -- І -> і

-- Латинские буквы, неотличимые от кириллических -> кириллица
local LATIN_LOOKALIKE = {
	[0x61] = 0x0430, -- a
	[0x63] = 0x0441, -- c
	[0x65] = 0x0435, -- e
	[0x69] = 0x0456, -- i -> казахская і
	[0x6B] = 0x043A, -- k
	[0x6D] = 0x043C, -- m
	[0x6F] = 0x043E, -- o
	[0x70] = 0x0440, -- p
	[0x74] = 0x0442, -- t
	[0x78] = 0x0445, -- x
	[0x79] = 0x0443, -- y
}

-- Возвращает слово в канонической форме или nil, если оно не годится
-- (чужие символы, пробелы/дефисы/цифры, слишком короткое).
function KazakhRules.normalize(raw)
	if type(raw) ~= "string" or #raw == 0 or #raw > Config.MAX_RAW_BYTES then
		return nil
	end
	if not utf8.len(raw) then
		return nil
	end
	local trimmed = raw:match("^%s*(.-)%s*$")
	local out, n = {}, 0
	for _, cp in utf8.codes(trimmed) do
		if cp >= 0x41 and cp <= 0x5A then
			cp += 32 -- ASCII A-Z -> a-z
		end
		cp = LATIN_LOOKALIKE[cp] or cp
		cp = UPPER_TO_LOWER[cp] or cp
		if not ALPHABET[cp] then
			return nil
		end
		n += 1
		out[n] = utf8.char(cp)
	end
	if n < Config.MIN_WORD_LEN then
		return nil
	end
	return table.concat(out)
end

function KazakhRules.chars(word)
	local out = {}
	for _, cp in utf8.codes(word) do
		out[#out + 1] = utf8.char(cp)
	end
	return out
end

function KazakhRules.firstLetter(word)
	return word:sub(1, utf8.offset(word, 2) - 1)
end

-- Следующая буква: идём с конца слова назад, пока не найдём «играбельную».
-- isPlayable(letter) -> bool решает вызывающий (учитывает словарь и уже использованные слова).
-- таң -> ң мёртвая -> «а»;  тың -> ң, ы мёртвые -> «т».
function KazakhRules.nextLetter(word, isPlayable)
	local c = KazakhRules.chars(word)
	for i = #c, 1, -1 do
		if isPlayable(c[i]) then
			return c[i]
		end
	end
	return nil
end

return KazakhRules
