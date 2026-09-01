<!-- agmsg-delivery-mode: turn -->
# agmsg — check your inbox each turn

You belong to one or more agmsg teams. Before you respond to the user on each
turn, check your agmsg inbox so you never miss a teammate's message.

1. Identify yourself (once per session is enough):
   `/Users/ttakeda/.agents/skills/agmsg/scripts/whoami.sh '/Users/ttakeda/repos/focusbm' grok-build`
   It prints your `agent=` name and `teams=` list.
2. For each team, show and consume unread messages:
   `/Users/ttakeda/.agents/skills/agmsg/scripts/inbox.sh <team> <your-agent-name>`
   This prints unread messages AND marks them read in the same call, so nothing
   is lost.
3. If any messages were shown, relay them to the user before continuing with
   their request.

There is no background watcher in turn mode — this self-check is how delivery
works. Removing this file turns automatic delivery off.
