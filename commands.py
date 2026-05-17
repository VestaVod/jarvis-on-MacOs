import os
import webbrowser
import subprocess

def execute_command(command):

    command = command.lower()

    if "ютуб" in command:
        webbrowser.open("https://youtube.com")
        return "Открываю YouTube"

    elif "гугл" in command:
        webbrowser.open("https://google.com")
        return "Открываю Google"

    elif "сафари" in command:
        subprocess.run(["open", "-a", "Safari"])
        return "Открываю Safari"

    elif "яндекс музыка" in command or "музыка" in command or "музло" in command or "музыку" in command or "песенки" in command:
        subprocess.run(["open", "-a", "Яндекс Музыка"])
        return "Врубаю музло сэр"

    return None