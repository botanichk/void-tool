<div align="center">
  <img src="logo.svg" width="128" alt="rSAkv">
  <h1>void-tool — rSAkv 🦀</h1>
  <p><b>R</b>usty <b>S</b>wiss <b>A</b>rmy <b>k</b>nife from the <b>V</b>oid</p>
  <p><i>Swiss Army knife for Void Linux, forged by some weirdos having fun.<br>
  Half Python, half Rust, and a questionable amount of shell scripts.</i></p>
</div>

---

## Что это?

CLI-инструмент, который делает за тебя то, что ты ленишься делать руками:

| Команда | Что делает |
|---------|-----------|
| `void-tool install nvidia` | Ставит NVIDIA на ноут/десктоп, PRIME, prime-run |
| `void-tool install pipewire` | Разворачивает PipeWire на голом Void |
| `void-tool install zen` | Собрать и установить Zen Browser |
| `void-tool install ppqt` | Собрать и установить PortProtonQt |
| `void-tool update` | Обновить всё (Zen, PPQt, ...) |
| `void-tool update zen` | Обновить только Zen Browser |
| `void-tool update ppqt` | Обновить только PortProtonQt |
| `void-tool update check` | Проверить, что нового вышло |
| `void-tool update status` | Таблица версий всех модулей |
| `void-tool fix health` | 🦀 Починить аудиостек (Rust — не виснет) |
| `void-tool clean builds` | xbps-src clean после сборок |
| `void-tool clean cache` | pip, thumbnails, mpv, wireplumber |
| `void-tool menu` | Интерактивное меню (fzf / нумерация) |
| `void-tool trigger` | Для автозапуска из Hyprland |

## Как установить

### Способ 1 — для новичков (проще всего)

1. Открой браузер, перейди на страницу:
   **https://github.com/botanichk/void-tool**
2. Нажми зелёную кнопку **`<> Code`**
3. В меню выбери **`Download ZIP`**
4. Распакуй архив в любую папку (например, `~/void-tool/`)
5. Открой терминал в этой папке и выполни:

```bash
./void-tool self-install
exec $SHELL
void-tool --version
```

Готово. Дальше просто открываешь терминал и пишешь:

```bash
void-tool menu          # меню со стрелками
void-tool --version     # проверить, что стоит
void-tool update check  # есть ли обновления
```

Всё. Никаких `./`, никаких путей — просто `void-tool`.

### Способ 2 — для тех, кто дружит с git

```bash
git clone https://github.com/botanichk/void-tool.git
cd void-tool
./void-tool self-install
exec $SHELL
```

### Что делает self-install?

- копирует `void-tool` в `~/.local/bin`
- раскладывает скрипты по `~/scripts/`
- собирает `krs` из Rust-исходников (компонент для проверки здоровья аудио)
- создаёт конфиг `~/.config/void-update/config.toml`, если его нет
- устанавливает автодополнение для Zsh/Bash

## Модули

| Модуль | `void-tool install` | `void-tool update` | Описание |
|--------|---------------------|--------------------|----------|
| `zen` | ✅ устанавливает | ✅ обновляет | Zen Browser (native xbps) |
| `ppqt` | ✅ устанавливает | ✅ обновляет | PortProtonQt (Native XBPS) |
| `nvidia` | ✅ устанавливает | — | NVIDIA + PRIME + prime-run |
| `pipewire` | ✅ устанавливает | — | PipeWire на голый Void |

## Архитектура

```
void-tool ─── Python ─── CLI/оркестратор
  ├── krs ─── Rust ───── health check (не виснет на pactl info)
  ├── *.sh ── Bash ───── модули обновления/установки
  └── fzf ─── TUI ────── интерактивное меню
```

## Требования

- **Void Linux** (xbps, runit)
- **Python ≥ 3.11** (tomllib)
- **Rust** (опционально — только для `krs`)
- **fzf** (опционально — для меню со стрелками)

## Лицензия

MIT — делай что хочешь, но не забудь посмеяться.

---

<sub>Создано с ❤️ и периодическим отчаянием на Void Linux.<br>
Автор идеи и тестировщик: <a href="https://github.com/botanichk">botanichk</a><br>
Кодер: немного человек, немного нейросеть, результат один — работает.<br>
<br>
А вместе они — <b>Марсианское братство</b> 🐱<br>
Марсик — пыжик, главный тестировщик дивана и хранитель уюта.</sub>
