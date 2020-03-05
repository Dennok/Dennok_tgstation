#define RELAY_OK 1
#define RELAY_ADD_CABLE 2
#define RELAY_ADD_METAL 3

/obj/machinery/power/deck_relay //This bridges powernets
	name = "Multi-deck power adapter"
	desc = "A huge bundle of double insulated cabling which seems to run up into the ceiling."
	icon = 'icons/obj/power.dmi'
	icon_state = "cablerelay-off"
	max_integrity = 350
	integrity_failure = 0.25
	var/broken_status = RELAY_OK
	var/obj/machinery/power/deck_relay/below ///The relay that's below us (for bridging powernets)
	var/obj/machinery/power/deck_relay/above ///The relay that's above us (for bridging powernets)
	anchored = TRUE
	density = FALSE

/obj/machinery/power/deck_relay/examine(mob/user)
	. += ..()
	if(!anchored)
		. += "<span class='notice'>The securing bolts are undone.</span>"
	if(broken_status == RELAY_ADD_CABLE)
		. += "<span class='notice'>The cable insulation is torn apart and the wires are frayed beyond use.</span>"
	if(broken_status == RELAY_ADD_METAL)
		. += "<span class='notice'>The cable insulation is torn apart and the wiring is exposed.</span>"
	. += "<span class='notice'>above:[above]:[above?1:0], below:[below]:[below?1:0] </span>"

/obj/machinery/power/deck_relay/attackby(obj/item/I, mob/user, params)
	if(default_unfasten_wrench(user, I))
		if(!anchored && broken_status == RELAY_OK)
			break_connections()
			return
		return FALSE
		. = ..()
	if(istype(I, /obj/item/stack/cable_coil) && broken_status == RELAY_ADD_CABLE)
		var/obj/item/stack/C = I
		if(C.use(15))
			to_chat(user, "<span class='notice'>You fix the frayed wires inside [src].</span>")
			icon_state = "cablerelay-broken-cable"
			broken_status = RELAY_ADD_METAL
			return
		else
			to_chat(user, "You need 15 cables to rewire [src].")
			return
	if(istype(I, /obj/item/stack/sheet/metal) && broken_status == RELAY_ADD_METAL)
		var/obj/item/stack/S = I
		if(S.use(10))
			to_chat(user, "<span class='notice'>You reseal the insulation for [src].</span>")
			icon_state = "cablerelay"
			broken_status = RELAY_OK
			obj_integrity = max_integrity
			return
		else
			to_chat(user, "You need 10 metal to mend [src].")
			return
	. = ..()

/obj/machinery/power/deck_relay/obj_break()
	..()
	if(broken_status == RELAY_OK)
		break_connections()
		visible_message("<span class='warning'>[src]'s insulation breaks, fraying and severing the cable bundle!</span>")
		playsound(loc, 'sound/effects/glassbr3.ogg', 100, TRUE)
		icon_state = "cablerelay-broken"
		broken_status = RELAY_ADD_CABLE

/obj/machinery/power/deck_relay/obj_destruction()
	return //this shouldn't break under usual means

/obj/machinery/power/deck_relay/Destroy()
	break_connections()
	return ..()

///Lose connections and reset the merged powernet so it makes 2 new seperated ones
/obj/machinery/power/deck_relay/proc/break_connections()
	if(above)
		var/turf/above_deck_relay = get_turf(above)
		var/obj/structure/cable/above_cable = above_deck_relay.get_cable_node()
		if(above_cable)
			var/datum/powernet/above_powernet = new()
			propagate_network(above_cable, above_powernet)
		above.below = null
		above = null
	if(below)
		var/turf/below_deck_relay = get_turf(below)
		var/obj/structure/cable/below_cable = below_deck_relay.get_cable_node()
		if(below_cable)
			var/datum/powernet/below_powernet = new()
			propagate_network(below_cable, below_powernet)
		below.above = null
		below = null

///Allows you to scan the relay with a multitool to see stats/reconnect relays
/obj/machinery/power/deck_relay/multitool_act(mob/user, obj/item/I)
	if(!anchored)
		to_chat(user, "<span class='danger'>You need to wrench this into place before getting a reading!</span>")
		return TRUE
	if(broken_status == RELAY_ADD_CABLE || broken_status == RELAY_ADD_METAL)
		to_chat(user, "<span class='danger'>The [src] isn't in proper shape to get a reading!</span>")
		return TRUE
	if(powernet && (above || below))//we have a powernet and at least one connected relay
		to_chat(user, "<span class='danger'>Total power: [DisplayPower(powernet.avail)]\nLoad: [DisplayPower(powernet.load)]\nExcess power: [DisplayPower(surplus())]</span>")
	if(!above && !below)
		to_chat(user, "<span class='danger'>Cannot access valid powernet. Attempting to re-establish. Ensure any relays above and below are aligned properly and on cable nodes.</span>")
		find_relays()
		addtimer(CALLBACK(src, .proc/refresh), 20) //Wait a bit so we can find the one below, then get powering
	return TRUE

/obj/machinery/power/deck_relay/Initialize()
	. = ..()
	name = rand(1000)
	addtimer(CALLBACK(src, .proc/find_relays), 30)
	addtimer(CALLBACK(src, .proc/refresh), 50) //Wait a bit so we can find the one below, then get powering

///Handles re-acquiring + merging powernets found by find_relays()
/obj/machinery/power/deck_relay/proc/refresh()
	if(above)
		above.merge(src)
	if(below)
		below.merge(src)

///Merges the two powernets connected to the deck relays
/obj/machinery/power/deck_relay/proc/merge(var/obj/machinery/power/deck_relay/DR)
	if(!DR)
		return
	var/turf/merge_from = get_turf(DR)
	var/turf/merge_to = get_turf(src)
	var/obj/structure/cable/C = merge_from.get_cable_node()
	var/obj/structure/cable/XR = merge_to.get_cable_node()
	if(C && XR)
		merge_powernets(XR.powernet,C.powernet)//Bridge the powernets.

///Locates relays that are above and below this object
/obj/machinery/power/deck_relay/proc/find_relays()
	var/turf/T = get_turf(src)
	if(!T || !istype(T))
		return FALSE
	below = null //in case we're re-establishing
	above = null
	var/obj/structure/cable/C = T.get_cable_node() //check if we have a node cable on the machine turf, the first found is picked
	if(C && C.powernet)
		C.powernet.add_machine(src) //Nice we're in.
		powernet = C.powernet
	below = locate(/obj/machinery/power/deck_relay) in(SSmapping.get_turf_below(T))
	above = locate(/obj/machinery/power/deck_relay) in(SSmapping.get_turf_above(T))
	if(below || above)
		icon_state = "cablerelay-on"
	return TRUE

///refresh() on connect_to_network()
/obj/machinery/power/deck_relay/connect_to_network()
	to_chat(world, "<span class='danger'>[name] connect_to_network()</span>")
	. = ..()
	if(.)
		//addtimer(CALLBACK(src, .proc/refresh), 0)
		addtimer(CALLBACK(src, .proc/find_relays), 30)
		addtimer(CALLBACK(src, .proc/refresh), 50) //Wait a bit so we can find the one below, then get powering


///break_connections() on disconnect_from_network()
/obj/machinery/power/deck_relay/disconnect_from_network()
	to_chat(world, "<span class='danger'>[name] disconnect_from_network()</span>")
	addtimer(CALLBACK(src, .proc/break_connections), 0) 
	return ..()


////////////////////////////////////////////
// POWERBRIGE DATUM
// powernet over powernets
/////////////////////////////////////
/datum/powerbrige
	var/number					// unique id
	var/list/cables = list()	// all cables & junctions
	var/list/nodes = list()		// all connected machines

/datum/powerbrige/New()
	return ..()

/datum/powerbrige/Destroy()
	cables.Cut()
	nodes.Cut()
	return ..()

/datum/powerbrige/proc/is_empty()
	return !cables.len && !nodes.len

//remove a cable from the current powerbrige
//Warning : this proc DON'T check if the cable exists
/datum/powerbrige/proc/remove_cable(obj/structure/cable/C)
	cables -= C
	//C.powernet = null
	//if(is_empty())//the powernet is now empty...
	//	qdel(src)///... delete it

//add a cable to the current powerbrige
//Warning : this proc DON'T check if the cable exists
/datum/powerbrige/proc/add_cable(obj/structure/cable/C)
	//if(C.powernet)// if C already has a powernet...
	//	if(C.powernet == src)
	//		return
	//	else
	//		C.powernet.remove_cable(C) //..remove it
	//C.powernet = src
	cables +=C

//remove a power machine from the current powerbrige
//if the powernet is then empty, delete it
//Warning : this proc DON'T check if the machine exists
/datum/powerbrige/proc/remove_machine(obj/machinery/power/M)
	nodes -=M
	//M.powernet = null
	if(is_empty())//the powerbrige is now empty...
		qdel(src)///... delete it


//add a power machine to the current powerbrige
//Warning : this proc DON'T check if the machine exists
/datum/powerbrige/proc/add_machine(obj/machinery/power/deck_relay/M)
	if(M.powerbrige)// if M already has a powerbrige...
		if(M.powerbrige == src)
			return
		else
			M.disconnect_from_powerbrige()//..remove it
	M.powerbrige = src
	nodes[M] = M

//resets?
/datum/powerbridge/proc/reset()
	return

/proc/merge_powerbridges(datum/powerbridge/bridge1, datum/powerbridge/bridge2)
	if(!bridge1 || !bridge2) //if one of the powerbridge doesn't exist, return
		return

	if(bridge1 == bridge2) //don't merge same powerbridges
		return

	//We assume bridge1 is larger. If bridge2 is in fact larger we are just going to make them switch places to reduce on code.
	if(bridge1.nodes.len < bridge2.nodes.len)	//bridge2 is larger than bridge1. Let's switch them around
		var/temp = bridge1
		bridge1 = bridge2
		bridge2 = temp

	//merge bridge2 into bridge1
	for(var/obj/structure/cable/Cable in bridge2.cables) //merge cables
		net1.add_cable(Cable)

	for(var/obj/machinery/power/Node in bridge2.nodes) //merge power machines
		if(!Node.connect_to_bridge())
			Node.disconnect_from_bridge() //if somehow we can't connect the machine to the new powerbridge, disconnect it from the old nonetheless

	return bridge1

















