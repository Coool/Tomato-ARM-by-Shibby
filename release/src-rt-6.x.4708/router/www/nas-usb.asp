<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.0//EN'>
<!--
	Tomato GUI
	USB Support - !!TB

	For use with Tomato Firmware only.
	No part of this file may be used without permission.
-->
<html>
<head>
<meta http-equiv='content-type' content='text/html;charset=utf-8'>
<meta name='robots' content='noindex,nofollow'>
<title>[<% ident(); %>] NAS: USB Support</title>
<link rel='stylesheet' type='text/css' href='tomato.css'>
<link rel='stylesheet' type='text/css' href='color.css'>
<script type='text/javascript' src='tomato.js'></script>

<!-- / / / -->

<style type='text/css'>
textarea {
	width: 98%;
	height: 5em;
}
</style>

<style type='text/css'>
#dev-grid .co1 {
	width: 10%;
}
#dev-grid .co2 {
	width: 9%;
}
#dev-grid .co3 {
	width: 65%;
}
#dev-grid .co4 {
	width: 16%;
	text-align: center;
}
#dev-grid .header {
	text-align: left;
}
</style>

<script type='text/javascript' src='debug.js'></script>

<script type='text/javascript'>

//	<% nvram("usb_enable,usb_uhci,usb_ohci,usb_usb2,usb_usb3,usb_mmc,usb_storage,usb_printer,usb_printer_bidirect,usb_automount,usb_fs_ext4,usb_fs_fat,usb_fs_exfat,usb_fs_ntfs,usb_ntfs_driver,usb_fs_hfs,script_usbmount,script_usbumount,script_usbhotplug,idle_enable,usb_3g,usb_apcupsd"); %>
//	<% usbdevices(); %>

list = [];

var xob = null;

function _umountHost(host)
{
	form.submitHidden('usbcmd.cgi', { remove: host });
}

function _mountHost(host)
{
	form.submitHidden('usbcmd.cgi', { mount: host });
}

function _forceRefresh()
{
	if (!ref.running) ref.once = 1;
	ref.start();
}

function umountHost(a, host)
{
	if (xob) return;

	if ((xob = new XmlHttp()) == null) {
		_umountHost(host);
		return;
	}

	a = E(a);
	a.innerHTML = 'Please wait...';

	xob.onCompleted = function(text, xml) {
		eval(text);
		if (usb.length == 1) {
			if (usb[0] != 0)
				ferror.set(a, 'The device is busy. Please make sure no applications are using it, and try again.', 0);
		}
		xob = null;
		_forceRefresh();
	}

	xob.onError = function() {
		xob = null;
		_forceRefresh();
	}

	xob.post('usbcmd.cgi', 'remove=' + host);
}

function mountHost(a, host)
{
	if (xob) return;

	if ((xob = new XmlHttp()) == null) {
		_mountHost(host);
		return;
	}

	a = E(a);
	a.innerHTML = 'Please wait...';

	xob.onCompleted = function(text, xml) {
		eval(text);
		if (usb.length == 1) {
			if (usb[0] == 0)
				ferror.set(a, 'Failed to mount. Verify the device is plugged in, and try again.', 0);
		}
		xob = null;
		_forceRefresh();
	}

	xob.onError = function() {
		xob = null;
		_forceRefresh();
	}

	xob.post('usbcmd.cgi', 'mount=' + host);
}

var ref = new TomatoRefresh('update.cgi', 'exec=usbdevices', 0, 'nas_usb_refresh');

ref.refresh = function(text)
{
	try {
		eval(text);
	}
	catch (ex) {
		return;
	}
	dg.removeAllData();
	dg.populate();
	dg.resort();
}

var dg = new TomatoGrid();

dg.sortCompare = function(a, b) {
	var col = this.sortColumn;
	var ra = a.getRowData();
	var rb = b.getRowData();
	var r;

	switch (col) {
	case 1:
		if (ra.type == 'Storage' && ra.type == rb.type)
			r = cmpInt(ra.host, rb.host);
		else
			r = cmpText(ra.host, rb.host);
		break;
	default:
		r = cmpText(a.cells[col].innerHTML, b.cells[col].innerHTML);
	}
	return this.sortAscending ? r : -r;
}

dg.populate = function()
{
	var i, j, k, a, b, c, e, s, desc, d, parts, p;

	list = [];

	for (i = 0; i < list.length; ++i) {
		list[i].type = '';
		list[i].host = '';
		list[i].vendor = '';
		list[i].product = '';
		list[i].serial = '';
		list[i].discs = [];
		list[i].is_mounted = 0;
	}
	
	for (i = usbdev.length - 1; i >= 0; --i) {
		a = usbdev[i];
		e = {
			type: a[0],
			host: a[1],
			vendor: a[2],
			product: a[3],
			serial: a[4],
			discs: a[5],
			is_mounted: a[6]
		};
		list.push(e);
	}

	for (i = list.length - 1; i >= 0; --i) {
		e = list[i];

		if (e.type != 'Storage')
			s = '&nbsp<br><small>&nbsp</small>';
		else {
			if (xob)
				s = ((e.is_mounted == 0) ? 'No' : 'Yes') + '<br><small>Please wait...</small>';
			else if (e.is_mounted == 0)
				s = 'No<br><small><a href="javascript:mountHost(\'L' + i + '\',\'' + e.host + '\')" title="Mount all Partitions of Storage Device" id="L' + i + '">[ Mount ]</a></small>';
			else
				s = 'Yes<br><small><a href="javascript:umountHost(\'L' + i + '\',\'' + e.host + '\')" title="Safely Remove Storage Device" id="L' + i + '">[ Unmount ]</a></small>';
		}
		desc = (e.vendor + ' ' + e.product).trim() + '<small>'; // + (e.serial == '' ? '' : '<br>Serial No: ' + e.serial);
		if (e.discs) {
			for (j = 0; j <= e.discs.length - 1; ++j) {
				d = e.discs[j];
				parts = d[1];
				for (k = 0; k <= parts.length - 1; ++k) {
					p = parts[k];
					if (p) {
						desc = desc + '<br>Partition \'' + p[0] + '\'' + (p[3] != '' ? ' ' + p[3] : '') +
							((p[5] != 0) ? ' (' + doScaleSize(p[5], 0) + 
							((p[1] == 1) ? ' / ' + doScaleSize(p[6], 0) + ' free' : '') +
							')' : '') + ' is ' +
							((p[1] != 0) ? '' : 'not ') + ((p[3] == 'swap') ? 'active' : 'mounted') +
							((p[2] != '') ? ' on ' + p[2] : '');
					}
				}
			}
		}
		desc = desc + '</small>';
		this.insert(-1, e, [e.type, e.host, desc, s], false);
	}

	list = [];
}

dg.setup = function()
{
	this.init('dev-grid', 'sort');
	this.headerSet(['Type', 'Host', 'Description', 'Mounted?']);
	this.populate();
	this.sort(1);
}

function earlyInit()
{
	dg.setup();
}

function init()
{
	dg.recolor();
	ref.initPage();
}

function verifyFields(focused, quiet)
{
	var b = !E('_f_usb').checked;
	var a = !E('_f_storage').checked;

	E('_f_uhci').disabled = b || nvram.usb_uhci == -1;
	E('_f_ohci').disabled = b || nvram.usb_ohci == -1;
	E('_f_usb2').disabled = b;
	E('_f_usb3').disabled = b || nvram.usb_usb3 == -1;
	E('_f_print').disabled = b;
	E('_f_storage').disabled = b;

/* LINUX26-BEGIN */
/* MICROSD-BEGIN */
	E('_f_mmc').disabled = a || b || nvram.usb_mmc == -1;
	elem.display(PR('_f_mmc'), nvram.usb_mmc != -1);
/* MICROSD-END */
/* LINUX26-END */

	E('_f_ext4').disabled = b || a;
	E('_f_fat').disabled = b || a;
	E('_f_exfat').disabled = b || a;
/* LINUX26-BEGIN */
	E('_f_idle_enable').disabled = b || a;
	E('_f_usb_3g').disabled = b;
/* LINUX26-END */
/* UPS-BEGIN */
	E('_f_usb_apcupsd').disabled = b;
/* UPS-END */
/* NTFS-BEGIN */
	E('_f_ntfs').disabled = b || a;
	E('_usb_ntfs_driver').disabled = b || a;
/* NTFS-END */
/* HFS-BEGIN */
	E('_f_hfs').disabled = b || a; //!Victek
/* HFS-END */
	E('_f_automount').disabled = b || a;
	E('_f_bprint').disabled = b || !E('_f_print').checked;

	elem.display(PR('_f_automount'), !b && !a);
	elem.display(PR('_script_usbmount'), PR('_script_usbumount'), !b && !a && E('_f_automount').checked);
	elem.display(PR('_script_usbhotplug'), !b && (!a || E('_f_print').checked));

	if (!v_length('_script_usbmount', quiet, 0, 2048)) return 0;
	if (!v_length('_script_usbumount', quiet, 0, 2048)) return 0;
	if (!v_length('_script_usbhotplug', quiet, 0, 2048)) return 0;

	return 1;
}

function save()
{
	var fom;

	if (!verifyFields(null, 0)) return;

	fom = E('_fom');
	fom.usb_enable.value = E('_f_usb').checked ? 1 : 0;
	fom.usb_uhci.value = nvram.usb_uhci == -1 ? -1 : (E('_f_uhci').checked ? 1 : 0);
	fom.usb_ohci.value = nvram.usb_ohci == -1 ? -1 : (E('_f_ohci').checked ? 1 : 0);
	fom.usb_usb2.value = E('_f_usb2').checked ? 1 : 0;
	fom.usb_usb3.value = E('_f_usb3').checked ? 1 : 0;
	fom.usb_storage.value = E('_f_storage').checked ? 1 : 0;
	fom.usb_printer.value = E('_f_print').checked ? 1 : 0;
	fom.usb_printer_bidirect.value = E('_f_bprint').checked ? 1 : 0;

/* LINUX26-BEGIN */
/* MICROSD-BEGIN */
	fom.usb_mmc.value = nvram.usb_mmc == -1 ? -1 : (E('_f_mmc').checked ? 1 : 0);
/* MICROSD-END */
/* LINUX26-END */

	fom.usb_fs_ext4.value = E('_f_ext4').checked ? 1 : 0;
	fom.usb_fs_fat.value = E('_f_fat').checked ? 1 : 0;
	fom.usb_fs_exfat.value = E('_f_exfat').checked ? 1 : 0;
/* NTFS-BEGIN */
	fom.usb_fs_ntfs.value = E('_f_ntfs').checked ? 1 : 0;
/* NTFS-END */
/* HFS-BEGIN */
	fom.usb_fs_hfs.value = E('_f_hfs').checked ? 1 : 0; //!Victek
/* HFS-END */
	fom.usb_automount.value = E('_f_automount').checked ? 1 : 0;
/* LINUX26-BEGIN */
	fom.idle_enable.value = E('_f_idle_enable').checked ? 1 : 0;
	fom.usb_3g.value = E('_f_usb_3g').checked ? 1 : 0;
/* LINUX26-END */
/* UPS-BEGIN */
	fom.usb_apcupsd.value = E('_f_usb_apcupsd').checked ? 1 : 0;
/* UPS-END */

	form.submit(fom, 1);
}

function submit_complete()
{
	reloadPage();
}
</script>

</head>
<body onload='init()'>
<form id='_fom' method='post' action='tomato.cgi'>
<table id='container' cellspacing=0>
<tr><td colspan=2 id='header'>
	<div class='title'>Tomato</div>
	<div class='version'>Version <% version(); %></div>
</td></tr>
<tr id='body'><td id='navi'><script type='text/javascript'>navi()</script></td>
<td id='content'>
<div id='ident'><% ident(); %></div>

<!-- / / / -->

<input type='hidden' name='_nextpage' value='nas-usb.asp'>
<input type='hidden' name='_service' value='usb-restart'>

<input type='hidden' name='usb_enable'>
<input type='hidden' name='usb_uhci'>
<input type='hidden' name='usb_ohci'>
<input type='hidden' name='usb_usb2'>
<input type='hidden' name='usb_usb3'>
<input type='hidden' name='usb_mmc'>
<input type='hidden' name='usb_storage'>
<input type='hidden' name='usb_printer'>
<input type='hidden' name='usb_printer_bidirect'>
<input type='hidden' name='usb_fs_ext4'>
<input type='hidden' name='usb_fs_fat'>
<input type='hidden' name='usb_fs_exfat'>
/* NTFS-BEGIN */
<input type='hidden' name='usb_fs_ntfs'>
/* NTFS-END */
/* HFS-BEGIN */
<input type='hidden' name='usb_fs_hfs'>
/* HFS-END */
<input type='hidden' name='usb_automount'>
/* LINUX26-BEGIN */
<input type='hidden' name='idle_enable'>
<input type='hidden' name='usb_3g'>
/* LINUX26-END */
/* UPS-BEGIN */
<input type='hidden' name='usb_apcupsd'>
/* UPS-END */

<div class='section-title'>USB Support</div>
<div class='section'>
<script type='text/javascript'>

createFieldTable('', [
	{ title: 'Core USB Support', name: 'f_usb', type: 'checkbox', value: nvram.usb_enable == 1 },
	{ title: 'USB 3.0 Support', indent: 2, name: 'f_usb3', type: 'checkbox', value: nvram.usb_usb3 == 1 },
	{ title: 'USB 2.0 Support', indent: 2, name: 'f_usb2', type: 'checkbox', value: nvram.usb_usb2 == 1 },
	{ title: 'USB 1.1 Support', indent: 2, multi: [
		{ suffix: '&nbsp; OHCI &nbsp;&nbsp;&nbsp;', name: 'f_ohci', type: 'checkbox', value: nvram.usb_ohci == 1 },
		{ suffix: '&nbsp; UHCI &nbsp;',	name: 'f_uhci', type: 'checkbox', value: nvram.usb_uhci == 1 }
	] },
	null,
	{ title: 'USB Printer Support', name: 'f_print', type: 'checkbox', value: nvram.usb_printer == 1 },
		{ title: 'Bidirectional copying', indent: 2, name: 'f_bprint', type: 'checkbox', value: nvram.usb_printer_bidirect == 1 },
	null,
	{ title: 'USB Storage Support', name: 'f_storage', type: 'checkbox', value: nvram.usb_storage == 1 },
		{ title: 'File Systems Support', indent: 2, multi: [
			{ suffix: '&nbsp; Ext2 / Ext3 / Ext4 &nbsp;&nbsp;&nbsp;', name: 'f_ext4', type: 'checkbox', value: nvram.usb_fs_ext4 == 1 },
/* NTFS-BEGIN */
			{ suffix: '&nbsp; NTFS &nbsp;&nbsp;&nbsp;', name: 'f_ntfs', type: 'checkbox', value: nvram.usb_fs_ntfs == 1 },
/* NTFS-END */
			{ suffix: '&nbsp; FAT &nbsp;', name: 'f_fat', type: 'checkbox', value: nvram.usb_fs_fat == 1 },
			{ suffix: '&nbsp; exFAT &nbsp;', name: 'f_exfat', type: 'checkbox', value: nvram.usb_fs_exfat == 1 }
/* HFS-BEGIN */
			,{ suffix: '&nbsp; HFS / HFS+ &nbsp;', name: 'f_hfs', type: 'checkbox', value: nvram.usb_fs_hfs == 1 }
/* HFS-END */
		] },
/* NTFS-BEGIN */
	{ title: 'NTFS Driver', indent: 2, name: 'usb_ntfs_driver', type: 'select', options: [
			['ntfs3g','Open NTFS-3G driver'],
/* TUXERA-BEGIN */
			['tuxera','Tuxera driver'],
/* TUXERA-END */
/* PARAGON-BEGIN */
			['paragon','Paragon driver'],
/* PARAGON-END */
		], value: nvram.usb_ntfs_driver },
/* NTFS-END */
/* LINUX26-BEGIN */
/* MICROSD-BEGIN */
		{ title: 'SD/MMC Card Support', indent: 2, name: 'f_mmc', type: 'checkbox', value: nvram.usb_mmc == 1 },
/* MICROSD-END */
/* LINUX26-END */
		{ title: 'Automount', indent: 2, name: 'f_automount', type: 'checkbox',
			suffix: ' <small>Automatically mount all partitions to sub-directories in <i>/mnt</i>.</small>', value: nvram.usb_automount == 1 },
	{ title: 'Run after mounting', indent: 2, name: 'script_usbmount', type: 'textarea', value: nvram.script_usbmount },
	{ title: 'Run before unmounting', indent: 2, name: 'script_usbumount', type: 'textarea', value: nvram.script_usbumount },
	null,
/* LINUX26-BEGIN */
	{ title: 'HDD Spindown', name: 'f_idle_enable', type: 'checkbox',
		suffix: ' <small>Spin down each HDD when idle. No need to use with flash drive.</small>', value: nvram.idle_enable == 1 },
	{ title: 'USB 3G Modem support', name: 'f_usb_3g', type: 'checkbox',
		suffix: ' <small>Before disconnecting 3G Modem from USB port, remember to uncheck box. If modem used usbserial module, you have to reboot router before unplug modem.</small>', value: nvram.usb_3g == 1 },
/* LINUX26-END */
/* UPS-BEGIN */
	{ title: 'Run APCUPSD Deamon', name: 'f_usb_apcupsd', type: 'checkbox',
		suffix: ' <small>Required by UPS Monitor (APC Uninterruptible Power Supply)</small>', value: nvram.usb_apcupsd == 1 },
/* UPS-END */
	{ title: 'Hotplug script<br><small>(called when any USB device is attached or removed)</small>', name: 'script_usbhotplug', type: 'textarea', value: nvram.script_usbhotplug },
	null,
	{ text: '<small>Some of the changes will take effect only after a restart.</small>' }
]);
</script>
</div>

<!-- / / / -->

<div class='section-title'>Attached Devices</div>
<div class='section'>
<table id='dev-grid' class='tomato-grid' cellspacing=0></table>
<div id='usb-controls'>
	<script type='text/javascript'>genStdRefresh(1,0,'ref.toggle()');</script>
</div>
<script type='text/javascript'></script>
</div>

<!-- / / / -->

</td></tr>
<tr><td id='footer' colspan=2>
	<span id='footer-msg'></span>
	<input type='button' value='Save' id='save-button' onclick='save()'>
	<input type='button' value='Cancel' id='cancel-button' onclick='javascript:reloadPage();'>
</td></tr>
</table>
</form>
<script type='text/javascript'>earlyInit();verifyFields(null, 1);</script>
</body>
</html>
