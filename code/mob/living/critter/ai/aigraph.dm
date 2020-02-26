/*DEFINES
#define AI_GRAPH_NODE_RESULT_IN_PROGRESS 0		//Everything is fine, but the node is not complete yet.
#define AI_GRAPH_NODE_RESULT_COMPLETED 1		//The node has completed, and the graph should advance to the next node
#define AI_GRAPH_NODE_RESULT_SKIP -1			//Indicates that the node should be skipped.
#define AI_GRAPH_NODE_RESULT_ABORT -2			//Something has gone wrong, and the current branch should be aborted.

#define AI_GRAPH_WEIGHT_DEFAULT 100				//The base value for weighted nodes. Use this for neutral options in weighted branches.
*/////////

datum/ai_graph_root								//root of a nodegraph
	var/datum/ai_graph_node/root_node			//the first node in the tree
	var/host									//the thing containing the ai, what the ai should be controlling
	var/default_name = "Idling"					//what to return as a name if no nodes are active
	var/list/next_data							//a list of data to be sent into the graph
	var/list/data								//data stored in memory, reset every time a non in-progress result is recieved
	var/last_result = AI_GRAPH_NODE_RESULT_COMPLETED//the last result recieved

	New(hostvar)							//pass it the object running it, and it will make it available to all nodes in the graph
		..()
		src.host = hostvar
	
	disposing()
		..()
		src.stop()


	proc
		start()
			if ( !host ) return
			processing_items.Add(src)
		stop()
			if ( src in processing_items )
				processing_items.Remove(src)

		set_root(var/datum/ai_graph_node/root)
			root_node = root
			root_node.set_host(host)
			
		process()
			if ( !host ) return
			if ( istype(src.host, /mob/living) )
				var/mob/living/M = src.host
				if ( !M.is_npc )
					return
			if ( last_result != AI_GRAPH_NODE_RESULT_IN_PROGRESS )
				data = list()
				if ( next_data )
					var/d
					for(d in next_data)
						data[d] = next_data[d]
					next_data = null
				root_node.on_begin(data)
			last_result = root_node.on_tick(data)
		
		create(node_type, list/arg)
			var/datum/ai_graph_node/N
			if ( !arg ) N = new node_type()
			else N = new node_type(arglist(arg))
			return N
		
		get_name()
			if ( !root_node ) return src.default_name
			var/N = root_node.get_name()
			if (N) return N
			return src.default_name
		
		interrupt()
			if ( !root_node ) return
			root_node.on_interrupt()
			last_result = AI_GRAPH_NODE_RESULT_COMPLETED
		
		do_shutdown()
			src.stop()
			src.interrupt()
			if( istype(host, /mob) )
				var/mob/M = host
				walk(M,0)
		
		issue_command(list/order,immediate = 1)	//sets the next data to be sent into the graph. immediate causes this order to interrupt current execution
			if ( immediate ) src.interrupt()
			next_data = order



datum/ai_graph_node								//Base of the NodeGraph system
	var/name = "NODEBASE"						//The name of the node. Some systems may use this to give updates on the state of the AI.
	var/weight = AI_GRAPH_WEIGHT_DEFAULT		//The node's weight. Used for weighted random selection.
	var/host

	proc
		//////////////
		//MAIN METHODS

		//runs every tick, should be overriden to run your main loop. Takes a list as an argument. Use this to store information you want shared through the branch (such as targeting info).
		on_tick(var/list/data)
			LAGCHECK(LAG_LOW)
			return AI_GRAPH_NODE_RESULT_COMPLETED
		
		//runs when a node begins to run, before on_tick. Doesn't return anything
		on_begin(var/list/data)
			src.reset()
		
		//return the weight of the node, can be overriden for weighted nodes. Can take targeting data. Return -1 to indicate that the node cannot be run.
		weight(var/list/data)
			return src.weight
		
		//This should be overwritten to reset any values you don't want to persist between runs of a node
		reset()
			return
		
		//Check if the node can/should be run. should return ..._IN_PROGRESS if everything is fine, ..._SKIP if the node should be skipped, and ..._ABORT if the branch should abort. Recieves the same data as on_tick. Your check function should be a lightweight version of weight.
		check(var/list/data)
			return AI_GRAPH_NODE_RESULT_IN_PROGRESS
		
		//If the node's execution is interupted, make sure whatever the graph is controlling is in a valid state. Branches should cancel execution of active nodes.
		on_interrupt()
			src.reset()
		
		//Propagate a new host through nodes, should be overriden by branch
		set_host(var/newhost)
			src.host = newhost
		
		//Returns the name, overriden by branch
		get_name()
			return src.name


datum/ai_graph_node/branch						//Nodes designed to contain other nodes
	var/list/children = list()					//The list of the children of the branch
	var/head = 1								//The index of the current active child
	var/skipable = 0							//If the branch is aborted, should the abort command be passed up the graph(0) or can the faulty branch be safely skipped(1)? Don't turn this on unless you are absolutely sure

	name = "BRANCHBASE"

	reset()
		head = 1
		for(var/datum/ai_graph_node/node in src.children)
			node.reset()
	
	set_host(var/newhost)
		..(newhost)
		for(var/datum/ai_graph_node/node in src.children)
			node.set_host(newhost)
	
	on_interrupt()
		if ( head <= length(children) )
			children[head].on_interrupt()
		..()
	
	weight(list/data)
		. = -1
		for ( var/datum/ai_graph_node/N in src.children )
			. = max(.,N.weight(data))
	
	get_name()
		if ( head <= length(children) )
			return children[head].get_name()
		return src.name
	
	proc
		add_new_child(node_type, list/arg)
			var/datum/ai_graph_node/N
			if ( !arg ) N = new node_type()
			else N = new node_type(arglist(arg))
			src.add_child(N)
		add_child(var/datum/ai_graph_node/child)//Add a child node to the branch
			src.children += child
			child.set_host(src.host)

		on_abort()								//Return this to abort the branch
			src.reset()
			return skipable ? AI_GRAPH_NODE_RESULT_COMPLETED : AI_GRAPH_NODE_RESULT_ABORT

datum/ai_graph_node/branch/sequence			 	//A sequence branch will run its nodes in sequence
	name = "SEQUENCE"
	var/last_result = AI_GRAPH_NODE_RESULT_COMPLETED

	reset()
		..()
		last_result = AI_GRAPH_NODE_RESULT_COMPLETED
	
	get_name()
		if ( head <= length(children) )
			if ( last_result == AI_GRAPH_NODE_RESULT_IN_PROGRESS )
				return children[head].get_name()
		return src.name

	on_tick(var/list/data)
		..()
		if ( head > length(children) )
			src.reset()
			return AI_GRAPH_NODE_RESULT_COMPLETED
		if ( last_result != AI_GRAPH_NODE_RESULT_IN_PROGRESS )
			var/result = children[head].check(data)
			switch(result)
				if(AI_GRAPH_NODE_RESULT_SKIP)
					return src.advance()
				if(AI_GRAPH_NODE_RESULT_ABORT)
					return src.on_abort()
			children[head].on_begin(data)
		last_result = children[head].on_tick(data)
		switch(last_result)
			if (AI_GRAPH_NODE_RESULT_IN_PROGRESS)
				return last_result
			if (AI_GRAPH_NODE_RESULT_SKIP,AI_GRAPH_NODE_RESULT_IN_PROGRESS)
				return src.advance()
		//abort or some other bad state recieved
		return src.on_abort()

	proc
		advance()
			head += 1
			if ( head >= length(children) )
				src.reset()
				return AI_GRAPH_NODE_RESULT_COMPLETED
			else
				return AI_GRAPH_NODE_RESULT_IN_PROGRESS

datum/ai_graph_node/branch/selector			//Runs the node with the highest weight (in a tie, the winner is chosen randomly)
	name = "SELECTOR"
	var/last_result = AI_GRAPH_NODE_RESULT_COMPLETED

	reset()
		last_result = AI_GRAPH_NODE_RESULT_COMPLETED
		
	get_name()
		if ( head && head <= length(children) )
			//if ( last_result == AI_GRAPH_NODE_RESULT_IN_PROGRESS )
			return children[head].get_name()
		return src.name
	
	on_tick(data)
		if ( last_result != AI_GRAPH_NODE_RESULT_IN_PROGRESS ) //select a new node to run
			..()
			if ( !length(children) ) return on_abort()
			var/list/weights[0]
			var/best = -1
			for (var/i = 1; i <= length(children); i++)
				var/W = children[i].weight(data)
				weights += W
				if ( W > best ) best = W
			if ( best == -1 ) return on_abort()
			var/list/possibleNodes[0]
			for (var/i = 1; i <= length(children); i++)
				if ( weights[i] == best )
					possibleNodes += i
			head = pick(possibleNodes)
			children[head].on_begin(data)
		last_result = children[head].on_tick(data)
		return last_result

datum/ai_graph_node/inline
	name = "INLINE_BASE"
	var/datum/ai_graph_node/next
	var/id
	var/previous_value						//The value we changed [ID] from

	reset()
		if ( next ) next.reset()
	
	New(datum/ai_graph_node/N = null)
		if ( N ) src.set_next(N)
	
	on_begin(list/data)
		..()
		if ( !next ) return AI_GRAPH_NODE_RESULT_SKIP
		src.add_data(data)
		return next.on_begin(data)
	
	on_tick(list/data)
		..()
		if ( !next ) return AI_GRAPH_NODE_RESULT_SKIP
		. = next.on_tick(data)
		if ( . != AI_GRAPH_NODE_RESULT_IN_PROGRESS )
			src.remove_data(data)
	
	weight(list/data)
		..()
		if ( !next ) return -1
		src.add_data(data)
		var/out = next.weight(data)
		src.remove_data(data)
		return out
	
	set_host(newhost)
		..()
		if ( next ) next.set_host(newhost)
	
	on_interrupt()
		if ( next ) next.on_interrupt()
		..()
	
	check(list/data)
		if ( next )
			src.add_data(data)
			. = next.check(data)
			src.remove_data(data)
		else . = AI_GRAPH_NODE_RESULT_SKIP
	
	get_name()
		. = ..()
		if ( next ) return next.get_name()
		
	
	proc
		set_next(datum/ai_graph_node/N)
			src.next = N
			src.next.set_host(src.host)
		
		add_data(list/data)
			previous_value = (id in data) ? data[id] : null
			data[id] = do_inline(data)
		
		remove_data(list/data)
			if ( id in data )
				if ( previous_value )
					data[id] = previous_value
				else
					data.Remove(data[id])
		
		do_inline(list/data)							//override this to set the inline function, return the data you want to set [ID] to
			return null

#define AI_GRAPH_NODE_INLINE_COMMAND_FILTER_OVERRIDE(name,override,default) (override && name in override) ? override[name] : new default()
datum/ai_graph_node/inline/command_filter
	name = "COMMAND_FILTER"
	var/datum/ai_graph_node/override			// The active command override node
	var/last_result = AI_GRAPH_NODE_RESULT_COMPLETED
	//command list - override New to add more
	var/list/commands

	reset()
		..()
		override = null
		last_result = AI_GRAPH_NODE_RESULT_COMPLETED

	New(datum/ai_graph_node/through,list/override_commands)
		..(through)
		commands = list()
		commands["move"] = AI_GRAPH_NODE_INLINE_COMMAND_FILTER_OVERRIDE("move",override_commands,/datum/ai_graph_node/moveto)//(override_commands && "move" in override_commands) ? override_commands["move"] : /datum/ai_graph_node/moveto
		commands["wait"] = AI_GRAPH_NODE_INLINE_COMMAND_FILTER_OVERRIDE("wait",override_commands,/datum/ai_graph_node/wait) //datum/ai_graph_node/wait

		for ( var/command in commands )
			commands[command].set_host(src.host)
	
	on_begin(data)
		if ( next ) next.reset()
		reset()
	
	get_name()
		. = ..()
		if ( override ) . = override.get_name()
	
	set_host(newhost)
		. = ..()
		for ( var/command in commands )
			commands[command].set_host(src.host)
	
	on_interrupt()
		if ( override ) override.on_interrupt()
		. = ..()

	on_tick(list/data)
		LAGCHECK(LAG_LOW)
		if ( !next ) return AI_GRAPH_NODE_RESULT_ABORT
		var/command_ready = ( data && "command" in data)
		if ( !override )
			if ( !command_ready && last_result == AI_GRAPH_NODE_RESULT_IN_PROGRESS)
				last_result = next.on_tick(data)
				return last_result
			if ( !command_ready )
				next.on_begin()
				last_result = next.on_tick(data)
				return last_result

		if ( !override )
			override = commands[data["command"]]
			var/checked = override.check(data)
			if ( checked != AI_GRAPH_NODE_RESULT_COMPLETED && checked != AI_GRAPH_NODE_RESULT_IN_PROGRESS)
				override = null
				return AI_GRAPH_NODE_RESULT_COMPLETED

			override.on_begin(data)
		var/result = override.on_tick(data)
		if ( result != AI_GRAPH_NODE_RESULT_IN_PROGRESS ) //DO NOT COUNT ON COMMAND_FILTER TO PASS ABORTS FROM ITS OVERRIDES
			override = null
			return AI_GRAPH_NODE_RESULT_COMPLETED
		return AI_GRAPH_NODE_RESULT_IN_PROGRESS

datum/ai_graph_node/inline/overclock					//alters the speed that the graph is run. DO NOT STACK THESE. If you need to change the speed temporarily, use overclock_modifier
	name = "OVERCLOCK"
	id = "overclock_interval"
	var/active = 0
	var/default_interval = 10
	var/last_result = AI_GRAPH_NODE_RESULT_COMPLETED

	New(datum/ai_graph_node/N,interval)
		. = ..(N)
		src.default_interval = interval ? interval : 10

	reset()
		..()
		src.last_result = AI_GRAPH_NODE_RESULT_COMPLETED
		src.active = 0
	
	on_begin(list/data)
		..(data)
		src.active = 1
		src.last_result = AI_GRAPH_NODE_RESULT_IN_PROGRESS
		SPAWN_DBG(0)
			while ( src.active )
				LAGCHECK(LAG_LOW)
				src.last_result = next.on_tick(data)
				if ( src.last_result != AI_GRAPH_NODE_RESULT_IN_PROGRESS )
					src.active = 0
					src.remove_data(data)
				sleep(("overclock_interval" in data) ? data["overclock_interval"] : src.default_interval)
	
	on_tick(list/data)
		return src.last_result

	do_inline(list/data)
		return src.default_interval

//sets the overclock interval
datum/ai_graph_node/inline/overclock_modifier
	name = "OVERCLOCK_MODIFIER"
	id = "overclock_interval"
	var/interval = 10

	New(datum/ai_graph_node/N,rate)
		..(N)
		src.interval = rate ? rate : 10

datum/ai_graph_node/inline/visible_items
	name = "INLINE_VISIBLE_ITEMS"
	id = "visible_items"
	var/range

	New(datum/ai_graph_node/N,range)
		src.range = range
		. = ..()

	do_inline(list/data)
		. = list()
		var/inview
		if( range )
			inview = view(range,src.host)
		else
			inview = view(src.host)
		for (var/obj/item/I in inview)
			. += I

datum/ai_graph_node/inline/visible_items/nearest
	name = "INLINE_NEAREST_ITEM"
	id = "nearest_item"

	do_inline(list/data)
		var/inview
		if( range )
			inview = view(range,src.host)
		else
			inview = view(src.host)
		for (var/obj/item/I in inview)
			if ( !. )
				. = I
			else
				if ( get_dist(src.host,I) < get_dist(src.host,(.).loc) )
					. = I