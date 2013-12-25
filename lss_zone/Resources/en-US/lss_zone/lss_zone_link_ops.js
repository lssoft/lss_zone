var cat_cols = {};
var links_arr = new Array ();
var nodes_info_arr = new Array ();
var nodes_pos_arr = new Array ();
var node_objs_arr = new Array ();
var min_crds = null;
var max_crds = null;
var center_crds = null;
var popup = null;
var delta_r=8;
var init_r=8;
var scale=1;

function get_cat_col(cat_col_str){
	var cat_col=cat_col_str.split("|");
	var cat=cat_col[0];
	var col_arr=cat_col[1].split(",");
	col_arr.pop();
	cat_cols[cat]=col_arr.join(",");
}

function get_node_identity(identity_str){
	var identity_arr=identity_str.split(",");
	var identity_hash={};
	identity_hash["number"]=identity_arr[0];
	identity_hash["name"]=identity_arr[1];
	identity_hash["category"]=identity_arr[2];
	identity_hash["area"]=parseFloat(identity_arr[3]);
	nodes_info_arr.push(identity_hash);
}

function get_node_position(pos_str){
	var crds_arr=pos_str.split(",");
	nodes_pos_arr.push(crds_arr);
}

function update_node_position(pos_str){
	var ind=parseInt(pos_str.split("|")[0]);
	var crds_str=pos_str.split("|")[1];
	var crds_arr=crds_str.split(",");
	nodes_pos_arr[ind]=crds_arr;
}

function clear_nodes_and_links(){
	nodes_info_arr = new Array ();
	nodes_pos_arr = new Array ();
	node_objs_arr = new Array ();
	links_arr = new Array ();
	// Disable 'Build' button because links and nodes array became empty.
	var build_graph_btn=document.getElementById("build_graph_btn");
	build_graph_btn.disabled=true;
}

function get_link(link_str) {
	var link_arr=link_str.split("|");
	links_arr.push(link_arr);
}

function display_links_preview(disp_str){
	var links_preview_table=document.getElementById("links_preview_table");
	links_preview_table.style.display=disp_str;
}

function get_max_min_bounds(min_max_str){
	var min_max_arr=min_max_str.split("|");
	min_crds=min_max_arr[0].split(",");
	max_crds=min_max_arr[1].split(",");
}

function get_center(center_str){
	center_crds=center_str.split(",");
}

function rebuild_links_graph(){
	var links_container=document.getElementById("links_container");
	if (links_arr.length!=0){
		links_container.innerHTML="";
		// Estimate scale
		var x_max=parseFloat(max_crds[0]);
		var y_max=parseFloat(max_crds[1]);
		var z_max=parseFloat(max_crds[2]);
		var x_min=parseFloat(min_crds[0]);
		var y_min=parseFloat(min_crds[1]);
		var z_min=parseFloat(min_crds[2]);
		var wdt=x_max-x_min;
		var hgt=(y_max+z_max)-(y_min+z_min);
		var cont_wdt=links_container.offsetWidth;
		var cont_hgt=links_container.offsetHeight;
		var scale_w=(cont_wdt-30)/wdt;
		var scale_h=(cont_hgt-90)/hgt;
		scale=Math.min(scale_w, scale_h);
		// Estimate offset
		var x_c=parseFloat(center_crds[0]);
		var y_c=parseFloat(center_crds[1]);
		var z_c=parseFloat(center_crds[2]);
		var scaled_x_c=x_c*scale;
		var scaled_y_c=-(y_c+z_c)*scale;
		var offset_x=cont_wdt/2-scaled_x_c;
		var offset_y=cont_hgt/2-scaled_y_c;
		// Draw links graph
		var links_paper = Raphael("links_container", "100%", "100%");
		var r=8;
		for (i=0; i<links_arr.length; i++){
			var ind1=links_arr[i][0];
			var ind2=links_arr[i][1];
			var pt1_crds=nodes_pos_arr[ind1];
			var pt2_crds=nodes_pos_arr[ind2];
			x1=Math.round(parseFloat(pt1_crds[0])*scale+offset_x);
			y1=Math.round(-(parseFloat(pt1_crds[1])+parseFloat(pt1_crds[2]))*scale+offset_y);
			x2=Math.round(parseFloat(pt2_crds[0])*scale+offset_x);
			y2=Math.round(-(parseFloat(pt2_crds[1])+parseFloat(pt2_crds[2]))*scale+offset_y);
			x1_str=x1.toString();
			y1_str=y1.toString();
			x2_str=x2.toString();
			y2_str=y2.toString();
			var path_str="M" + x1_str + " " + y1_str + " L" + x2_str + " " + y2_str
			var link_line = links_paper.path(path_str);
			link_line.attr("stroke", "#fff");
			link_line.attr("stroke-width", "3");
			link_line.attr("stroke-opacity", 0.5);
			link_line.attr("stroke-linecap", "round");
		}
		for (i=0; i<nodes_pos_arr.length; i++){
			var pt_crds=nodes_pos_arr[i];
			var x=Math.round(parseFloat(pt_crds[0])*scale+offset_x);
			var y=Math.round(-(parseFloat(pt_crds[1])+parseFloat(pt_crds[2]))*scale+offset_y);
			var node=links_paper.circle(x, y, r);
			var node_data=nodes_info_arr[i];
			node.data("number", node_data["number"]);
			node.data("name", node_data["name"]);
			node.data("area", node_data["area"]);
			node.data("ind", i);
			node.hover(node_in, node_out);
			node.drag(node_move, onstart, onend);
			var cat=node_data["category"];
			var col="rgb(" + cat_cols[cat] + ")";
			node.attr("fill", col);
			node.attr("fill-opacity", 0.5);
			node.attr("stroke", "#fff");
			node.attr("stroke-width", "3");
			node_objs_arr.push(node);
		}
	}
	else {
		// links_tbl.style.display="none";
	}
}

function node_move(dx, dy, x, y, evt){
	var cx=this.attr("initx");
	var cy=this.attr("inity");
	cx+=dx;
	cy+=dy;
	this.attr("cx", cx);
	this.attr("cy", cy);
	real_dx=(dx/scale).toString();
	real_dy=(dy/scale).toString();
	act_name="move_node" + "," + this.data("ind") + "," + real_dx + "," + real_dy;
	callRuby(act_name);
}

function onstart(x, y){
	var cx=this.attr("cx");
	var cy=this.attr("cy");
	this.attr("initx", cx);
	this.attr("inity", cy);
	popup.remove();
	var act_name="save_node_init_pos" + "," + this.data("ind");
	callRuby(act_name);
}

function onend(){
	var act_name="refresh_links" + "," + this.data("ind");
	callRuby(act_name);
}

function node_in(){
	var new_r=init_r+delta_r;
	var anim=Raphael.animation({r: new_r}, 100);
	this.animate(anim);
	var paper=this.paper;
	var txt=this.data("number")+" | "+this.data("name")+" | "+this.data("area");
	popup=paper.popup(this.attr("cx"), this.attr("cy")-2*this.attr("r"), txt, "up", 5);
}

function node_out(){
	var new_r=init_r;
	var anim=Raphael.animation({r: new_r}, 50);
	this.animate(anim);
	popup.remove();
}

function custom_init(){
	callRuby("get_cat_colors");
}

function build_graph(){
	callRuby("build_graph");
}

function display_build_graph(){
	// var graph_cmd_tbl=document.getElementById("build_graph_table");
	// graph_cmd_tbl.style.display="";
	var build_graph_btn=document.getElementById("build_graph_btn");
	build_graph_btn.disabled=false;
}

function send_links_cont_height(){
	var links_cont=document.getElementById("links_container");
	if (links_cont) {
		var hgt=links_cont.offsetHeight+18; //18 is padding size of links_cell div
		act_name="links_cont_height" + delimiter + hgt;
		callRuby(act_name);
	}
}

function fld_unfld_link_ops_dial(){
	var content=document.getElementById("content_container")
	if (content.style.display==""){
		content.style.display="none";
		act_name="adjust_dial_size_min";
		callRuby(act_name);
	}
	else {
		// As for content height, we need to send 'scrollHeight' in order to inform about actual content height
		var content_height=document.body.scrollHeight;
		if (content_height==0){content_height=1};
		// In our particular case table width=100% so we need to send 'offsetWidth' instead of 'scrollWidth'
		var content_width=document.documentElement.offsetWidth;
		act_name="content_size" + delimiter + content_width + delimiter + content_height;
		callRuby(act_name);
		send_dial_xy();
		content.style.display="";
		act_name="adjust_dial_size_max";
		callRuby(act_name);
	}
}