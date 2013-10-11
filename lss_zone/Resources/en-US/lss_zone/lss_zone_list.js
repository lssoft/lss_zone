var delimiter=",";
var fields_arr = new Array ();
var records_arr = new Array ();
var key_val_hash = {};
var name_aliases = {};
var charts_arr = new Array ();

function custom_init(){
	callRuby("get_presets");
	callRuby("get_fields");
	populate_selector("list_name", presets_arr);
	callRuby("get_settings"); //again in order to get current "list_name"
	apply_defaults(); //again in order to set appropriate value for selector
	callRuby("get_zones_data");
	callRuby("get_name_aliases");
	callRuby("get_charts");
	build_table();
	draw_charts();
}

function clear_key_val(){
	key_val_hash = {};
}

function get_key_val(key_val_str){
	key_val=key_val_str.split("|");
	key_val_hash[key_val[0]]=key_val[1];
}

function add_record(){
	records_arr.push(key_val_hash);
}

function clear_records(){
	records_arr =  new Array ();
}

function clear_fields(){
	fields_arr = new Array ();
}

function get_field_name(field_name){
	fields_arr.push(field_name);
}

function clear_name_aliases(){
	name_aliases={};
}

function get_name_alias(name_alias_str){
	var key_val=name_alias_str.split("|");
	name_aliases[key_val[0]]=key_val[1];
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
	oCaption.innerHTML="List Preview";
	oTable.appendChild(oCaption);
	
	oRow = document.createElement("TR");
	oTBody.appendChild(oRow);
	for (i=0; i<fields_arr.length; i++){
		var col_name=fields_arr[i];
		var alias_name=name_aliases[col_name];
		oHead = document.createElement("TH");
		if (alias_name){
			oHead.innerHTML=alias_name;
		}
		else {
			oHead.innerHTML=col_name;
		}
		oRow.appendChild(oHead);
		oHead.className="data_grid_cell";
		oHead.id=col_name;
	}
	
	for (i=0; i<records_arr.length; i++){
		oRow = document.createElement("TR");
		oTBody.appendChild(oRow);
		var record=records_arr[i];
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

function draw_charts(){
	var charts_cell=document.getElementById("charts_cell");
	var charts_container=document.getElementById("charts_container");
	charts_container.innerHTML="";
	if (charts_arr.length!=0){
		charts_cell.style.display="";
		for (j=0; j<charts_arr.length; j++){
			var chart_hash=charts_arr[j];
			var chart_name=chart_hash["chart_name"];
			var data_field=chart_hash["data_field"];
			var legend_field=chart_hash["legend_field"];
			add_chart(chart_name, data_field, legend_field, j);
		}
	}
	else {
		charts_cell.style.display="none";
	}
}

function add_chart(chart_name, data_key, legend_key, chart_no){
	var charts_container=document.getElementById("charts_container");
	var chart_widget=document.createElement("DIV");
	no_str=chart_no.toString();
	chart_widget.id="chart_widget_" + no_str;
	chart_widget.className="chart_widget";
	charts_container.appendChild(chart_widget);
	// Create chart header
	var header_elt=document.createElement("DIV");
	header_elt.id="header_elt_" + no_str;
	header_elt.className="chart_header";
	header_elt.innerHTML=chart_name;
	chart_widget.appendChild(header_elt);
	
	// Create chart container
	var chart_container=document.createElement("DIV");
	chart_container.id="chart_container_" + no_str;
	chart_container.className="chart_container";
	chart_widget.appendChild(chart_container);
	
	// Generate chart
	generate_chart(chart_container.id, data_key, legend_key);
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
	var pie_chart=chart_paper.piechart(cx, cy, r, data, options);
}