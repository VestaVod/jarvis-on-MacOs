def save_memory(text):

    with open(
        "memory.txt",
        "a",
        encoding="utf-8"
    ) as file:

        file.write(text + "\n")