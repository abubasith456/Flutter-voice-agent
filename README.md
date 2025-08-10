# Backend notes

LiveKit token is generated on-device using `.env`:

- `LIVEKIT_URL`: e.g. `wss://agent-test-h49o6les.livekit.cloud`
- `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`: used to sign the JWT.

The Flutter client sets participant attributes:

- `userId`
- `userName`

## Python (LiveKit Agent) example

```python
# pip install livekit-agents
# Docs: https://docs.livekit.io/agents/

from livekit import agents
from livekit.agents import AutoSubscribe, JobContext

# Example agent that logs participant attributes when they join
async def entry(ctx: JobContext):
    room = await ctx.connect(auto_subscribe=AutoSubscribe.SUBSCRIBE_NONE)

    @room.on("participant_connected")
    async def on_participant_connected(participant):
        # attributes is a dict set by the Flutter app via setAttributes
        attrs = getattr(participant, "attributes", {}) or {}
        user_id = attrs.get("userId")
        user_name = attrs.get("userName")
        print(f"Participant joined: sid={participant.sid} userId={user_id} userName={user_name} attrs={attrs}")

    await room.wait_closed()

if __name__ == "__main__":
    agents.run(entry)
```

Notes:
- In your agent pipeline, you can access attributes on `participant.attributes` when the user joins or via room state at any time.
- Ensure the token used allows joining/creating the target room.