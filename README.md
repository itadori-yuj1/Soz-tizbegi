# Сөз Тізбегі: серверный каркас (MVP)

Структура под Rojo (`rojo serve` -> Connect в Studio):

- `src/shared/Config.lua`: жизни, таймеры, пороги
- `src/shared/KazakhRules.lua`: нормализация слов, правило следующей буквы
- `src/server/Dictionary.lua`: загрузка и индекс словаря
- `src/server/BotAI.lua`: уровни бота (задержка + шанс не успеть)
- `src/server/TableGame.lua`: партия: ходы, таймер, жизни, победа
- `src/server/Main.server.lua`: Remotes, режим тренировки
- `src/data/Words.lua`: словарь (893 слова, из вашего файла)
- `src/client/Keyboard.lua`: экранная казахская клавиатура
- `src/client/DebugClient.client.lua`: отладочный клиент (лог + клавиатура)

## Протокол (RemoteEvent'ы в ReplicatedStorage.SozRemotes)

- клиент -> сервер: `SubmitWord(text)`, `JoinPractice(level, botCount)`
- сервер -> клиент: `TableState(payload)`, где `payload.type`:
  `start`, `turn` (who, letter, deadline, turnTime, round, seats), `word` (by, word, nextLetter),
  `reject` (reason: format | letter | unknown | used), `timeout`, `eliminated`, `end`.

`deadline` приходит в `workspace:GetServerTimeNow()`. Клиент считает остаток сам, не получая тики с сервера.

## Решения, которые стоит держать в голове

- Неверное слово не сбрасывает таймер и не отнимает жизнь. Жизнь отнимает только истёкший таймер.
- После таймаута буква остаётся прежней для следующего игрока.
- Правило «мёртвых» букв общее: идём с конца слова назад, пока буква не станет играбельной.
  Играбельна = слов на неё >= `MIN_START_COUNT` и остались неиспользованные.
- Слова на экране берутся только из твоего словаря, поэтому чистка словаря от мата это и есть модерация.
- Код не запускался в Studio. Первый прогон на ноутбуке: подставить в `JoinPractice` разные уровни,
  проверить таймаут, `ң` на конце (таң, аң, тың) и выход игрока посреди хода.

## Дальше

1. Настоящий словарь (в идеале разбить файлы по первой букве) и `MIN_START_COUNT` ~ 30.
2. Реальные столы со стульями (Seat + ProximityPrompt) вместо кнопки тренировки.
3. UI: встроенная казахская клавиатура, таймер, жизни, лента слов.
4. Рейтинг и DataStore (только после стабильного ядра).
