

/obj/machinery/computer/tram_controls
	name = "tram controls"
	desc = "An interface for the tram that lets you tell the tram where to go and hopefully it makes it there. I'm here to describe the controls to you, not to inspire confidence."
	icon_screen = "tram"
	icon_keyboard = "atmos_key"
	circuit = /obj/item/circuitboard/computer/tram_controls
	flags_1 = NODECONSTRUCT_1
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	var/id //id of controlled tram
	var/tram_old_location_id //id of last visited tram station

	light_color = LIGHT_COLOR_GREEN

/obj/machinery/computer/tram_controls/LateInitialize()
	. = ..()
	connect2tram(id)
	find_tram_location(id)

/obj/machinery/computer/tram_controls/Destroy()
	for(var/destination_id in GLOB.assoc_tram_landmarks)
		var/obj/effect/landmark/tram/destination = GLOB.assoc_tram_landmarks[destination_id]
		UnregisterSignal(destination, COMSIG_ATOM_ENTERED)
	return ..()

/**
 * Finds the tram from the console
 *
 * Locates tram master in the assoc_trams global list by id,
 * or try to find it by tram under console
 */
/obj/machinery/computer/tram_controls/proc/connect2tram(new_id)
	if(new_id)//tram remote controls
		id = new_id
	else//tram direct controls
		var/obj/structure/industrial_lift/tram/tram_loc = locate() in loc //try to find tram under console
		if(tram_loc?.id)
			id = new_id

///Listen for tram landmark crossing
/obj/machinery/computer/tram_controls/proc/on_waypoint_cross(datum/source, obj/structure/industrial_lift/tram/central/crosser)
	if(istype(crosser) && crosser.id == id)
		find_tram_location()

/**
 * Finds the location of the tram
 *
 * The central tram piece checking the contents of the turf its on
 * for a tram landmark when it docks anywhere. This assures the tram actually knows where it is after docking,
 * even in the worst cast scenario.
 */
/obj/machinery/computer/tram_controls/proc/find_tram_location()
	var/obj/structure/industrial_lift/tram/central/tram_central = GLOB.assoc_trams[id]
	var/turf/tram_location = get_turf(tram_central)
	var/obj/effect/landmark/tram/where_we_are = locate(/obj/effect/landmark/tram) in tram_location.contents
	if(where_we_are)
		tram_old_location_id = where_we_are.destination_id

/obj/machinery/computer/tram_controls/ui_state(mob/user)
	return GLOB.not_incapacitated_state

/obj/machinery/computer/tram_controls/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TramControl", name)
		ui.open()

/obj/machinery/computer/tram_controls/ui_data(mob/user)
	var/list/data = list()
	var/obj/structure/industrial_lift/tram/central/tram_central = GLOB.assoc_trams[id]
	data["moving"] = tram_central?.lift_master_datum.travelling
	data["broken"] = tram_central ? FALSE : TRUE
	return data

/obj/machinery/computer/tram_controls/ui_static_data(mob/user)
	var/list/data = list()
	data["destinations"] = get_destinations()
	return data

/**
 * Finds the destinations for the tram console gui
 *
 * Pulls tram landmarks from the assoc_tram_landmarks gobal list
 * and uses those to show the proper icons and destination
 * names for the tram console gui.
 */
/obj/machinery/computer/tram_controls/proc/get_destinations()
	. = list()
	find_tram_location()
	for(var/destination_id in GLOB.assoc_tram_landmarks)
		var/obj/effect/landmark/tram/destination = GLOB.assoc_tram_landmarks[destination_id]
		var/list/this_destination = list()
		this_destination["here"] = destination.destination_id == tram_old_location_id
		this_destination["name"] = destination.name
		this_destination["dest_icons"] = destination.tgui_icons
		this_destination["id"] = destination.destination_id
		. += list(this_destination)	
		AddElement(/datum/element/connect_loc, destination, list(COMSIG_ATOM_ENTERED = .proc/on_waypoint_cross))

/obj/machinery/computer/tram_controls/ui_act(action, params)
	. = ..()
	var/obj/structure/industrial_lift/tram/central/tram_central = GLOB.assoc_trams[id]
	var/datum/lift_master/tram_master = tram_central.lift_master_datum
	if(. || tram_master.travelling)
		return
	var/destination_name = params["destination"]
	var/obj/effect/landmark/tram/to_where
	for(var/destination_id in GLOB.assoc_tram_landmarks)
		var/obj/effect/landmark/tram/destination = GLOB.assoc_tram_landmarks[destination_id]
		if(destination && destination.name == destination_name)
			to_where = destination
	if(!to_where)
		CRASH("Controls couldn't find the destination \"[destination_name]\"!")
	if(tram_master.controls_locked || tram_master.travelling) // someone else started
		return
	tram_master.tram_travel(to_where)
	update_static_data(usr) //show new location of tram
