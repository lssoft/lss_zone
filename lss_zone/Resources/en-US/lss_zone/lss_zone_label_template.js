var delimiter=",";
var fields_arr = new Array ();
var template_name = "";

function get_template_name(name){
	template_name=name;
	var template_name_field = documents.getElementById("template_name");
	template_name_field.value=template_name;
}

function get_label_preview_txt(preview_txt){
	var preview_container=document.getElementById("preview_container");
	preview_container.value=unescape(preview_txt);
}

function clear_fields(){
	fields_arr = new Array ();
}

function get_field_name(field_name){
	fields_arr.push(field_name);
}

function custom_init(){
	callRuby("get_fields");
	var label_template_txt_box=document.getElementById("label_template");
	var obj = new autosuggest("label_template", fields_arr, null, send_label_template(label_template_txt_box));
	obj.text_delimiter=[",", ";", " ", "\n"];
	obj.response_time=10;
	send_label_template(label_template_txt_box);
}

function send_label_template(txt_box){
	// Escape only new line characters instead of escaping the whole string as it was before escape(txt_box.value).
	// The point is that 'escape' method escapes all UTF-8 characters, so the result 'label_template' string
	// becomes unreadable in ruby. Change made in ver. 1.2.1 05-Jan-14.
	var label_text=txt_box.value.replace(/[\n]/g, '%0A');
	var act_name="label_template" + delimiter + label_text;
	callRuby(act_name);
	callRuby("get_label_preview");
}

function save_template(){
	callRuby("save_template");
}