var div = document.getElementById("nav_div");
str = "<a href='index.html'>Help Index</a><br>"
str += "<br>";
str += "Tools";
str += "<ul>";
str += "<li><img src='images/buttons/web_dial_24.png' valign='top'>&nbsp;<a href='zone_tool.html'>Zone Tool</a></li>";
str += "<li><img src='images/buttons/link_ops_24.png'  valign='top'>&nbsp;<a href='link_ops.html'>Link Openings</a></li>";
str += "<li><img src='images/buttons/labels_24.png' valign='top'>&nbsp;<a href='labels.html'>Attach Labels</a></li>";
str += "<li><img src='images/buttons/list_24.png' valign='top'>&nbsp;<a href='list.html'>List Zones</a></li>";
str += "</ul>";
str += "<br>";
str += "Commands";
str += "<ul>";
str += "<li><img src='images/buttons/recalc_24.png' border='0' valign='top'>&nbsp;<a href='recalc.html'>Recalculate</a></li>";
str += "<li><img src='images/buttons/rebuild_24.png' border='0' valign='top'>&nbsp;<a href='rebuild.html'>Rebuild</a></li>";
str += "<li><img src='images/buttons/props_24.png' border='0' valign='top'>&nbsp;<a href='props.html'>View/Edit Properties</a></li>";
str += "<li><img src='images/buttons/filter_24.png' border='0' valign='top'>&nbsp;<a href='filter.html'>Filter Dialog</a></li>";
str += "<li><img src='images/buttons/layers_24.png' border='0' valign='top'>&nbsp;<a href='layers.html'>Layers Toolbar</a></li>";
str += "<li><img src='images/buttons/settings_24.png' border='0' valign='top'>&nbsp;<a href='settings.html'>Settings</a></li>";
str += "</ul>";
str += "<br>";
str += "Misc";
str += "<ul>";
str += "<li><a href='attrs.html'>Attributes List</a></li>";
str += "<li><a href='elements.html'>Elements of a Zone</a></li>";
str += "<li><a href='wrk_flow.html'>Recommended Workflow</a></li>";
str += "<li><a href='zone_types.html'>Zone Types</a></li>";
str += "<li><a href='trace_cont.html'>Contour Tracing</a></li>";
str += "</ul>";
str += "<br>";
str += "<ul>";
str += "<li><a href='whats_new.html'>What's New</a></li>";
str += "<li><a href='third_party.html'>Third Party Components</a></li>";
str += "</ul>";
div.innerHTML = str;
