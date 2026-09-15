import shutil
from importlib.resources import files
from pathlib import Path

QML_DEST = Path.home() / ".config/quickshell/pick"


def install_qml(force: bool = False):
    src = files("pick") / "qml"

    if QML_DEST.exists() and not force:
        print(f"{QML_DEST} already exists. Use --force to overwrite.")
        return

    shutil.copytree(src, QML_DEST, dirs_exist_ok=True)
    print(f"Installed QML config to {QML_DEST}")


def uninstall_qml(confirm: bool = True) -> bool:
    if not QML_DEST.exists():
        print(f"Nothing to uninstall — {QML_DEST} does not exist.")
        return False

    if confirm:
        answer = input(f"Remove {QML_DEST}? [y/N] ").strip().lower()
        if answer != "y":
            print("Uninstall cancelled.")
            return False

    if QML_DEST.is_symlink():
        QML_DEST.unlink()
    else:
        shutil.rmtree(QML_DEST)

    print(f"Removed {QML_DEST}")
    return True
