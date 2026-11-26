extends AnimationPlayer

const BOUNDARIES = [0.0,0.12,0.32,0.52,0.75,0.91]
const TRANSFER = {
	"sword":[Vector2.ZERO,Vector2(-1,0),Vector2(-2,-1),Vector2(3,0),Vector2(2,1),Vector2(0,1)],
	"axe":[Vector2.ZERO,Vector2(-1,0),Vector2(-2,2),Vector2(2,1),Vector2(4,2),Vector2(-1,1)],
	"bow":[Vector2.ZERO,Vector2(-1,0),Vector2(-2,0),Vector2(1,0),Vector2(-1,0),Vector2.ZERO],
	"spear":[Vector2.ZERO,Vector2(-1,0),Vector2(-2,0),Vector2(4,0),Vector2(2,0),Vector2.ZERO],
}

static func frame_at(ticks: Array, tick: int) -> int:
	for frame in range(5,0,-1):
		if tick>=ticks[frame]: return frame
	return 0

static func clip(duration: int, ticks: Array, weapon: String) -> Animation:
	var track = Animation.new()
	track.length = float(duration)/60.0
	var index = track.add_track(Animation.TYPE_VALUE)
	track.track_set_path(index,NodePath(".:painted_pose"))
	track.value_track_set_update_mode(index,Animation.UPDATE_DISCRETE)
	for frame in ticks.size():
		track.track_insert_key(index,float(ticks[frame])/60.0,frame)
	if TRANSFER.has(weapon):
		var offset = track.add_track(Animation.TYPE_VALUE)
		track.track_set_path(offset,NodePath(".:visual_transfer"))
		track.track_set_interpolation_type(offset,Animation.INTERPOLATION_CUBIC)
		for frame in ticks.size():
			track.track_insert_key(offset,float(ticks[frame])/60.0,TRANSFER[weapon][frame])
		track.track_insert_key(offset,track.length,Vector2.ZERO)
	return track

var painted_pose = 0
var visual_transfer := Vector2.ZERO
