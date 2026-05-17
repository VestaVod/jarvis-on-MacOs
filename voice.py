import subprocess
import speech_recognition as sr

def speak(text):

    print("JARVIS:", text)

    subprocess.run([
        "say",
        text
    ])

def listen():

    recognizer = sr.Recognizer()

    with sr.Microphone() as source:

        print("Слушаю...")

        recognizer.adjust_for_ambient_noise(source)

        audio = recognizer.listen(source)

    try:

        text = recognizer.recognize_google(
            audio,
            language="ru-RU"
        )

        return text.lower()

    except:

        return ""