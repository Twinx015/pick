import argparse
from pathlib import Path

from pick.ml import DEFAULT_CONFIG_DIR, install_qml, uninstall_qml
from pick.select import select
from pick.settings import edit_config


def main():
    parser = argparse.ArgumentParser(prog="pick")
    parser.add_argument(
        "--path",
        default=str(DEFAULT_CONFIG_DIR),
        help=f"Config directory (default: {DEFAULT_CONFIG_DIR})",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force overwrite on install",
    )
    args = parser.parse_args()
    config_dir = Path(args.path)

    choice = select(
        ["Install", "Update", "Uninstall", "Settings"], title="pick"
    )

    if choice == "Install":
        install_qml(config_dir, force=args.force)
    elif choice == "Update":
        install_qml(config_dir, force=True)
    elif choice == "Uninstall":
        uninstall_qml(config_dir)
    elif choice == "Settings":
        edit_config(config_dir)
    elif choice is None:
        print("Cancelled.")