﻿function condition_change(chk_box){
	var cond_name=chk_box.id.replace("use_","");
	var cond_value=chk_box.checked;
	var act_name="condition_change"+delimiter+cond_name+delimiter+cond_value;
	callRuby(act_name);
}

function refresh_data(){
	callRuby("refresh_data");
	callRuby("get_materials");
	callRuby("get_zones_cnt");
	callRuby("get_settings");
	// apply_defaults();
}

function get_zones_cnt(cnt_str){
	var cnt_arr=cnt_str.split(",");
	var room_cnt=0;
	var box_cnt=0;
	var flat_cnt=0;
	var cnt_type="";
	for (i=0; i<cnt_arr.length; i++){
		var cnt_pair=cnt_arr[i].split("=");
		switch(cnt_pair[0])
		{
			case "room":
				room_cnt=parseInt(cnt_pair[1]);
				break;
			case "box":
				box_cnt=parseInt(cnt_pair[1]);
				break;
			case "flat":
				flat_cnt=parseInt(cnt_pair[1]);
				break;
			case "cnt_type":
				cnt_type=cnt_pair[1];
				break;
			default:
				break;
		}
	}
	var cnt_div=document.getElementById(cnt_type+"_zones_count");
	cnt_div.innerHTML="";
	var filter_tbody=document.getElementById("filter_tbody");
	var btm_tbl=document.getElementById("bottom_tbl");
	if (room_cnt==0 && box_cnt==0 && flat_cnt==0){
		if (cnt_type=="total"){
			filter_tbody.style.display="none";
		}
		cnt_div.innerHTML="Zero";
	}
	else {
		filter_tbody.style.display="";
		btm_tbl.style.display="";
		if (room_cnt!=0) {
			room_img=document.createElement("IMG");
			room_img.src="images/room.gif"
			room_img.className="dock_left";
			room_img.title="'Room' zone type";
			cnt_div.appendChild(room_img);
			room_cnt_div=document.createElement("DIV");
			room_cnt_div.innerHTML=room_cnt;
			room_cnt_div.className="dock_left";
			room_cnt_div.title="'Room' zones count";
			cnt_div.appendChild(room_cnt_div);
		}
		if (box_cnt!=0) {
			box_img=document.createElement("IMG");
			box_img.src="images/box.gif"
			box_img.className="dock_left";
			box_img.title="'Box' zone type";
			cnt_div.appendChild(box_img);
			box_cnt_div=document.createElement("DIV");
			box_cnt_div.innerHTML=box_cnt;
			box_cnt_div.className="dock_left";
			box_cnt_div.title="'Box' zones count";
			cnt_div.appendChild(box_cnt_div);
		}
		if (flat_cnt!=0) {
			flat_img=document.createElement("IMG");
			flat_img.src="images/flat.gif"
			flat_img.className="dock_left";
			flat_img.title="'Flat' zone type";
			cnt_div.appendChild(flat_img);
			flat_cnt_div=document.createElement("DIV");
			flat_cnt_div.innerHTML=flat_cnt;
			flat_cnt_div.className="dock_left";
			flat_cnt_div.title="'Flat' zones count";
			cnt_div.appendChild(flat_cnt_div);
		}
		// Adjust display of properties according to selected zone types
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
		// Hide all adjustable properties
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
		if (room_cnt!=0) {
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
		}
		if (box_cnt!=0) {
			// Display building box related rows
			floors_count_row.style.display="";
			height_row.style.display="";
			volume_row.style.display="";
		}
		if (flat_cnt!=0) {
			// Display flat zone related rows
			
		}
	}
}

function send_condition(cond_field){
	var chk_box_id="use_"+cond_field.id;
	var chk_box=document.getElementById(chk_box_id);
	chk_box.checked=true;
	act_name="obtain_setting"+ delimiter+ cond_field.id+ delimiter + cond_field.value.replace(delimiter, ".").replace("'", "*");
	callRuby(act_name);
	condition_change(chk_box);
}

function cond_key_up(field) {
	if (event.keyCode==13) {
		send_condition(field);
		return false;
	}
}

function custom_init(){
	callRuby("get_zones_cnt");
}