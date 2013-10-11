var delimiter=",";
var key_val_hash = {};
var records_arr = new Array ();
var fields_arr = new Array ();
var suggest_fields_arr = new Array ();
var name_aliases = {};
var charts_arr = new Array ();
var chart_no=0;

function get_key_val(key_val_str){
	key_val=key_val_str.split("|");
	key_val_hash[key_val[0]]=key_val[1];
}

function clear_key_val(){
	key_val_hash = {};
}

function add_record(){
	records_arr.push(key_val_hash);
}

function clear_records(){
	records_arr =  new Array ();
}

function clear_name_aliases(){
	name_aliases={};
}

function clear_charts (){
	charts_arr = new Array ();
}

function get_chart(chart_str){
	var chart_settings=chart_str.split(",");
	var chart_name=chart_settings[0];
	var data_field=chart_settings[1];
	var legend_field=chart_settings[2];
	var chart_hash={};
	chart_hash["chart_name"]=chart_name;
	chart_hash["data_field"]=data_field;
	chart_hash["legend_field"]=legend_field;
	charts_arr.push(chart_hash);
}

function get_name_alias(name_alias_str){
	var key_val=name_alias_str.split("|");
	name_aliases[key_val[0]]=key_val[1];
}

function send_query_string(txt_box){
	var query_string=escape(txt_box.value);
	var act_name="query_string" + delimiter + query_string;
	callRuby(act_name);
	callRuby("get_fields");
	populate_selectors();
	callRuby("get_settings");
	callRuby("get_zones_data");
	build_table();
}

function query_str_key_up(txt_box){
	// if (event.keyCode==32) {
		send_query_string(txt_box);
	// }
}

function custom_init(){
	callRuby("get_fields");
	callRuby("get_suggest_fields");
	var query_string_txt_box=document.getElementById("query_string");
	var obj = new autosuggest("query_string", suggest_fields_arr, null, send_query_string(query_string_txt_box));
	obj.text_delimiter=[",", ";", " ", "\n"];
	obj.response_time=10;
	populate_selectors();
	callRuby("get_settings");
	apply_defaults(); //again in order to set appropriate values for selectors
	callRuby("get_zones_data");
	callRuby("get_name_aliases");
	callRuby("get_charts");
	build_table();
	draw_charts();
}

function populate_selectors(){
	populate_selector("group_by");
	populate_selector("sort_by");
}

function populate_selector(selector_id){
	sel=document.getElementById(selector_id);
	while (sel.hasChildNodes()) {
        sel.removeChild(sel.firstChild);
    }
	var first_option = document.createElement("OPTION");
	first_option.innerHTML="";
	first_option.value="";
	sel.appendChild(first_option);
	for (i=0; i<fields_arr.length; i++){
		var field_name=fields_arr[i];
		var option = document.createElement("OPTION");
		option.innerHTML=field_name;
		option.value=field_name
		sel.appendChild(option);
	}
	// Visual refresh in order to restore an original element width
	sel.style.display="none";
	sel.style.display="";
}

function clear_fields(){
	fields_arr = new Array ();
}

function get_field_name(field_name){
	fields_arr.push(field_name);
}

function clear_suggest_fields(){
	suggest_fields_arr = new Array ();
}

function get_suggest_field_name(field_name){
	suggest_fields_arr.push(field_name);
}

function build_table(){
	var table_container=document.getElementById("table_container");
	table_container.innerHTML="";
	var oTable = document.createElement("TABLE");
	var oTBody = document.createElement("TBODY");
	var oCaption = document.createElement("CAPTION");
	var oRow, oCell;
	
	oTable.appendChild(oTBody);
	oTable.style.width="100%";
	oTable.className="data_grid_table";
	oCaption.innerHTML="Zones List";
	oTable.appendChild(oCaption);
	
	oRow = document.createElement("TR");
	oTBody.appendChild(oRow);
	var sort_by=document.getElementById("sort_by").value;
	var sort_dir=document.getElementById("sort_dir").value;
	for (i=0; i<fields_arr.length; i++){
		var col_name=fields_arr[i];
		var oHead = document.createElement("TH");
		oHead.innerHTML=col_name;
		oRow.appendChild(oHead);
		if (col_name==sort_by){
			if (sort_dir=="ascending"){
				oHead.className="sort_by_asc";
			}
			else {
				oHead.className="sort_by_dec";
			}
		}
		else {
			oHead.className="data_grid_col_head";
		}
		oHead.onclick=sort_by_this_col;
		oHead.id=col_name;
	}
	
	// Name aliases row
	var oRow = document.createElement("TR");
	oTBody.appendChild(oRow);
	for (i=0; i<fields_arr.length; i++){
		var col_name=fields_arr[i];
		var alias_name=name_aliases[col_name];
		oCell = document.createElement("TD");
		var name_alias_field=document.createElement("INPUT");
		if (alias_name){
			name_alias_field.value=alias_name;
		}
		name_alias_field.id=col_name;
		name_alias_field.onchange=send_name_alias;
		name_alias_field.onkeydown=name_alias_key_dwn;
		oCell.appendChild(name_alias_field);
		oCell.className="data_grid_cell";
		oRow.appendChild(oCell);
	}
	
	function send_name_alias(event){
		var act_name="obtain_name_alias"+ delimiter+ this.id + delimiter + this.value;
		callRuby(act_name);
	}
	
	function name_alias_key_dwn(field){
		if (event.keyCode==13) {
			var act_name="obtain_name_alias"+ delimiter+ this.id + delimiter + this.value;
			callRuby(act_name);
			return false;
		}
	}
	
	for (i=0; i<records_arr.length; i++){
		oRow = document.createElement("TR");
		oTBody.appendChild(oRow);
		record=records_arr[i];
		for(var key in record) {
			if(record.hasOwnProperty(key)){
				oCell = document.createElement("TD");
				oCell.innerHTML=record[key];
				oCell.className="data_grid_cell";
				oRow.appendChild(oCell);
			}
		}
	}
	table_container.appendChild(oTable);
}

function sort_by_this_col(evt){
	var nodes=this.parentNode.childNodes
	for (i=0; i<nodes.length; i++){
		node=nodes[i];
		if (node.id!=this.id){
			node.className="data_grid_col_head";
		}
	}
	if (this.className=="data_grid_col_head"){
		this.className="sort_by_asc";
		actionName="sort_by" + delimiter + this.id;
		callRuby(actionName);
		actionName="sort_dir" + delimiter + "ascending";
		callRuby(actionName);
	}
	else{
		if (this.className=="sort_by_dec"){
			this.className="data_grid_col_head";
			actionName="sort_by" + delimiter + "";
			callRuby(actionName);
			actionName="sort_dir" + delimiter + "ascending";
			callRuby(actionName);
		}
		else{
			this.className="sort_by_dec";
			actionName="sort_by" + delimiter + this.id;
			callRuby(actionName);
			actionName="sort_dir" + delimiter + "descending";
			callRuby(actionName);
		}
	}
	callRuby("get_settings");
	apply_defaults();
	custom_init();
}

function query_condition_change(setting_control){
	if (setting_control.type == 'checkbox') {
		act_name="obtain_setting"+ delimiter+ setting_control.id+ delimiter +setting_control.checked;
	}
	else {
		act_name="obtain_setting"+ delimiter+ setting_control.id+ delimiter +setting_control.value.replace(delimiter, ".").replace("'", "*");
	}
	callRuby(act_name);
	custom_init();
}

function save_template(){
	send_charts();
	callRuby("save_template");
}

function send_charts(){
	var charts_container=document.getElementById("charts_container");
	for (i=0; i<charts_container.children.length; i++) {
		var chart_widget=charts_container.children[i];
		var arr=chart_widget.id.split("_");
		var no_str=arr[arr.length-1];
		// ID's
		var chart_name_id="chart_name_" + no_str;
		var data_id="data_"+no_str;
		var legend_id="legend_"+no_str;
		// Elements
		var chart_name_field=document.getElementById(chart_name_id);
		var data_field=document.getElementById(data_id);
		var legend_field=document.getElementById(legend_id);
		// Values
		var chart_name=chart_name_field.value;
		var data_key=data_field.value;
		var legend_key=legend_field.value;
		act_name="obtain_chart" + delimiter + chart_name + delimiter + data_key + delimiter + legend_key;
		callRuby(act_name);
	}
}

function select_field(event){
	var arr=this.id.split("_");
	var no_str=arr[arr.length-1];
	var data_id="data_"+no_str;
	var legend_id="legend_"+no_str;
	var data_field=document.getElementById(data_id);
	var legend_field=document.getElementById(legend_id);
	var data_key=data_field.value;
	var legend_key=legend_field.value;
	var chart_container_id="chart_container_" + no_str;
	var chart_name_id="chart_name_" + no_str;
	var chart_name_field=document.getElementById(chart_name_id);
	var chart_name=chart_name_field.value;
	generate_chart(chart_container_id, data_key, legend_key);
}

function remove_chart(event){
	var arr=this.id.split("_")
	var no_str=arr[arr.length-1];
	var chart_widget_id="chart_widget_" + no_str;
	var chart_widget=document.getElementById(chart_widget_id);
	var charts_container=document.getElementById("charts_container");
	charts_container.removeChild(chart_widget);
}

function add_new_chart(){
	var no_str=chart_no.toString();
	var chart_name="Chart " + no_str;
	var data_key="";
	var legend_key="";
	add_chart(chart_name, data_key, legend_key, chart_no);
	chart_no+=1;
}

function add_chart(chart_name, data_key, legend_key, n){
	chart_no=n;
	var no_str=chart_no.toString();
	var charts_container=document.getElementById("charts_container");
	var chart_widget=document.createElement("DIV");
	
	chart_widget.id="chart_widget_" + no_str;
	chart_widget.className="chart_widget";
	charts_container.appendChild(chart_widget);
	// Create chart header
	var header_elt=document.createElement("DIV");
	header_elt.id="header_elt_" + no_str;
	header_elt.className="chart_header";
	chart_widget.appendChild(header_elt);
	
	// Create chart name field
	var name_field=document.createElement("INPUT");
	name_field.id="chart_name_" + no_str;
	name_field.className="chart_name";
	name_field.title="Enter chart name";
	name_field.placeholder="Chart Name";
	name_field.value=chart_name;
	header_elt.appendChild(name_field);
	// Create "close" button
	var close_btn=document.createElement("DIV");
	close_btn.id="close_chart_btn_" + no_str;
	close_btn.className="chart_close_btn";
	close_btn.innerHTML="[x]";
	close_btn.title="Remove Chart";
	close_btn.onclick=remove_chart;
	header_elt.appendChild(close_btn);
	
	// Create chart container
	var chart_container=document.createElement("DIV");
	chart_container.id="chart_container_" + no_str;
	chart_container.className="chart_container";
	chart_widget.appendChild(chart_container);
	
	// Create footer element with selectors
	var footer_elt=document.createElement("DIV");
	footer_elt.id="footer_elt_" + no_str;
	footer_elt.className="chart_footer";
	chart_widget.appendChild(footer_elt);
	
	// Create data field selector
	var data_field=document.createElement("SELECT");
	footer_elt.appendChild(data_field);
	data_field.onchange=select_field;
	data_field.id="data_"+no_str;
	for (i=0; i<fields_arr.length; i++) {
		var field_opt=document.createElement("OPTION");
		field_name=fields_arr[i];
		field_opt.value=field_name;
		if (name_aliases[field_name]){
			field_opt.innerHTML=name_aliases[field_name];
		}
		else {
			field_opt.innerHTML=field_name;
		}
		data_field.appendChild(field_opt);
	}
	data_field.value=data_key;
	data_field.className="dock_left";
	data_field.style.width="6em";
	data_field.title="Choose data column";
	
	// Create legend field selector
	var legend_field=document.createElement("SELECT");
	footer_elt.appendChild(legend_field);
	legend_field.onchange=select_field;
	legend_field.id="legend_"+no_str;
	for (i=0; i<fields_arr.length; i++) {
		var field_opt=document.createElement("OPTION");
		field_name=fields_arr[i];
		field_opt.value=field_name;
		if (name_aliases[field_name]){
			field_opt.innerHTML=name_aliases[field_name];
		}
		else {
			field_opt.innerHTML=field_name;
		}
		legend_field.appendChild(field_opt);
	}
	legend_field.value=legend_key;
	legend_field.className="dock_right";
	legend_field.style.width="6em";
	legend_field.title="Choose legend column";
	
	// Generate chart if data not empty
	if (data_key!=""){
		generate_chart(chart_container.id, data_key, legend_key)
	}
	chart_no+=1;
}

function generate_chart(chart_container_id, data_key, legend_key){
	var chart_container=document.getElementById(chart_container_id);
	chart_container.innerHTML="";
	var wdt=chart_container.offsetWidth;
	var hgt=chart_container.offsetHeight;
	r=Math.min(wdt/2, hgt/2);
	r-=10;
	cx=r+10;
	cy=hgt/2;
	var chart_paper = Raphael(chart_container_id, "100%", "100%");
	var data = new Array();
	var legend = new Array();
	for (i=0; i<records_arr.length; i++){
		var record=records_arr[i];
		for(var key in record) {
			if(record.hasOwnProperty(key)){
				if (key==data_key){
					data.push(parseFloat(record[key].replace("~ ","")));
				}
				if (key==legend_key){
					legend.push(record[key]);
				}
			}
		}
	}
	var options = { legend: legend, legendpos: "east", init: true}
	pie_chart=chart_paper.piechart(cx, cy, r, data, options);
}

function draw_charts(){
	var charts_container=document.getElementById("charts_container");
	charts_container.innerHTML="";
	if (charts_arr.length!=0){
		for (j=0; j<charts_arr.length; j++){
			var chart_hash=charts_arr[j];
			var chart_name=chart_hash["chart_name"];
			var data_field=chart_hash["data_field"];
			var legend_field=chart_hash["legend_field"];
			add_chart(chart_name, data_field, legend_field, j);
		}
	}
}