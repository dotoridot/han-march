extends RefCounted

const Campaign = preload("res://campaign.gd")

static func pilot(g: Campaign, limit: int) -> int:
	for i in limit:
		if g.phase!="battle": return i
		var player = g.team[0]
		var p: Vector2 = player.p
		var current = g.nearest(p,g.foes)
		var target: Vector2 = p
		var hold = false
		var desired: Array = []
		for point in g.targets:
			if point[0]=="exit" and g.rescued<2: continue
			if point[0]=="flag" and not g.nearest(point[1],g.foes,80).is_empty(): continue
			if desired.is_empty() or p.distance_to(point[1])<p.distance_to(desired[1]): desired=point
		if g.chapter==2:
			target = g.wagon
			if not current.is_empty() and current.p.distance_to(g.wagon)<88:
				target = current.p
		elif not desired.is_empty():
			target = desired[1]
			hold = p.distance_to(target)<23
		elif not current.is_empty():
			target = current.p
		var d = p.distance_to(target)
		var aim: Vector2 = current.p if not current.is_empty() else target+Vector2.UP
		var can_hit = not current.is_empty() and p.distance_to(aim)<59
		var move = p.direction_to(target) if not hold and d>(39 if not current.is_empty() and target==current.p else 17) else Vector2.ZERO
		var evade = false
		for e in g.alive(g.foes):
			if e.attack.is_empty() or e.attack.frame!=2: continue
			if p.distance_to(e.p)<g.max_range(e)+8 and e.p.direction_to(p).dot(e.attack.dir)>0.74:
				evade = g.dodge_cd<=0
				if evade: move = e.attack.dir.orthogonal()
				break
		g.tick(1.0/60.0,move,aim,can_hit,evade,hold,can_hit and i%18==0)
	return limit
