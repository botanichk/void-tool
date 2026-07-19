<div align="center">
  <img src="logo.svg" width="160" alt="rSAkv">
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
| `void-tool update` | Обновляет Zen, PortProtonQt и всё остальное |
| `void-tool update check` | Проверить, что нового вышло |
| `void-tool update status` | Таблица версий всех модулей |
| `void-tool fix health` | 🦀 Починить аудиостек (Rust, не виснет) |
| `void-tool clean builds` | xbps-src clean после сборок |
| `void-tool clean cache` | pip, thumbnails, mpv, wireplumber |
| `void-tool menu` | Интерактивное меню (fzf / нумерация) |
| `void-tool trigger` | Для автозапуска из Hyprland |

## Установка

```bash
git clone https://github.com/botanichk/void-tool.git
cd void-tool
./void-tool self-install
exec $SHELL
void-tool --version
```

Всё. `self-install` сам:
- скопирует `void-tool` в `~/.local/bin`
- разложит скрипты по `~/scripts/`
- соберёт `krs` из Rust-исходников
- создаст конфиг, если нет
- установит автодополнение для Zsh/Bash

## Модули

| Модуль | Статус | Описание |
|--------|--------|----------|
| `zen` | ✅ | Обновление Zen Browser (native xbps) |
| `ppqt` | ✅ | Обновление PortProtonQt (Native XBPS) |
| `nvidia` | ✅ | Установка NVIDIA + PRIME |
| `pipewire` | ✅ | Установка PipeWire с нуля |

## Архитектура

```
void-tool ─── Python ─── CLI/оркестратор
  ├── krs ─── Rust ───── health check (не виснет)
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
Кодер: немного человек, немного нейросеть, результат один — работает.</sub>
