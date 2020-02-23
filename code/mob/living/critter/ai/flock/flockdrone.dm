datum/ai_graph_root/flockdrone
	New(host)
		..(host)
		
		var/datum/ai_graph_node/branch/S = src.create(/datum/ai_graph_node/branch/selector)
		S.name = "Thinking"
		var/datum/ai_graph_node/N
		//build flock decision tree here

		//main selector
		S.add_new_child(/datum/ai_graph_node/wander)


		//add selector to command filter then to root
		src.set_root( src.create(/datum/ai_graph_node/inline/command_filter/flock,list(S)) )

datum/ai_graph_node/inline/command_filter/flock
	name = "COMMAND_FILTER_FLOCK"
	New(datum/ai_graph_node/through)
		var/datum/ai_graph_node/inline/overclock/N = new /datum/ai_graph_node/inline/overclock(new /datum/ai_graph_node/moveto)
		N.default_interval = 1
		..(through,list("move"=N))

/*
root
	command_filter selector
		wander
		visible_item/harvest sequence
			move
			.
		visible_container/rummage sequence
			move
			.
		visible_ally_injured/repair sequence
			move
			.
		visible_flocktile/replicate sequence
			move
			.
		visible_closed_usable_door/explore move
*/

/*
/datum/aiHolder/flock/drone

/datum/aiHolder/flock/drone/New()
	..()
	default_task = get_instance(/datum/aiTask/prioritizer/flock/drone, list(src))

///////////////////////////////////////////////////////////////////////////////////////////////////////////

// main default "what do we do next" task, run for one tick and then switches to a new task
/datum/aiTask/prioritizer/flock/drone
	name = "thinking"

/datum/aiTask/prioritizer/flock/drone/New()
	..()
	// populate the list of tasks
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/replicate, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/build, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/repair, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/open_container, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/rummage, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/sequence/goalbased/harvest, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/timed/targeted/flockdrone_shoot, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/timed/targeted/flockdrone_capture, list(holder, src))
	transition_tasks += holder.get_instance(/datum/aiTask/timed/wander, list(holder, src))

/datum/aiTask/prioritizer/flock/drone/on_reset()
	..()
	if(holder.owner)
		holder.owner.a_intent = INTENT_GRAB
*/