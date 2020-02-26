
datum/ai_graph_node/inline/command_filter/flock
	name = "COMMAND_FILTER_FLOCK"
	New(datum/ai_graph_node/through)
		var/datum/ai_graph_node/inline/overclock/flock_move/N = new()
		..(through,list("move"=N))

//TODO: add flock navigation
datum/ai_graph_node/moveto/flock
	name = "Navigating"

datum/ai_graph_node/inline/overclock/flock_move
	New(interval)
		src.default_interval = interval ? interval : 1
		. = ..(new /datum/ai_graph_node/moveto/flock(), src.default_interval)

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