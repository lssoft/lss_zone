﻿function custom_init(){
	// Set zone type view
	var zone_type_field=document.getElementById("zone_type");
	var zone_type=zone_type_field.value;
	var zone_type_btn=document.getElementById(zone_type);
	radio_click(zone_type_btn);
}