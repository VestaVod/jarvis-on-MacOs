import customtkinter as ctk
import threading
from executor import execute_ai_action
from ai import ask_ai
from voice import listen, speak
from commands import execute_command

ctk.set_appearance_mode("dark")

app = ctk.CTk()

app.geometry("800x600")

app.title("JARVIS")

chat = ctk.CTkTextbox(
    app,
    width=760,
    height=450,
    font=("Helvetica", 16)
)

chat.pack(pady=20)

entry = ctk.CTkEntry(
    app,
    width=500,
    height=45,
    font=("Helvetica", 16)
)

entry.pack(side="left", padx=15, pady=15)

def add_message(sender, text):

    chat.insert(
        "end",
        f"{sender}: {text}\n\n"
    )

    chat.see("end")

def process_message(text):

    add_message("Ты", text)

    result = execute_command(text)

    if result:

        add_message("JARVIS", result)

        speak(result)

        return

    try:

        response = ask_ai(text)

        if response.startswith("ACTION:"):

            result = execute_ai_action(response)

            if result:
                add_message("JARVIS", result)

                speak(result)

                return

        add_message("JARVIS", response)

        speak(response)

    except Exception as e:

        add_message(
            "Ошибка",
            str(e)
        )

def send_text():

    text = entry.get()

    entry.delete(0, "end")

    if text.strip() == "":
        return

    threading.Thread(
        target=process_message,
        args=(text,)
    ).start()

def voice_input():

    text = listen()

    if text != "":

        threading.Thread(
            target=process_message,
            args=(text,)
        ).start()

send_button = ctk.CTkButton(
    app,
    text="Отправить",
    width=120,
    command=send_text
)

send_button.pack(side="left", padx=10)

voice_button = ctk.CTkButton(
    app,
    text="🎤",
    width=60,
    command=voice_input
)

voice_button.pack(side="left")

app.mainloop()