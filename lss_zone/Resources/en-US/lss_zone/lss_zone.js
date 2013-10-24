﻿var delimiter=",";
var settings_arr = new Array ();
var materials_arr = new Array ();
var presets_arr = new Array ();
var categories_arr = new Array ();
var categories_autosuggest = {};

function callRuby(actionName) {
	query = 'skp:get_data@' + actionName;
	window.location.href = query;
}

function get_setting(setting_pair_str) {
	setting_pair_str=setting_pair_str.replace("*", "\'"); // Added 01-Sep-12 it is a fix of unterminated string constant problem when units are set to feet
	var setting_pair=setting_pair_str.split("|");
	settings_arr.push(setting_pair);
}

function set_progress_state() {
	document.body.style.cursor="progress"
}

function set_default_state() {
	document.body.style.cursor="default"
}

function get_material(mat_str) {
	materials_arr.push(mat_str);
}

function clear_mats_arr() {
	materials_arr = new Array ();
}

function get_category(cat_str) {
	categories_arr.push(cat_str);
}

function clear_cats_arr() {
	categories_arr = new Array ();
}

function bind_categories() {
	if (document.getElementById("category")){
		categories_autosuggest = new autosuggest("category", categories_arr, null, send_auto_category());
		categories_autosuggest.text_delimiter=[",", ";"];
		categories_autosuggest.response_time=10;
	}
}

function send_auto_category(){
	var category_field=document.getElementById("category");
	act_name="obtain_setting"+ delimiter+ category_field.id + delimiter + category_field.value;
	callRuby(act_name);
	return false;
}

function re_bind_categories() {
	categories_autosuggest.bindArray(categories_arr);
}

function press_eye_dropper_btn(surf_type) {
	var btn_id=surf_type + "_eye_dropper";
	var btn=document.getElementById(btn_id);
	btn.className="img_btn_pressed";
}

function unpress_eye_dropper_btn(surf_type) {
	var btn_id=surf_type + "_eye_dropper";
	var btn=document.getElementById(btn_id);
	btn.className="img_btn";
}

function refresh_colors() {
	for (i=0; i<settings_arr.length; i++) {
		var input_ctrl=document.getElementById(settings_arr[i][0]);
		if (input_ctrl) {
			if (input_ctrl.id.split("_")[1] == 'material') {
				input_ctrl.value=settings_arr[i][1];
				if (input_ctrl.id=="floor_material") {
					var sel_ind=input_ctrl.selectedIndex;
					var picker_btn = document.getElementById("floor_eye_dropper");
					if (sel_ind>0){
						var col = materials_arr[sel_ind-1].split("|")[1];
						picker_btn.style.backgroundColor = "rgb(" + col + ")";
					}
				}
				if (input_ctrl.id=="ceiling_material") {
					var sel_ind=input_ctrl.selectedIndex;
					var picker_btn = document.getElementById("ceiling_eye_dropper");
					if (sel_ind>0){
						var col = materials_arr[sel_ind-1].split("|")[1];
						picker_btn.style.backgroundColor = "rgb(" + col + ")";
					}
				}
				if (input_ctrl.id=="wall_material") {
					var sel_ind=input_ctrl.selectedIndex;
					var picker_btn = document.getElementById("wall_eye_dropper");
					if (sel_ind>0){
						var col = materials_arr[sel_ind-1].split("|")[1];
						picker_btn.style.backgroundColor = "rgb(" + col + ")";
					}
				}
			}
		}
	}
}

function create_mat_select(container_id, select_id) {
	var mat_container=document.getElementById(container_id);
	mat_container.innerHTML="";
	var material = document.createElement("SELECT");
	var first_opt = document.createElement("OPTION");
	first_opt.value="";
	first_opt.innerHTML="Choose material";
	material.appendChild(first_opt);
	for (i=0; i<materials_arr.length; i++) {
		var mat=document.createElement("OPTION");
		mat_name=materials_arr[i].split("|")[0];
		mat.value=mat_name;
		mat.innerHTML=mat_name;
		material.appendChild(mat);
	}
	
	material.setAttribute("id", select_id);
	material.className = "value_input";
	material.onchange=ctrl_onchange;
	mat_container.appendChild(material);
}

function input_btn_onclick(evt){
	act_name=this.id;
	callRuby(act_name);
}

function build_mat_list() {
	create_mat_select("floor_mat_container", "floor_material");
	create_mat_select("wall_mat_container", "wall_material");
	create_mat_select("ceiling_mat_container", "ceiling_material");
}

function apply_defaults(){
	for (i=0; i<settings_arr.length; i++) {
		var img_btn=document.images[settings_arr[i][0]]
		if (img_btn) {
			if (settings_arr[i][1]=="true") {
				img_btn.setAttribute("className", "btn_checked");
			};
			else {
				img_btn.setAttribute("className", "btn_unchecked");
			};
		}
		var input_ctrl=document.getElementById(settings_arr[i][0]);
		if (input_ctrl) {
			if (input_ctrl.type == 'text') {
				input_ctrl.value=settings_arr[i][1];
			}
			if (input_ctrl.type == 'checkbox') {
				if (settings_arr[i][1]=='true'){
					input_ctrl.checked=true;
				}
				else{
					input_ctrl.checked=false;
				}
			}
			if (input_ctrl.className=="value_input"){
				input_ctrl.value=settings_arr[i][1];
			}
			if (input_ctrl.id.split("_")[1] == 'material') {
				input_ctrl.value=settings_arr[i][1];
				var picker_btn=false;
				var sel_ind=0;
				if (input_ctrl.id=="floor_material") {
					sel_ind=input_ctrl.selectedIndex;
					picker_btn = document.getElementById("floor_eye_dropper");
				}
				if (input_ctrl.id=="ceiling_material") {
					sel_ind=input_ctrl.selectedIndex;
					picker_btn = document.getElementById("ceiling_eye_dropper");
				}
				if (input_ctrl.id=="wall_material") {
					sel_ind=input_ctrl.selectedIndex;
					picker_btn = document.getElementById("wall_eye_dropper");
				}
				if (picker_btn){
					if (sel_ind>0){
						var col = materials_arr[sel_ind-1].split("|")[1];
						picker_btn.style.backgroundColor = "rgb(" + col + ")";
					}
				}
			}
			// Special setting handling
			// Setting 'zone type' radio into appropriate state
			if (input_ctrl.id == 'zone_type') {
				input_ctrl.value=settings_arr[i][1];
				switch(input_ctrl.value)
				{
					case "room":
						var room_btn=document.getElementById("room");
						if (room_btn){
							radio_click(room_btn);
						}
						break;
					case "box":
						var box_btn=document.getElementById("box");
						if (box_btn){
							radio_click(box_btn);
						}
						break;
					case "flat":
						var flat_btn=document.getElementById("flat");
						if (flat_btn){
							radio_click(flat_btn);
						}
						break;
					default:
						break;
				}
			}
		}
	}
}

function load_init_data() {
	callRuby('get_materials');
	callRuby('get_categories');
	obtain_defaults();
	document.onkeypress = stopRKey; //It is a trick to prevent onclick event of the first image button after pressing Enter key
}

//Function to prevent onclick event of the first image button after pressing Enter key
function stopRKey(evt) { 
  var evt = (evt) ? evt : ((event) ? event : null); 
  if (evt.keyCode == 13)   {return false;};
} 

function obtain_defaults(){
	callRuby("get_settings");
	apply_defaults();
	if (typeof window.custom_init == "function") { // Checks if custom_init exists
		custom_init(); // Calls a function within custom *.js file
	}
}

function reset_tool() {
	actionName="reset"
	callRuby(actionName);
}

function apply_settings() {
	callRuby("apply_settings");
}

function terminate_tool() {
	callRuby("terminate_tool");
}

function key_dwn(field) {
	if (event.keyCode==13) {
		send_setting(field);
		return false;
	}
}

function key_up(field) {
	if (event.keyCode==13) {
		send_setting(field);
		return false;
	}
}

function prevent_enter(field){
	if (event.keyCode==13) {
		event.returnValue = false; 
		event.cancel = true;
		return false;
	}
}

function click_chk(btn) {
	if ((btn.getAttribute("className")=="btn_unchecked") || (btn.getAttribute("className")=="btn_unchecked_over")) {
		btn.setAttribute("className", "btn_checked");
		act_name="obtain_setting"+ delimiter+ btn.id+ delimiter +"true";
	}
	else {
		btn.setAttribute("className", "btn_unchecked");
		act_name="obtain_setting"+ delimiter+ btn.id+ delimiter +"false";
	}
	callRuby(act_name);
	callRuby("get_settings");
}

function click_speed(btn) {
	callRuby(btn.id);
	callRuby("get_settings");
}

function btn_over(btn) {
	if (btn.getAttribute("className")=="btn_unchecked") {
		btn.setAttribute("className", "btn_unchecked_over");
	}
	else {
		btn.setAttribute("className", "btn_checked_over");
	}
}

function btn_out(btn) {
	if ((btn.getAttribute("className")=="btn_unchecked_over") || (btn.getAttribute("className")=="btn_unchecked")) {
		btn.setAttribute("className", "btn_unchecked");
	}
	else {
		btn.setAttribute("className", "btn_checked");
	}
}

function speed_btn_over(btn) {
	btn.setAttribute("className", "speed_btn_over");
}

function speed_btn_out(btn) {
	btn.setAttribute("className", "speed_btn");
}

function radio_over(btn) {
	if (btn.getAttribute("className")=="radio_unselected") {
		btn.setAttribute("className", "radio_unselected_over");
	}
}

function radio_out(btn) {
	if (btn.getAttribute("className")=="radio_unselected_over") {
		btn.setAttribute("className", "radio_unselected");
	}
}

function radio_click(btn) {
	if ((btn.getAttribute("className")=="radio_unselected_over") || (btn.getAttribute("className")=="radio_unselected")) {
		radio_grp=btn.parentNode;
		for (i=0; i < document.images.length; i++) {
			if (document.images[i].parentNode==radio_grp) {
				document.images[i].setAttribute("className", "radio_unselected");
			}
		}
		btn.setAttribute("className", "radio_selected");
		for (i=0; i < radio_grp.all.length; i++) {
			if (radio_grp.all[i].type=="hidden") {
				radio_grp.all[i].value=btn.id;
				send_setting(radio_grp.all[i]);
			}
		}
	}
}

function send_setting(setting_control) {
	if (setting_control.type == 'checkbox') {
		act_name="obtain_setting"+ delimiter+ setting_control.id+ delimiter +setting_control.checked;
	}
	else {
		act_name="obtain_setting"+ delimiter+ setting_control.id+ delimiter +setting_control.value.replace(delimiter, ".").replace("'", "*");
	}
	callRuby(act_name);
	callRuby("get_settings");
}

function send_slider_val(val_name, val) {
	act_name="obtain_setting"+ delimiter+ val_name+ delimiter + val;
	callRuby(act_name);
	callRuby("get_settings");
}

function key_up_body(event){
	if (event.keyCode==27){
		callRuby("cancel_action");
	}
}

function draw_contour() {
	callRuby("draw_contour");
}

function pick_face() {
	callRuby("pick_face");
}

function specify_height() {
	callRuby("specify_height");
}

function ctrl_onchange(evt){
	act_name="obtain_setting"+ delimiter + this.id + delimiter + this.value.replace(delimiter, ".").replace("'", "*");
	callRuby(act_name);
	if (this.id == "floor_material") {
		var sel_ind=this.selectedIndex;
		var picker_btn = document.getElementById("floor_eye_dropper");
		var col = materials_arr[sel_ind-1].split("|")[1];
		picker_btn.style.backgroundColor = "rgb(" + col + ")";
	}
	if (this.id == "ceiling_material") {
		var sel_ind=this.selectedIndex;
		var picker_btn = document.getElementById("ceiling_eye_dropper");
		var col = materials_arr[sel_ind-1].split("|")[1];
		picker_btn.style.backgroundColor = "rgb(" + col + ")";
	}
	if (this.id == "wall_material") {
		var sel_ind=this.selectedIndex;
		var picker_btn = document.getElementById("wall_eye_dropper");
		var col = materials_arr[sel_ind-1].split("|")[1];
		picker_btn.style.backgroundColor = "rgb(" + col + ")";
	}
}

function click_standard_btn(btn) {
	act_name="cmd_btn" + delimiter + btn.id;
	callRuby(act_name);
}

function populate_selector(selector_id, values_arr, default_value){
	sel=document.getElementById(selector_id);
	while (sel.hasChildNodes()) {
        sel.removeChild(sel.firstChild);
    }
	// var first_option = document.createElement("OPTION");
	// first_option.innerHTML="";
	// first_option.value="";
	// sel.appendChild(first_option);
	for (i=0; i<values_arr.length; i++){
		var field_name=values_arr[i];
		var option = document.createElement("OPTION");
		option.innerHTML=field_name;
		option.value=field_name
		sel.appendChild(option);
	}
	if (default_value!="" || default_value!=null){
		sel.value=default_value;
	}
	// Visual refresh in order to restore an original element width
	sel.style.display="none";
	sel.style.display="";
}

function edit_preset(selector_id){
	var selector=document.getElementById(selector_id);
	var preset_name=selector.value;
	act_name = "edit_preset" + delimiter + preset_name;
	callRuby(act_name);
}

function add_preset(){
	act_name="add_preset"
	callRuby(act_name);
	callRuby("get_settings");
	apply_defaults();
	custom_init();
}

function delete_preset(selector_id){
	var selector=document.getElementById(selector_id);
	var preset_name=selector.value;
	act_name = "delete_preset" + delimiter + preset_name;
	callRuby(act_name);
	callRuby("get_settings");
	apply_defaults();
	custom_init();
}

function return_current_preset(selector_id){
	var preset_selector=document.getElementById(selector_id);
	var preset_name="";
	if (preset_selector.value!=null){
		preset_name=preset_selector.value;
	}
	action_name="select_preset" + delimiter + preset_name;
	callRuby(action_name);
}

function get_preset(preset_name){
	presets_arr.push(preset_name);
}

function clear_presets(){
	presets_arr =  new Array ();
}

function preset_change(preset_selector){
	var preset_name="";
	if (preset_selector.value!=null){
		preset_name=preset_selector.value;
	}
	action_name="select_preset" + delimiter + preset_name;
	callRuby(action_name);
	custom_init();
}

function cancel_changes(){
	callRuby("cancel");
}

function opening_tbody_display(display_str){
	var opening_tbody=document.getElementById("opening_tbody");
	opening_tbody.style.display=display_str;
}

function cut_opening(){
	callRuby("cut_opening");
}

function simple_btn_over(evt){
	this.className="simple_btn_over";
}

function simple_btn_out(evt){
	this.className="simple_btn";
}

function close_btn_over(evt){
	this.className="close_btn_over";
}

function close_btn_out(evt){
	this.className="close_btn";
}

function zone_type_view(zone_type){
	var height_row=document.getElementById("height_row");
	var volume_row=document.getElementById("volume_row");
	var floor_level_row=document.getElementById("floor_level_row");
	var floor_number_row=document.getElementById("floor_number_row");
	var floors_count_row=document.getElementById("floors_count_row");
	var floor_mat_row=document.getElementById("floor_mat_row");
	var ceiling_mat_row=document.getElementById("ceiling_mat_row");
	var wall_mat_row=document.getElementById("wall_mat_row");
	var floor_refno_row=document.getElementById("floor_refno_row");
	var ceiling_refno_row=document.getElementById("ceiling_refno_row");
	var wall_refno_row=document.getElementById("wall_refno_row");
	switch(zone_type)
	{
		case "room":
			// Display room related rows
			height_row.style.display="";
			volume_row.style.display="";
			floor_level_row.style.display="";
			floor_number_row.style.display="";
			floor_mat_row.style.display="";
			ceiling_mat_row.style.display="";
			wall_mat_row.style.display="";
			floor_refno_row.style.display="";
			ceiling_refno_row.style.display="";
			wall_refno_row.style.display="";
			// Hide non-related rows
			floors_count_row.style.display="none";
			break;
		case "box":
			// Display building box related rows
			floors_count_row.style.display="";
			height_row.style.display="";
			volume_row.style.display="";
			// Hide non-related rows
			floor_level_row.style.display="none";
			floor_number_row.style.display="none";
			floor_mat_row.style.display="none";
			ceiling_mat_row.style.display="none";
			wall_mat_row.style.display="none";
			floor_refno_row.style.display="none";
			ceiling_refno_row.style.display="none";
			wall_refno_row.style.display="none";
			break;
		case "flat":
			// Display flat zone related rows
			
			// Hide non-related rows
			height_row.style.display="none";
			volume_row.style.display="none";
			floor_level_row.style.display="none";
			floor_number_row.style.display="none";
			floor_mat_row.style.display="none";
			ceiling_mat_row.style.display="none";
			wall_mat_row.style.display="none";
			floor_refno_row.style.display="none";
			ceiling_refno_row.style.display="none";
			wall_refno_row.style.display="none";
			floors_count_row.style.display="none";
			break;
		default:
		
	}
}

function close_dial(){
	callRuby("close_dial");
}