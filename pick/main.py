from pick.ml import install_qml, uninstall_qml
from pick.select import select


def main():
    choice = select(["Install", "Update", "Uninstall"], title="pick")

    if choice == "Install":
        install_qml()
    elif choice == "Update":
        install_qml(force=True)
    elif choice == "Uninstall":
        uninstall_qml()
    elif choice is None:
        print("Cancelled.")
