/obj/structure/cable/multilayer/MultiZ //This bridges powernets
	name = "multiZlayer cable hub"
	desc = "A flexible, superconducting insulated multilayer hub for heavy-duty power Ztransfer."
	icon = 'icons/obj/power.dmi'
	icon_state = "cablerelay-on"
	level = 2
	cable_layer = CABLE_LAYER_1|CABLE_LAYER_2|CABLE_LAYER_3
	machinery_layer = MACHINERY_LAYER_1

/obj/structure/cable/multilayer/MultiZ/get_cable_connections(powernetless_only)
	. = ..()
	var/turf/T = get_turf(src)
	. +=  locate(/obj/structure/cable/multilayer/MultiZ) in (SSmapping.get_turf_below(T))
	. +=  locate(/obj/structure/cable/multilayer/MultiZ) in (SSmapping.get_turf_above(T))
