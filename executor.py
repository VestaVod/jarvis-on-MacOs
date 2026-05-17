
import subprocess
import urllib.parse
def execute_ai_action(action):

    print("ACTION:", action)

    # =========================
    # OPEN APP
    # =========================

    if action.startswith("ACTION: OPEN_APP:"):

        app = action.replace(
            "ACTION: OPEN_APP:",
            ""
        ).strip()

        try:

            result = subprocess.run(
                ["open", "-a", app],
                capture_output=True,
                text=True
            )

            # Если приложение не найдено
            if "Unable to find application" in result.stderr:
                site = app.lower() + ".com"

                subprocess.Popen([
                    "open",
                    f"https://{site}"
                ])

                return (
                    f"{app} не найден. "
                    f"Открываю сайт."
                )

            return f"Открываю {app}"

        except Exception as e:

            return str(e)

    # =========================
    # OPEN WEBSITE
    # =========================

    elif action.startswith("ACTION: OPEN_SITE:"):

        site = action.replace(

            "ACTION: OPEN_SITE:",

            ""

        ).strip()

        if not site.startswith("http"):
            site = "https://" + site

        subprocess.Popen([

            "open",

            site

        ])

        return f"Открываю {site}"

    # =========================
    # GOOGLE SEARCH
    # =========================

    elif action.startswith("ACTION: SEARCH_GOOGLE:"):

        query = action.replace(

            "ACTION: SEARCH_GOOGLE:",

            ""

        ).strip()

        url = (

                "https://google.com/search?q="

                + urllib.parse.quote(query)

        )

        subprocess.Popen([

            "open",

            url

        ])

        return f"Ищу в Google: {query}"

    return None