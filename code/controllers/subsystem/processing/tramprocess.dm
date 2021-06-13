PROCESSING_SUBSYSTEM_DEF(tramprocess)
	name = "Tram Process"
	wait = 1
	/// only used on maps with trams, so only enabled by such.
	can_fire = FALSE

	///A associated list of currently active lifts/platforms/trams
	var/list/assoc_lifts = list() //list of {id = lift_master}
	///A list of tram central parts
	var/list/tram_centrals = list() //list of {/obj/structure/industrial_lift/tram/central}
	///A list of tram landmarks
	var/list/tram_landmarks = list() //list of {obj/effect/landmark/tram}	
