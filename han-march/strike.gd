extends AnimationPlayer

const BOUNDARIES = [0.0,0.12,0.32,0.52,0.75,0.91]

static func phase_tick(duration: int, frame: int) -> int:
	return ceili(float(duration)*BOUNDARIES[frame])

static func frame_at(duration: int, tick: int) -> int:
	for frame in range(5,0,-1):
		if tick>=phase_tick(duration,frame): return frame
	return 0

static func clip(duration: int) -> Animation:
	var track = Animation.new()
	track.length = float(duration)/60.0
	var index = track.add_track(Animation.TYPE_VALUE)
	track.track_set_path(index,NodePath(".:painted_pose"))
	track.value_track_set_update_mode(index,Animation.UPDATE_DISCRETE)
	for frame in BOUNDARIES.size():
		track.track_insert_key(index,float(phase_tick(duration,frame))/60.0,frame)
	return track

var painted_pose = 0
