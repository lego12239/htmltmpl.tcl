# Copyright (c) 2020-2023 Oleg Nemanov <lego12239@yandex.ru>
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

package provide htmltmpl_ifeq 1.0

namespace eval htmltmpl {
######################################################################
# TMPL_IFEQ handlers
######################################################################
proc _tmpl_ifeq_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "TMPL_IFEQ: NAME is missed" "" HTMLTMPLERR
	}
	if {![dict exists $attrs VALUE]} {
		error "TMPL_IFEQ: VALUE is missed" "" HTMLTMPLERR
	}
	_push_chunks tmpl {}
	_push_priv tmpl [list "TMPL_IFEQ" $attrs]
}
dict set tags TMPL_IFEQ parse _tmpl_ifeq_parse

proc _tmpl_ifeq_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl
	set else_chunks {}

	set priv [_pop_priv tmpl]
	if {[lindex $priv 0] eq "TMPL_ELSE"} {
		set else_chunks [_pop_chunks tmpl]
		set priv [_pop_priv tmpl]
	}
	if {[lindex $priv 0] ne "TMPL_IFEQ"} {
		error "/TMPL_IFEQ: there was '[lindex $priv 0]' tag\
		  instead of TMPL_IFEQ" "" HTMLTMPLERR
	}
	set attrs [lindex $priv 1]

	set chunks [_pop_chunks tmpl]
	dict lappend tmpl chunks\
	  [list "TMPL_IFEQ" [dict get $attrs NAME] [dict get $attrs VALUE]\
	  $chunks $else_chunks]
}
dict set tags /TMPL_IFEQ parse _tmpl_ifeq_end_parse

proc _tmpl_ifeq_apply {ctx chunk} {
	set str ""

	set name [lindex $chunk 1]
	set val_need [lindex $chunk 2]
	set val [_ctx_data_get $ctx $name]
	if {$val eq $val_need} {
		set ifchunks [lindex $chunk 3]
		return [_apply [_ctx_level_down $ctx $ifchunks [_ctx_data_get $ctx]]]
	}
	set elsechunks [lindex $chunk 4]
	return [_apply [_ctx_level_down $ctx $elsechunks [_ctx_data_get $ctx]]]
}
dict set tags TMPL_IFEQ apply _tmpl_ifeq_apply


}

