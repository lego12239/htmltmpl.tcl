# Copyright (c) 2023 Oleg Nemanov <lego12239@yandex.ru>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package provide htmltmpl_list 1.0

namespace eval htmltmpl {
######################################################################
# TMPL_LIST handlers
######################################################################
proc _tmpl_list_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "TMPL_LIST: NAME is missed" "" HTMLTMPLERR
	}
	_push_chunks tmpl {}
	_push_priv tmpl [list "TMPL_LIST" $attrs]
}
dict set tags TMPL_LIST parse _tmpl_list_parse

proc _tmpl_list_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	set priv [_pop_priv tmpl]
	if {[lindex $priv 0] ne "TMPL_LIST"} {
		error "/TMPL_LIST: there was '[lindex $priv 0]' tag\
		  instead of TMPL_LIST" "" HTMLTMPLERR
	}
	set attrs [lindex $priv 1]

	set chunks [_pop_chunks tmpl]
	dict lappend tmpl chunks [list "TMPL_LIST" [dict get $attrs NAME] $chunks]
}
dict set tags /TMPL_LIST parse _tmpl_list_end_parse

proc _tmpl_listitem_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	set priv [_get_priv tmpl]
	if {[lindex $priv 0] ne "TMPL_LIST"} {
		error "TMPL_LISTITEM outside TMPL_LIST" "" HTMLTMPLERR
	}
	if {[dict exists $attrs ESCAPE]} {
		set esc [dict get $attrs ESCAPE]
		# If the order of words is changed, then _tmpl_listitem_apply must be
		# changed too.
		set esc_code [lsearch -exact "NONE HTML JS URI" $esc]
		if {$esc_code < 0} {
			error "TMPL_LISTITEM: ESCAPE is wrong: $esc"
		}
	} else {
		set esc_code 0
	}
	dict lappend tmpl chunks [list "TMPL_LISTITEM" $esc_code]
}
dict set tags TMPL_LISTITEM parse _tmpl_listitem_parse

proc _tmpl_list_apply {ctx chunk} {
	set str ""

	set name [lindex $chunk 1]
	set ldata [_ctx_data_get $ctx $name]
	if {[llength $ldata] == 0} {
		return ""
	}
	set lchunks [lindex $chunk 2]
	foreach d $ldata {
		append str [_apply [_ctx_level_down $ctx $lchunks $d]]
	}
	return $str
}
dict set tags TMPL_LIST apply _tmpl_list_apply

proc _tmpl_listitem_apply {ctx chunk} {
	set val [_ctx_data_get $ctx]
	set val [_escape_val $val [lindex $chunk 1]]
	return $val
}
dict set tags TMPL_LISTITEM apply _tmpl_listitem_apply

}

