import curses
import json
from pathlib import Path

SUPPORTED = (int, float, bool)


def edit_config(config_dir: Path) -> None:
    config_path = config_dir / "config.json"

    if not config_path.exists():
        print(f"{config_path} does not exist. Run `pick` -> Install first.")
        return

    with open(config_path) as f:
        config = json.load(f)

    unsupported = [k for k, v in config.items() if not isinstance(v, SUPPORTED)]
    if unsupported:
        print(f"Cannot edit non-numeric settings: {', '.join(unsupported)}")
        return

    def _run(stdscr):
        curses.curs_set(0)
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)

        keys = list(config)
        idx = 0
        editing = False
        buffer = ""

        while True:
            stdscr.clear()
            stdscr.addstr(0, 0, "pick — settings", curses.A_BOLD)
            stdscr.addstr(
                1, 0, "(↑/↓ move, enter to edit, s save & exit, q quit)", curses.A_DIM
            )

            for i, key in enumerate(keys):
                y = i + 3
                value = config[key]
                attr = curses.color_pair(1) if i == idx else curses.A_NORMAL
                if isinstance(value, bool):
                    mark = "[x]" if value else "[ ]"
                    stdscr.addstr(y, 2, f"{key}: {mark}", attr)
                else:
                    stdscr.addstr(y, 2, f"{key}: {value}", attr)

            if editing:
                key = keys[idx]
                value = config[key]
                if isinstance(value, bool):
                    prompt = f"Toggle {key} (current {'on' if value else 'off'})? [y/n] "
                else:
                    prompt = f"New value for {key} (current {value}): {buffer}"
                stdscr.addstr(len(keys) + 5, 2, prompt, curses.A_BOLD)
                stdscr.refresh()
                ch = stdscr.getch()

                if isinstance(value, bool):
                    if ch in (ord("y"), ord("Y"), curses.KEY_ENTER, 10, 13):
                        config[key] = not value
                        editing = False
                    elif ch in (ord("n"), ord("N"), 27):
                        editing = False
                    continue

                if ch in (curses.KEY_BACKSPACE, 127, 8):
                    buffer = buffer[:-1]
                elif ch in (curses.KEY_ENTER, 10, 13):
                    if buffer:
                        try:
                            new = float(buffer)
                            if isinstance(config[key], int):
                                new = int(new)
                            config[key] = new
                        except ValueError:
                            pass
                    buffer = ""
                    editing = False
                elif ch == 27:
                    buffer = ""
                    editing = False
                elif 32 <= ch <= 126 and chr(ch) in "-0123456789.":
                    buffer += chr(ch)
                continue

            stdscr.refresh()
            ch = stdscr.getch()

            if ch in (curses.KEY_UP, ord("k")):
                idx = (idx - 1) % len(keys)
            elif ch in (curses.KEY_DOWN, ord("j")):
                idx = (idx + 1) % len(keys)
            elif ch in (curses.KEY_ENTER, 10, 13):
                editing = True
            elif ch == ord("s"):
                return True
            elif ch in (27, ord("q")):
                return False

    if curses.wrapper(_run):
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
        print(f"Saved {config_path}")
    else:
        print("Settings unchanged.")