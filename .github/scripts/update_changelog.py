import subprocess
from datetime import datetime
import os

CHANGELOG_FILE = "CHANGELOG.md"

def get_commit_log():
    # Get the last 20 commits (excluding merges)
    log = subprocess.check_output(
        ["git", "log", "--pretty=format:%h %s", "--no-merges", "HEAD~20..HEAD"],
        text=True
    )
    return log.strip().split("\n")

def update_changelog():
    commits = get_commit_log()
    if not commits:
        return

    date_str = datetime.utcnow().strftime("%Y-%m-%d")
    new_section = [f"## {date_str}\n"] + [f"- {c}" for c in commits] + ["\n"]

    old_content = ""
    if os.path.exists(CHANGELOG_FILE):
        with open(CHANGELOG_FILE, "r", encoding="utf-8") as f:
            old_content = f.read()

    if not old_content.startswith("# Changelog"):
        old_content = "# Changelog\n\n" + old_content

    with open(CHANGELOG_FILE, "w", encoding="utf-8") as f:
        f.write(old_content + "\n".join(new_section))

if __name__ == "__main__":
    update_changelog()
