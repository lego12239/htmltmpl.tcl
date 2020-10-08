# Copyright (c) 2020 Oleg Nemanov <lego12239@yandex.ru>
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

package provide htmltmpl_ifdef 1.0

namespace eval htmltmpl {
######################################################################
# TMPL_IFDEF handlers
######################################################################
proc _tmpl_ifdef_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "TMPL_IFDEF: NAME is missed" "" HTMLTMPLERR
	}
	_push_chunks tmpl {}
	_push_priv tmpl [list "TMPL_IFDEF" $attrs]
}
_tags_add TMPL_IFDEF parse _tmpl_ifdef_parse

proc _tmpl_ifdef_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl
	set else_chunks {}

	set priv [_pop_priv tmpl]
	if {[lindex $priv 0] eq "TMPL_ELSE"} {
		set else_chunks [_pop_chunks tmpl]
		set priv [_pop_priv tmpl]
	}
	if {[lindex $priv 0] ne "TMPL_IFDEF"} {
		error "/TMPL_IFDEF: there was '[lindex $priv 0]' tag\
		  instead of TMPL_IFDEF" "" HTMLTMPLERR
	}
	set attrs [lindex $priv 1]

	set chunks [_pop_chunks tmpl]
	dict lappend tmpl chunks\
	  [list [_tag_idx [_tags_get_by_name TMPL_IFDEF]]\
	    [dict get $attrs NAME] $chunks $else_chunks]
}
_tags_add /TMPL_IFDEF parse _tmpl_ifdef_end_parse

proc _tmpl_ifdef_apply {ctx chunk} {
	set str ""

	set name [lindex $chunk 1]
	set val [_ctx_data_exists $ctx $name]
	if {$val} {
		set ifchunks [lindex $chunk 2]
		return [_apply [_ctx_level_down $ctx $ifchunks [_ctx_data_get $ctx]]]
	}
	set elsechunks [lindex $chunk 3]
	return [_apply [_ctx_level_down $ctx $elsechunks [_ctx_data_get $ctx]]]
}
_tags_add TMPL_IFDEF apply _tmpl_ifdef_apply


}

