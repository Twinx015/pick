import curses


def select(
    options: list[str],
    title: str = "Select an option",
    multiple: bool = False,
) -> str | list[str] | None:
    def _run(stdscr):
        curses.curs_set(0)
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)
        curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_GREEN)

        idx = 0
        selected: set[int] = set()

        help_text = (
            "(↑/↓ move, space to toggle, enter to confirm, q to quit)"
            if multiple
            else "(↑/↓ move, enter to select, q to quit)"
        )

        while True:
            stdscr.clear()
            stdscr.addstr(0, 0, title, curses.A_BOLD)
            stdscr.addstr(1, 0, help_text, curses.A_DIM)

            for i, option in enumerate(options):
                y = i + 3
                is_cursor = i == idx
                is_selected = i in selected

                if multiple:
                    mark = "[x]" if is_selected else "[ ]"
                    line = f"{mark} {option}"
                else:
                    line = f"> {option}" if is_cursor else f"  {option}"

                if is_cursor:
                    stdscr.addstr(y, 2, line, curses.color_pair(1))
                elif is_selected:
                    stdscr.addstr(y, 2, line, curses.color_pair(2))
                else:
                    stdscr.addstr(y, 2, line)

            stdscr.refresh()
            key = stdscr.getch()

            if key in (curses.KEY_UP, ord("k")):
                idx = (idx - 1) % len(options)
            elif key in (curses.KEY_DOWN, ord("j")):
                idx = (idx + 1) % len(options)
            elif multiple and key == ord(" "):
                if idx in selected:
                    selected.remove(idx)
                else:
                    selected.add(idx)
            elif key in (curses.KEY_ENTER, 10, 13):
                if multiple:
                    return [options[i] for i in sorted(selected)]
                return options[idx]
            elif key in (27, ord("q")):
                return None

    return curses.wrapper(_run)


if __name__ == "__main__":
    choice = select(
        ["Install", "Update", "Uninstall", "Settings"], title="pick — main menu"
    )
    print(f"You chose: {choice}")

    chosen = select(
        ["SystemTray", "Notch2", "shell"],
        title="pick — select modules",
        multiple=True,
    )
    print(f"You selected: {chosen}")
