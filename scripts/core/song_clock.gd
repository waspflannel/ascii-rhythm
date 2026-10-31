extends Node
## Song time for gameplay. Stub for now.
##
## It will derive time from the audio playback position, never frame deltas:
## player.get_playback_position() + AudioServer.get_time_since_last_mix()
## - AudioServer.get_output_latency(), plus the user's audio offset.


## Current song time in seconds.
func get_time() -> float:
	return 0.0
