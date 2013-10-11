var pop_up_div=document.createElement("DIV");
var mouse_over=false;

function image_over(image){
	mouse_over=true;
	image.className="elt_over_shadow";
	pop_up_div.innerHTML="";
	var big_img=document.createElement("IMG");
	big_img.src=image.src;
	pop_up_div.appendChild(big_img);
	var img_real_wdt=big_img.width;
	var img_real_hgt=big_img.height;
	var bnds=image.getBoundingClientRect();
	var top=bnds.top;
	var left=bnds.left;
	var width=image.offsetWidth;
	var height=image.offsetHeight;
	pop_up_div.className="pop_up_block";
	pop_up_div.style.position="fixed";
	pop_up_div.style.top=top;
	pop_up_div.style.left=left+width+15;
	document.body.appendChild(pop_up_div);
	pop_up_div.style.width=width;
	pop_up_div.style.height=height;
	var dw=img_real_wdt+15-width;
	var dh=img_real_hgt+15-height;
	var frames=50;
	var i=0;
	delay=1;
	function grow_size () {
		setTimeout(function () {
			new_wdt=width+parseInt(dw*i/frames);
			new_hgt=height+parseInt(dh*i/frames);
			if (top+new_hgt+90<window.innerHeight){
				pop_up_div.style.top=top;
			}
			else {
				pop_up_div.style.top=window.innerHeight-new_hgt-90;
			}
			pop_up_div.style.width=new_wdt;
			pop_up_div.style.height=new_hgt;
			i+=1;
			if (i<frames && mouse_over) {
				grow_size();
			}
			delay=parseInt(delay+i/30);
		}, delay);
	}
	grow_size();   
}

function image_out(image){
	mouse_over=false;
	image.className="";
	var big_img=document.createElement("IMG");
	big_img.src=image.src;
	pop_up_div.appendChild(big_img);
	var img_real_wdt=big_img.width;
	var img_real_hgt=big_img.height;
	var width=image.offsetWidth;
	var height=image.offsetHeight;
	var dw=img_real_wdt+15-width;
	var dh=img_real_hgt+15-height;
	var frames=25;
	var i=0;
	delay=1;
	var bnds=image.getBoundingClientRect();
	var top=bnds.top;
	var left=bnds.left;
	function shrink_size () {
		setTimeout(function () {
			new_wdt=img_real_wdt-parseInt(dw*i/frames);
			new_hgt=img_real_hgt-parseInt(dh*i/frames);
			if (top+new_hgt+90<window.innerHeight){
				pop_up_div.style.top=top;
			}
			else {
				pop_up_div.style.top=window.innerHeight-new_hgt-90;
			}
			pop_up_div.style.width=new_wdt;
			pop_up_div.style.height=new_hgt;
			i+=1;
			if (i<frames && mouse_over==false) {
				shrink_size();
			}
			else {
				if (mouse_over==false) {
					document.body.removeChild(pop_up_div);
				}
			}
			delay=parseInt(delay+i/20);
		}, delay);
	}
	shrink_size();   
}

function thumb_div_over(thumb_div){
	image=thumb_div.parentNode.getElementsByTagName("IMG")[0];
	mouse_over=true;
	thumb_div.parentNode.className="img_cont_over";
	pop_up_div.innerHTML="";
	var big_img=document.createElement("IMG");
	big_img.src=image.src;
	pop_up_div.appendChild(big_img);
	var img_real_wdt=big_img.width;
	var img_real_hgt=big_img.height;
	var bnds=thumb_div.getBoundingClientRect();
	var top=bnds.top;
	var left=bnds.left;
	var width=thumb_div.offsetWidth;
	var height=thumb_div.offsetHeight;
	pop_up_div.className="pop_up_block";
	pop_up_div.style.position="fixed";
	pop_up_div.style.top=top;
	pop_up_div.style.left=left+width+15;
	document.body.appendChild(pop_up_div);
	pop_up_div.style.width=width;
	pop_up_div.style.height=height;
	var dw=img_real_wdt+15-width;
	var dh=img_real_hgt+15-height;
	var frames=50;
	var i=0;
	delay=1;
	function grow_size1 () {
		setTimeout(function () {
			new_wdt=width+parseInt(dw*i/frames);
			new_hgt=height+parseInt(dh*i/frames);
			if (top+new_hgt+90<window.innerHeight){
				pop_up_div.style.top=top;
			}
			else {
				pop_up_div.style.top=window.innerHeight-new_hgt-90;
			}
			pop_up_div.style.width=new_wdt;
			pop_up_div.style.height=new_hgt;
			i+=1;
			if (i<frames && mouse_over) {
				grow_size1();
			}
			delay=parseInt(delay+i/30);
		}, delay);
	}
	grow_size1();   
}

function thumb_div_out(thumb_div){
	mouse_over=false;
	image=thumb_div.parentNode.getElementsByTagName("IMG")[0];
	thumb_div.parentNode.className="img_cont";
	var big_img=document.createElement("IMG");
	big_img.src=image.src;
	pop_up_div.appendChild(big_img);
	var img_real_wdt=big_img.width;
	var img_real_hgt=big_img.height;
	var width=thumb_div.offsetWidth;
	var height=thumb_div.offsetHeight;
	var dw=img_real_wdt+15-width;
	var dh=img_real_hgt+15-height;
	var frames=25;
	var i=0;
	delay=1;
	var bnds=thumb_div.getBoundingClientRect();
	var top=bnds.top;
	var left=bnds.left;
	function shrink_size1 () {
		setTimeout(function () {
			new_wdt=img_real_wdt-parseInt(dw*i/frames);
			new_hgt=img_real_hgt-parseInt(dh*i/frames);
			if (top+new_hgt+90<window.innerHeight){
				pop_up_div.style.top=top;
			}
			else {
				pop_up_div.style.top=window.innerHeight-new_hgt-90;
			}
			pop_up_div.style.width=new_wdt;
			pop_up_div.style.height=new_hgt;
			i+=1;
			if (i<frames && mouse_over==false) {
				shrink_size1();
			}
			else {
				if (mouse_over==false) {
					document.body.removeChild(pop_up_div);
				}
			}
			delay=parseInt(delay+i/20);
		}, delay);
	}
	shrink_size1();
}