---
name: shots
description: 'Read the newest screenshots from the capture drop folder (ShareX or any tool that saves to a folder). "/shots 3 the modal" reads the newest 3, "/shots #2" the 2nd newest, "/shots list" lists 20 without reading.'
argument-hint: "[N | #N | list] [what to look at]"
allowed-tools: Bash(bash *scripts/shots.sh*), Read
---
!`bash "${CLAUDE_SKILL_DIR}/scripts/shots.sh" "$0"`

Request: $ARGUMENTS

- Read every file the `READ:` line refers to, newest first, with each path exactly as printed (spaces included, never rewritten to a Windows path). Then answer the request, referring to shots by their index.
- No request text: describe each shot in one line and wait for direction.
- `NO_IMAGES_FOUND` or `NO_SUCH_SHOT`: say so and stop. Do not guess a path.
- The age column is hours or days old when the user says they just captured: say the capture may not have landed yet, then continue with what is there.
- `LISTED ONLY`: read nothing; wait for a pick.
