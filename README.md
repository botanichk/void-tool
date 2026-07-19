```
       █
   ▄▄▄▄███▄▄▄▄
  █            █
  █  rSAkv 🦀  █
  █            █
  █▄▄▄▄▄▄▄▄▄▄▄▄▄█
  █│││││││││││││█
  █╞╡╞╡╞╡╞╡╞╡╞╡╞█
  █└┴┴┴┴┴┴┴┴┴┴┴┘█
  █      ▄▄      █
  █     ████     █
  █      ▀▀      █
  █              █
  █  ╔══════╗    █
  █  ║ VOID ║    █
  █  ╚══════╝    █
  █              █
  █  ══╗ ╔═╗ ╔══ █
  █  ══╝ ╚═╝ ╚══ █
  █              █
  █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█
```

# void-tool — rSAkv 🦀 rusty Swiss Army knife from the Void

> Swiss Army knife for Void Linux, forged by some weirdos having fun.
> Half Python, half Rust, and a questionable amount of shell scripts.

**rSAkv** — Rusty Swiss Army knife from the Void.
We earned that `r` when we wrote `krs` in Rust, so don't argue.

## Что это?

CLI-инструмент, который делает за тебя то, что ты ленишься делать руками:

- **Обновление** всего добра (Zen Browser, PortProtonQt) одной командой
- **Установка** того, что в xbps не влезло (NVIDIA, PipeWire)
- **Починка** аудиостока, когда PipeWire решил умереть (а он умеет)
- **Чистка** мусора после сборок
- **Интерактивное меню** для тех, кто забыл флаги

## Установка

```bash
git clone https://github.com/botanichk/void-tool.git
cd void-tool

# установка в систему
cp void-tool ~/.local/bin/
cp scripts/* ~/scripts/
chmod +x ~/.local/bin/void-tool ~/scripts/*.sh

# если хочешь Rust-компонент (krs — health check)
cd krs && cargo build --release && cp target/release/krs ~/.local/bin/ && cd ..
```

Или проще:

```bash
# одной строкой для смелых
./void-tool self-install  # TODO: придумать, как это красиво сделать
```

## Использование

```bash
void-tool install nvidia          # sudo — установка NVIDIA
void-tool install pipewire        # sudo — установка PipeWire на голый Void
void-tool update                  # проверка и обновление всего
void-tool update check            # только проверить
void-tool update status           # таблица версий
void-tool fix health              # 🦀 Rust health check
void-tool clean builds            # xbps-src clean
void-tool clean cache             # pip, thumbnails, mpv, wireplumber
void-tool menu                    # интерактив (fzf или нумерация)
void-tool trigger                 # для автозапуска из Hyprland
```

## Модули

| Модуль | Статус | Описание |
|--------|--------|----------|
| `zen` | ✅ | Обновление Zen Browser (native xbps) |
| `ppqt` | ✅ | Обновление PortProtonQt (Native XBPS) |
| `nvidia` | ✅ | Установка NVIDIA + PRIME (vchwd legacy) |
| `pipewire` | ✅ | Установка PipeWire на Void с нуля |

## Архитектура

```
void-tool ─── Python ─── CLI/оркестратор
  ├── krs ─── Rust ───── health check (Pgrep есть, hang'ов нет)
  ├── *.sh ── Bash ───── модули обновления/установки
  └── fzf ─── TUI ────── интерактивное меню
```

## Лицензия

MIT — делай что хочешь, но не забудь посмеяться.

---

<sub>Created with ❤️ and occasional despair on Void Linux.</sub>
