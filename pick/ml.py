import shutil
from importlib.resources import files
from pathlib import Path

DEFAULT_CONFIG_DIR = Path.home() / ".config/pick"


def install_qml(dest: Path, force: bool = False):
    src = files("pick") / "qml"

    if dest.exists() and not force:
        print(f"{dest} already exists. Use --force to overwrite.")
        return

    shutil.copytree(src, dest, dirs_exist_ok=True)
    print(f"Installed QML config to {dest}")


def uninstall_qml(dest: Path, confirm: bool = True) -> bool:
    if not dest.exists():
        print(f"Nothing to uninstall — {dest} does not exist.")
        return False

    if confirm:
        answer = input(f"Remove {dest}? [y/N] ").strip().lower()
        if answer != "y":
            print("Uninstall cancelled.")
            return False

    if dest.is_symlink():
        dest.unlink()
    else:
        shutil.rmtree(dest)

    print(f"Removed {dest}")
    return True
