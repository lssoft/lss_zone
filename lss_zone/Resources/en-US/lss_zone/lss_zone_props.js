var dicts = new Array ();
var props = new Array ();
var dict_no = 1;
var attr_no = 1;

function refresh_data(){
	callRuby("refresh_data");
	callRuby("get_materials");
	callRuby("get_zones_cnt");
	callRuby("get_settings");
	apply_defaults();
}

function get_zones_cnt(cnt_str){
	var cnt_arr=cnt_str.split(",");
	var room_cnt=0;
	var box_cnt=0;
	var flat_cnt=0;
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
			default:
				break;
		}
	}
	var cnt_div=document.getElementById("zones_count");
	cnt_div.innerHTML="";
	var basic_props_container=document.getElementById("basic_props_container");
	var btm_tbl=document.getElementById("bottom_tbl");
	var apply_btn=document.getElementById("apply_btn");
	var reset_btn=document.getElementById("reset_btn");
	if (room_cnt==0 && box_cnt==0 && flat_cnt==0){
		basic_props_container.style.display="none";
		cnt_div.innerHTML="Zero";
		var props_list_content_field=document.getElementById("props_list_content");
		var view_type=props_list_content_field.value;
		if (view_type=="zone_only") {
			apply_btn.disabled=true;
			reset_btn.disabled=true;
		}
		else {
			apply_btn.disabled=false;
			reset_btn.disabled=false;
		}
	}
	else {
		basic_props_container.style.display="";
		apply_btn.disabled=false;
		reset_btn.disabled=false;
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
		
		// Read roll groups statuses (folded/unfolded). Added in ver. 1.2.1 06-Dec-13.
		var trace_cont_grp_btn=document.getElementById("fld_unfld|trace_cont_group");
		var geom_grp_btn=document.getElementById("fld_unfld|geom_group");
		var mat_grp_btn=document.getElementById("fld_unfld|mat_group");
		var trace_cont_st=trace_cont_grp_btn.innerHTML;
		var mat_st=mat_grp_btn.innerHTML;
		var geom_st=geom_grp_btn.innerHTML;
		
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
		var floor_area_row=document.getElementById("floor_area_row");
		var ceiling_area_row=document.getElementById("ceiling_area_row");
		var wall_area_row=document.getElementById("wall_area_row");
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
		floor_area_row.style.display="none";
		ceiling_area_row.style.display="none";
		wall_area_row.style.display="none";
		if (room_cnt!=0) {
			// Display room related rows
			if (geom_st!="+"){
				height_row.style.display="";
				volume_row.style.display="";
				floor_level_row.style.display="";
				floor_number_row.style.display="";
			};
			if (mat_st!="+"){
				floor_mat_row.style.display="";
				ceiling_mat_row.style.display="";
				wall_mat_row.style.display="";
				floor_refno_row.style.display="";
				ceiling_refno_row.style.display="";
				wall_refno_row.style.display="";
				floor_area_row.style.display="";
				ceiling_area_row.style.display="";
				wall_area_row.style.display="";
			};
		}
		if (box_cnt!=0) {
			// Display building box related rows
			if (geom_st!="+"){
				floors_count_row.style.display="";
				height_row.style.display="";
				volume_row.style.display="";
			}
		}
		if (flat_cnt!=0) {
			// Display flat zone related rows
			
		}
	}
	adjust_dial_height();
}

function custom_init(){
	callRuby("get_zones_cnt");
	for (i=0; i<settings_arr.length; i++) {
		if (settings_arr[i][0]=="props_list_content"){
			var view_type=settings_arr[i][1];
			if (view_type=="all"){
				var all_radio=document.getElementById("all");
				radio_click(all_radio);
			}
			else {
				var zone_only_radio=document.getElementById("zone_only");
				radio_click(zone_only_radio);
				// Roll states added in ver. 1.2.1 05-Dec-13.
				var act_name="get_roll_states";
				callRuby(act_name);
			}
		}
	}
}

function switch_content_view(view_type){
	var basic_props_container=document.getElementById("basic_props_container");
	var all_props_container=document.getElementById("all_props_container");
	var zones_count_row=document.getElementById("zones_count_row");
	var btm_tbl=document.getElementById("bottom_tbl");
	if (view_type=="all"){
		all_props_container.style.display="";
		basic_props_container.style.display="none";
	}
	else
	{
		all_props_container.style.display="none";
		basic_props_container.style.display="";
		callRuby("get_zones_cnt");
	}
}

function clear_dicts(){
	dicts = new Array ();
	props = new Array ();
}

function add_prop(prop_str){
	props.push(prop_str);
}

function add_dict(dict_name){
	dicts.push(dict_name);
}

function list_all_props(){
	var all_props_container=document.getElementById("all_props_container");
	all_props_container.innerHTML="";
	for (i=0; i<dicts.length; i++){
		var dict_name=dicts[i];
		// Initialize table for attributes list
		var props_list_table=document.createElement("TABLE");
		props_list_table.id="table"+delimiter+dict_name;
		props_list_table.style.tableLayout="fixed";
		props_list_table.style.width="100%";
		// Add properties list tbody
		var props_tbody = document.createElement("TBODY");
		props_tbody.style.width="100%";
		props_tbody.id="tbody"+delimiter+dict_name;
		props_list_table.appendChild(props_tbody);
		// Add header line with attribute dictionary name and buttons
		var hdr_line=document.createElement("TR");
		var hdr_cell=document.createElement("TH");
		hdr_cell.className="header1";
		hdr_cell.colSpan="2";
		hdr_cell.style.whiteSpase="nowrap";
		var erase_dict_btn=document.createElement("DIV");
		erase_dict_btn.innerHTML="[X]";
		erase_dict_btn.id="erase_dict"+delimiter+dict_name;
		erase_dict_btn.title="Erase this attribute dictionary";
		erase_dict_btn.onclick=erase_dict;
		erase_dict_btn.onmouseover=close_btn_over;
		erase_dict_btn.onmouseout=close_btn_out;
		erase_dict_btn.className="close_btn";
		hdr_cell.appendChild(erase_dict_btn);
		var fold_unfold_btn=document.createElement("DIV");
		fold_unfold_btn.innerHTML="-";
		fold_unfold_btn.id="fold_unfold"+delimiter+dict_name;
		fold_unfold_btn.title="Click to unfold properties list";
		fold_unfold_btn.onclick=fold_unfold;
		fold_unfold_btn.className="dock_left";
		fold_unfold_btn.style.cursor="hand";
		hdr_cell.appendChild(fold_unfold_btn);
		var dict_div = document.createElement("DIV");
		dict_div.className="props_hdr";
		dict_div.title=dict_name;
		dict_div.innerHTML=dict_name;
		hdr_cell.appendChild(dict_div);
		hdr_line.appendChild(hdr_cell);
		props_tbody.appendChild(hdr_line);
		// Populate with propeties
		for (j=0; j<props.length; j++){
			var prop_str=props[j];
			var prop_arr=prop_str.split("|");
			var prop_dict_name=prop_arr[0];
			if (prop_dict_name==dict_name){
				var prop_name=prop_arr[1];
				var prop_val=prop_arr[2];
				var field_id = dict_name + delimiter + prop_name;
				prop_line = document.createElement("TR");
				prop_line.id="prop_line"+delimiter+field_id;
				props_tbody.appendChild(prop_line);
				name_cell = document.createElement("TD");
				name_cell.width="50%";
				var name_div = document.createElement("DIV");
				name_div.style.whiteSpace="nowrap";
				name_div.style.textOverflow="ellipsis";
				name_div.style.minWidth="0";
				name_div.style.overflow="hidden";
				name_div.style.display="inline-block";
				name_div.style.width="100%";
				name_div.style.maxWidth="100%";
				name_div.innerHTML = prop_name;
				name_div.title = prop_name;
				name_div.id="name"+delimiter+field_id;
				name_cell.appendChild(name_div);
				prop_line.appendChild(name_cell);
				val_cell = document.createElement("TD");
				val_div=document.createElement("DIV");
				val_div.style.whiteSpace="nowrap";
				val_div.style.display="inline-block";
				val_div.style.width="100%";
				val_div.style.maxWidth="100%";
				val_div.id="val"+delimiter+field_id;
				// Create erase attribute from dictionary button
				var erase_attr_btn=document.createElement("DIV");
				erase_attr_btn.style.cursor="hand";
				erase_attr_btn.innerHTML="x";
				erase_attr_btn.id="erase_attr"+delimiter+field_id;
				erase_attr_btn.title="Erase this attribute attrionary";
				erase_attr_btn.onclick=erase_attr;
				erase_attr_btn.onmouseover=close_btn_over;
				erase_attr_btn.onmouseout=close_btn_out;
				erase_attr_btn.className="close_btn";
				val_div.appendChild(erase_attr_btn);
				//Create an input type dynamically.
				var val_input = document.createElement("input");
				//Assign different attributes to the element.
				val_input.setAttribute("type", "text");
				val_input.value=prop_val;
				val_input.id=field_id;
				val_input.style.width="100%";
				val_input.title=prop_name;
				val_input.onchange=prop_onchange;
				val_input.onkeydown=key_dwn_prop;
				val_div.appendChild(val_input);
				val_cell.appendChild(val_div);
				prop_line.appendChild(val_cell);
			}
		}
		add_new_attr_btn(props_tbody);
		all_props_container.appendChild(props_list_table);
	}
	add_dict_div_btn(all_props_container);
}

function fold_unfold(evt){
	var dict_name=this.id.split(delimiter)[1];
	var props_tbody=document.getElementById("tbody"+delimiter+dict_name);
	var init_delay=60;
	if (this.innerHTML=="-") {
		// Collapse properties list
		this.innerHTML="+";
		var nodes = props_tbody.childNodes;
		var i = 0;
		delay=60;
		function hide_nodes () {
			setTimeout(function () {
				var node=nodes[i];
				if (node.id.indexOf("prop_line")!=-1 || node.id.indexOf("add_attr_line")!=-1){
					node.style.display="none";
				}
				i++;
				if (i < nodes.length) {
					hide_nodes();
				}
				delay=parseInt(init_delay/(i*i/nodes.length+1));
			}, delay);
			adjust_dial_height();
		}
		hide_nodes();   
	}
	else {
		// Unfold properties list
		this.innerHTML="-";
		var nodes = props_tbody.childNodes;
		var i = nodes.length-1;
		delay=60;
		function show_nodes () {
			setTimeout(function () {
				var node=nodes[i];
				if (node.id.indexOf("prop_line")!=-1 || node.id.indexOf("add_attr_line")!=-1){
					node.style.display="";
				}
				i-=1;
				if (i >=0) {
					show_nodes();
				}
				delay=parseInt(init_delay/(i*i/nodes.length+1));
			}, delay);
			adjust_dial_height();
		}
		show_nodes();   
	}
}

function prop_onchange(evt){
	act_name="obtain_prop" + delimiter + this.id + delimiter + this.value.replace(delimiter, ".").replace("'", "*");
	this.style.fontWeight="bold";
	this.style.color="red";
	var name_div=document.getElementById("name"+delimiter+this.id);
	name_div.style.fontWeight="bold";
	var val_div=document.getElementById("val"+delimiter+this.id);
	// Refresh value div in order to properly display erase attribute button
	val_div.style.display="none";
	val_div.style.display="";
	callRuby(act_name);
}

function key_dwn_prop(evt) {
	if (event.keyCode==13) {
		act_name="obtain_prop" + delimiter + this.id + delimiter + this.value.replace(delimiter, ".").replace("'", "*");
		this.style.fontWeight="bold";
		this.style.color="red";
		var name_div=document.getElementById("name"+delimiter+this.id);
		name_div.style.fontWeight="bold";
		callRuby(act_name);
		return false;
	}
}

function erase_dict(evt){
	var dict_name=this.id.split(delimiter)[1];
	var dict_table=document.getElementById("table"+delimiter+dict_name);
	dict_table.className="deleted";
	act_name=this.id;
	callRuby(act_name);
}

function erase_attr(evt){
	var dict_name=this.id.split(delimiter)[1];
	var attr_name=this.id.split(delimiter)[2];
	var field_id=dict_name+delimiter+attr_name;
	var prop_line=document.getElementById("prop_line"+delimiter+field_id);
	// prop_line.className="deleted";
	var name_div=document.getElementById("name"+delimiter+field_id);
	var val_div=document.getElementById("val"+delimiter+field_id);
	name_div.className="deleted";
	val_div.className="deleted";
	act_name=this.id;
	callRuby(act_name);
}

function add_new_dict(evt){
	var all_props_container=document.getElementById("all_props_container");
	var dict_name="new_dict_" + dict_no;
	while (document.getElementById("table"+delimiter+dict_name))
	{
		dict_no+=1;
		dict_name="new_dict_" + dict_no;
	}
	dict_no+=1;
	// Initialize table for attributes list
	var props_list_table=document.createElement("TABLE");
	props_list_table.id="table"+delimiter+dict_name;
	props_list_table.style.tableLayout="fixed";
	props_list_table.style.width="100%";
	// Add properties list tbody
	var props_tbody = document.createElement("TBODY");
	props_tbody.style.width="100%";
	props_tbody.id="tbody"+delimiter+dict_name;
	props_list_table.appendChild(props_tbody);
	// Add header line with attribute dictionary name and buttons
	var hdr_line=document.createElement("TR");
	var hdr_cell=document.createElement("TH");
	hdr_cell.className="header1";
	hdr_cell.colSpan="2";
	hdr_cell.style.whiteSpase="nowrap";
	var erase_dict_btn=document.createElement("DIV");
	erase_dict_btn.innerHTML="[X]";
	erase_dict_btn.id="erase_dict"+delimiter+dict_name;
	erase_dict_btn.title="Erase this attribute dictionary";
	erase_dict_btn.onclick=erase_dict;
	erase_dict_btn.onmouseover=close_btn_over;
	erase_dict_btn.onmouseout=close_btn_out;
	erase_dict_btn.className="close_btn";
	hdr_cell.appendChild(erase_dict_btn);
	var fold_unfold_btn=document.createElement("DIV");
	fold_unfold_btn.innerHTML="-";
	fold_unfold_btn.id="fold_unfold"+delimiter+dict_name;
	fold_unfold_btn.title="Click to unfold properties list";
	fold_unfold_btn.onclick=fold_unfold;
	fold_unfold_btn.className="dock_left";
	fold_unfold_btn.style.cursor="hand";
	hdr_cell.appendChild(fold_unfold_btn);
	var dict_div = document.createElement("DIV");
	dict_div.className="props_hdr";
	var dict_name_input = document.createElement("input");
	dict_name_input.setAttribute("type", "text");
	dict_name_input.value=dict_name;
	dict_name_input.id="new_dict"+delimiter+dict_name;
	dict_name_input.style.width="100%";
	dict_name_input.title="Enter name of new dictionary";
	dict_name_input.onchange=dict_name_onchange;
	dict_name_input.onkeydown=key_dwn_dict_name;
	dict_div.appendChild(dict_name_input);
	hdr_cell.appendChild(dict_div);
	hdr_line.appendChild(hdr_cell);
	props_tbody.appendChild(hdr_line);
	add_new_attr_btn(props_tbody);
	props_list_table.appendChild(props_tbody);
	all_props_container.appendChild(props_list_table);
	// Add new dictionary button (just to place it at the bottom of the table)
	var btn=document.getElementById("add_dict_div_btn");
	all_props_container.removeChild(btn);
	add_dict_div_btn(all_props_container);
	// Inform ruby about new dictionary creation
	act_name="add_new_dict"+delimiter+dict_name;
	callRuby(act_name);
}

function dict_name_onchange(evt){
	var dict_name=this.id.split(delimiter)[1];
	act_name="dict_name_change" + delimiter + dict_name + delimiter + this.value;
	callRuby(act_name);
}

function key_dwn_dict_name(evt){
	if (event.keyCode==13) {
		var dict_name=this.id.split(delimiter)[1];
		act_name="dict_name_change" + delimiter + dict_name;
		callRuby(act_name);
		return false;
	}
}

function add_dict_div_btn(all_props_container){
	var add_dict_div=document.createElement("DIV");
	add_dict_div.innerHTML="Add Dictionary";
	add_dict_div.style.whiteSpace="nowrap";
	add_dict_div.style.textOverflow="ellipsis";
	add_dict_div.style.overflow="hidden";
	add_dict_div.style.display="inline-block";
	add_dict_div.style.width="100%";
	add_dict_div.style.maxWidth="100%";
	add_dict_div.title = "Add new attribute dictionary";
	add_dict_div.style.cursor="hand";
	add_dict_div.onclick=add_new_dict;
	add_dict_div.id="add_dict_div_btn";
	add_dict_div.onmouseover=simple_btn_over;
	add_dict_div.onmouseout=simple_btn_out;
	add_dict_div.className="simple_btn";
	all_props_container.appendChild(add_dict_div);
}

function add_new_attr_btn(props_tbody){
	var dict_name=props_tbody.id.split(delimiter)[1];
	add_attr_line = document.createElement("TR");
	add_attr_line.id="add_attr_line"+delimiter+dict_name;
	props_tbody.appendChild(add_attr_line);
	add_attr_cell = document.createElement("TD");
	add_attr_cell.width="100%";
	var add_attr_div = document.createElement("DIV");
	add_attr_div.style.whiteSpace="nowrap";
	add_attr_div.style.textOverflow="ellipsis";
	add_attr_div.style.overflow="hidden";
	add_attr_div.style.display="inline-block";
	add_attr_div.style.width="100%";
	add_attr_div.style.maxWidth="100%";
	add_attr_div.innerHTML = "Add Attribute";
	add_attr_div.title = "Add new attribute (property) to a dictionary";
	add_attr_div.id="add_attr"+delimiter+dict_name;
	add_attr_div.style.cursor="hand";
	add_attr_div.onclick=add_new_attr;
	add_attr_div.onmouseover=simple_btn_over;
	add_attr_div.onmouseout=simple_btn_out;
	add_attr_div.className="simple_btn";
	add_attr_cell.colSpan="2";
	add_attr_cell.appendChild(add_attr_div);
	add_attr_line.appendChild(add_attr_cell);
}

function add_new_attr(evt){
	var dict_name=this.id.split(delimiter)[1];
	var dict_table=document.getElementById("table"+delimiter+dict_name);
	if (dict_table.className=="deleted"){
		return;
	}
	var props_tbody=document.getElementById("tbody"+delimiter+dict_name);
	var prop_name="new_attr"+attr_no;
	var field_id = dict_name + delimiter + prop_name;
	while (document.getElementById(field_id))
	{
		attr_no+=1;
		prop_name="new_attr"+attr_no;
		field_id = dict_name + delimiter + prop_name;
	}
	attr_no+=1;
	var prop_val="";
	prop_line = document.createElement("TR");
	prop_line.id="prop_line"+delimiter+field_id;
	props_tbody.appendChild(prop_line);
	name_cell = document.createElement("TD");
	name_cell.width="50%";
	var name_div = document.createElement("DIV");
	name_div.style.whiteSpace="nowrap";
	name_div.style.textOverflow="ellipsis";
	name_div.style.minWidth="0";
	name_div.style.overflow="hidden";
	name_div.style.display="inline-block";
	name_div.style.width="100%";
	name_div.style.maxWidth="100%";
	name_div.title = "Enter name of new attribute";
	name_div.id="name"+delimiter+field_id;
	name_field=document.createElement("input");
	name_field.setAttribute("type", "text");
	name_field.value=prop_name;
	name_field.id="name_field"+delimiter+field_id;
	name_field.style.width="100%";
	name_field.onchange=attr_name_onchange;
	name_field.onkeydown=key_dwn_attr_name;
	name_div.appendChild(name_field);
	name_cell.appendChild(name_div);
	prop_line.appendChild(name_cell);
	val_cell = document.createElement("TD");
	val_div=document.createElement("DIV");
	val_div.style.whiteSpace="nowrap";
	val_div.style.display="inline-block";
	val_div.style.width="100%";
	val_div.style.maxWidth="100%";
	val_div.id="val"+delimiter+field_id;
	// Create erase attribute from dictionary button
	var erase_attr_btn=document.createElement("DIV");
	erase_attr_btn.style.cursor="hand";
	erase_attr_btn.innerHTML="x";
	erase_attr_btn.id="erase_attr"+delimiter+field_id;
	erase_attr_btn.title="Erase this attribute attrionary";
	erase_attr_btn.onclick=erase_attr;
	erase_attr_btn.onmouseover=close_btn_over;
	erase_attr_btn.onmouseout=close_btn_out;
	erase_attr_btn.className="close_btn";
	val_div.appendChild(erase_attr_btn);
	//Create an input type dynamically.
	var val_input = document.createElement("input");
	//Assign different attributes to the element.
	val_input.setAttribute("type", "text");
	val_input.value=prop_val;
	val_input.id=field_id;
	val_input.style.width="100%";
	val_input.title=prop_name;
	val_input.onchange=prop_onchange;
	val_input.onkeydown=key_dwn_prop;
	val_div.appendChild(val_input);
	val_cell.appendChild(val_div);
	prop_line.appendChild(val_cell);
	
	var btn=document.getElementById("add_attr_line"+delimiter+dict_name);
	props_tbody.removeChild(btn);
	add_new_attr_btn(props_tbody);
	
	act_name="add_new_attr" + delimiter + field_id;
	callRuby(act_name);
}

function change_attr_name(id, value){
	var dict_name=id.split(delimiter)[1];
	var attr_name=id.split(delimiter)[2];
	var field_id=dict_name + delimiter + attr_name;
	var prop_val_field=document.getElementById(field_id);
	var prop_val=prop_val_field.value;
	act_name="change_attr_name" + delimiter + dict_name + delimiter + attr_name + delimiter + value + delimiter + prop_val;
	callRuby(act_name);
	// Change ids
	var new_field_id=dict_name + delimiter + value;
	var prop_line=document.getElementById("prop_line"+delimiter+field_id);
	var name_div=document.getElementById("name"+delimiter+field_id);
	var erase_attr_btn=document.getElementById("erase_attr"+delimiter+field_id);
	var val_input=document.getElementById(field_id);
	var val_div=document.getElementById("val"+delimiter+field_id);
	prop_line.id="prop_line"+delimiter+new_field_id;
	name_div.id="name"+delimiter+new_field_id;
	erase_attr_btn.id="erase_attr"+delimiter+new_field_id;
	val_input.id=new_field_id;
	val_div.id="val"+delimiter+new_field_id
}

function attr_name_onchange(evt){
	change_attr_name(this.id, this.value);
}

function key_dwn_attr_name(evt){
	if (event.keyCode==13) {
		change_attr_name(this.id, this.value);
		return false;
	}
}