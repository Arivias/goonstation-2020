//contains common aigraph structures and util functions

//wander - takes a step in a random direction every tick, with a chance to do nothing
//mob only
datum/ai_graph_node/wander
	name = "Wandering"
	weight = 1

	on_tick()
		..()
		if ( !istype(host,/mob) ) return AI_GRAPH_NODE_RESULT_ABORT
		var/mob/M = host
		if ( prob(80) )
			SPAWN_DBG(0)
				step_rand(M,0)
		return AI_GRAPH_NODE_RESULT_COMPLETED

//moveto moves to the turf data["move_target"] within ["move_prox"]=0 tiles avoiding ["move_exclude"] with access algo["move_adj"] and a max dist of ["move_dist"]
//move_
//_target : turf to move to
//OPTIONAL:
//_prox : how close to the target to get
//_exclude : list of turfs to exclude
//_adj : navigation proc
//_adj_params : params to give to _adj
//_heuristic : heuristic algo to use
//_dist : maximum traverse
//_lag : movement lag
datum/ai_graph_node/moveto
	name = "Moving"
	var/list/path
	var/cstep = 2
	var/patience = 5
	var/fails = 0

	reset()
		path = null
		cstep = 2
		patience = 5
		fails = 0
	check(list/data)
		if ( host && (istype(host,/mob) || istype(host,/obj)) && (data && "move_target" in data) )
			var/lpath = get_path(data)
			if ( lpath && length(lpath)>0 )
				return AI_GRAPH_NODE_RESULT_IN_PROGRESS
		return AI_GRAPH_NODE_RESULT_ABORT
	weight(list/data)
		return check(data) ? src.weight : -1
	
	on_begin(list/data)
		..()
		src.path = src.get_path(data)
		
	on_tick(list/data)
		..()
		message_admins("[src.host] Move target: [data["move_target"]]")
		walk(host,0)
		var/mob/living/H = host
		if ( !H.is_npc )
			return AI_GRAPH_NODE_RESULT_ABORT
		if ( src.path && cstep <= length(src.path) )
			var/turf/T = src.path[src.cstep]
			var/lag = ("move_lag" in data) ? data["move_lag"] : H.ai_movedelay
			walk_to(host,T,0,lag)
			sleep(lag)
			if (get_dist(get_turf(host),T) < 1)
				cstep++
				fails = 0
			else
				var/found_door = 0
				for (var/obj/machinery/door/D in T.contents)
					D.Bumped(host)
					found_door = 1
				if (!found_door)
					fails++
					if ( fails > patience ) return AI_GRAPH_NODE_RESULT_ABORT
					src.path = get_path(data)
					src.cstep = 2
					if ( !path || length(path) == 0 ) return AI_GRAPH_NODE_RESULT_ABORT
			return AI_GRAPH_NODE_RESULT_IN_PROGRESS
		return AI_GRAPH_NODE_RESULT_COMPLETED

		
	
	proc
		get_path(list/data)
			var/start = null
			if ( istype(host,/mob) )
				var/mob/M = host
				start = get_turf(M)
			else if ( istype(host,/obj) )
				var/obj/O = host
				start = get_turf(O)
			if ( !start ) return null
			var/end = data["move_target"]
			var/prox = ("move_prox" in data) ? data["move_prox"] : 0
			var/exclude = ("move_exclude" in data) ? data["move_exclude"] : list()
			var/adj = ("move_adj" in data) ? data["move_adj"] : /turf/proc/CardinalTurfsWithAccess
			var/dist = ("move_dist" in data) ? data["move_dist"] : 30
			var/adj_params = ("move_adj_params" in data) ? data["move_adj_params"] : null
			var/heuristic = ("move_heuristic" in data) ? data["move_heuristic"] : /turf/proc/Distance
			return cirrAstar(start,end,prox,adj,heuristic,dist,adj_params,exclude)


//wait - ["wait_time"] number of ticks to wait
datum/ai_graph_node/wait
	name = "Waiting"
	var/ticks_remaining

	reset()
		ticks_remaining = 0
	on_begin(list/data)
		..()
		if ( "wait_time" in data )
			ticks_remaining = data["wait_time"]
	on_tick()
		..()
		if ( !ticks_remaining ) return AI_GRAPH_NODE_RESULT_COMPLETED
		ticks_remaining -= 1
		return AI_GRAPH_NODE_RESULT_IN_PROGRESS