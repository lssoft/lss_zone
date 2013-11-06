var delimiter=",";
var layers_arr = new Array ();
var layers_autosuggest = {};

function get_layer(layer_str) {
	layers_arr.push(layer_str);
}

function clear_layers() {
	layers_arr = new Array ();
}

function get_label_preview_txt(preview_txt){
	var preview_container=document.getElementById("preview_container");
	preview_txt=preview_txt.replace("*", "\'"); // Added 06-Nov-13 it is a fix of unterminated string constant problem when units are set to feet
	preview_container.value=unescape(preview_txt);
}

function custom_init(){
	callRuby("get_presets");
	populate_selector("preset_name", presets_arr);
	callRuby("get_settings"); //again in order to get current "preset_name"
	apply_defaults(); //again in order to set appropriate values for selector
	callRuby("get_label_preview");
	callRuby("get_layers");
	var label_layer_field=document.getElementById("label_layer");
	layers_autosuggest = new autosuggest("label_layer", layers_arr, null, send_setting(label_layer_field));
	layers_autosuggest.text_delimiter=[",", ";"];
	layers_autosuggest.response_time=10;
}

function re_bind_layers(){
	layers_autosuggest.bindArray(layers_arr);
}