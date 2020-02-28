
datum/ai_graph_node/inline/command_filter/flock
	name = "COMMAND_FILTER_FLOCK"
	New(datum/ai_graph_node/through)
		var/datum/ai_graph_node/inline/overclock/flock_move/N = new()
		..(through,list("move"=N))

//TODO: add flock navigation
datum/ai_graph_node/moveto/flock
	name = "Navigating"

datum/ai_graph_node/inline/overclock/flock_move
	New(interval,list/moveargs=list(null))
		src.default_interval = interval ? interval : 1
		. = ..(new /datum/ai_graph_node/moveto/flock(arglist(moveargs)), src.default_interval)

datum/ai_graph_node/flock		//for generic flockdrone actions (harvesting, etc.)
	name = "FLOCK_BASE"
	var/mob/living/critter/flock/flockmob
	var/mob/living/critter/flock/drone/flockdrone

	set_host(newhost)
		. = ..()
		src.flockmob = newhost
		if( istype(newhost,/mob/living/critter/flock/drone) )
			src.flockdrone = newhost

datum/ai_graph_node/inline/visible_reachable_flocktiles
	id = "turfs"
	var/non_flocktiles = 0		//invert, look for non-flocktiles
	var/max_dist = 20
	var/reach = 0
	var/adj = /turf/proc/CardinalTurfsWithAccess
	var/heuristic = /turf/proc/Distance
	var/dist = 20

	New(datum/ai_graph_node/N,max_dist,reach,non_flocktiles = false)
		. = ..(N)
		src.non_flocktiles = non_flocktiles
		src.max_dist = max_dist ? max_dist : 20
		src.reach = reach ? reach : 0
	
	do_inline(list/data)
		. = list()
		for ( var/turf/T in view(src.host) )
			if ( src.non_flocktiles ^ isfeathertile(T) )
				var/list/L = cirrAstar(get_turf(src.host),T,src.reach,src.adj,src.heuristic,src.dist,null,null)
				if ( L )
					.[T] = length(L)


/*
/datum/aiHolder/flock
	// if there's ever specific flock values here they go

/datum/aiHolder/flock/proc/rally(atom/movable/target)
	// IMMEDIATE INTERRUPT	
	src.current_task = src.get_instance(/datum/aiTask/sequence/goalbased/rally, list(src, src.default_task))
	src.current_task.reset()
	src.target = get_turf(target)

/datum/aiTask/prioritizer/flock
	// if there's ever specific flock values here they go
*/