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

package provide htmltmpl 0.10

namespace eval htmltmpl {
variable tags [dict create]

######################################################################
# UTILS
######################################################################
proc _pctenc_encode {str} {
	set res ""
	set len [string length $str]
	for {set i 0} {$i < $len} {incr i} {
		set c [string index $str $i]
		if {![regexp {[A-Za-z0-9_.~-]} $c]} {
			set c "%[binary encode hex $c]"
		}
		append res $c
	}
	return $res
}

######################################################################
# COMPILE ROUTINES
######################################################################
# Compile a template from a file.
# SYNOPSIS:
#   compile_file FILE_NAME
#
# RETURN:
#   compiled template
proc compile_file {args} {
	set ctx [_mk_ctx_from_args $args]
	dict set ctx gets_r [namespace current]::gets_from_fh
	set fh [open [dict get $ctx src]]
	dict set ctx src $fh
	set err ""
	if {[catch {_compile $ctx} tmpl]} {
		set err [list $tmpl $::errorInfo $::errorCode]
	}
	close $fh
	if {$err ne ""} {
		error {*}$err
	}
	return $tmpl
}

# Compile a template from file handle.
# SYNOPSIS:
#   compile_fh CHAN
#
# RETURN:
#   compiled template
proc compile_fh {args} {
	set ctx [_mk_ctx_from_args $args]
	dict set ctx gets_r [namespace current]::gets_from_fh
	set tmpl [_compile $ctx]
	return $tmpl
}

# Compile a template from a string.
# SYNOPSIS:
#   compile_str STR
#
# RETURN:
#   compiled template
proc compile_str {args} {
	set ctx [_mk_ctx_from_args $args]
	if {![dict exists $ctx prms s]} {
		dict set ctx prms s 0
	}
	if {![dict exists $ctx prms e]} {
		dict set ctx prms e [string length [dict get $ctx src]]
	}
	if {[dict get $ctx prms e] < [dict get $ctx prms s]} {
		error "e is less than s" "" HTMLTMPLERR
	}
	dict set ctx gets_r [namespace current]::gets_from_str
	set tmpl [_compile $ctx]
	dict unset tmpl prms s
	dict unset tmpl prms e
	return $tmpl
}

proc _mk_ctx_from_args {argslist {prms ""}} {
	set ctx [dict create prms {}]
	set len [expr {[llength $argslist] - 1}]
#	lappend prms hd
	for {set i 0} {$i < $len} {incr i} {
		set prm [string range [lindex $argslist $i] 1 end]
		switch $prm {
			globalvars {
				set val 1
			}
			default {
				if {[lsearch -exact $prms $prm] < 0} {
					error "unknown parameter: [lindex $argslist $i]" ""\
					  HTMLTMPLERR
				}
				incr i
				set val [lindex $argslist $i]
			}
		}
		dict set ctx prms $prm $val
	}

	dict set ctx src [lindex $argslist end]

	return $ctx
}

# Start a parsing.
# ctx_init - context initial values
#            Can contain:
#              gets_r - (MANDATORY) next line get routine
#              src - (MANDATORY) a template source
#              p_s - current offset inside src(only for htmltmpl::gets_from_str)
#              p_e - last offset inside src(only for htmltmpl::gets_from_str)
proc _compile {ctx_init} {
	# Context for parser/lexer
	# lexer keys:
	#   src - a template source
	#   gets_r - a routine for next line reading(must work like a gets)
	#   lineno - line number of last read line of a source
	#   lineno_tok - line number of a start line of a last token
	#   buf - input buffer(lines read from a source)
	# parser:
	#   toks - input tokens buffer(tokens read, but not yet removed)
	#   toks_toks - a cache for _toks_match(tokens numbers in one string)
	#   sect - a current section(hierarchy level name)
	#   p_hd - a hierarchy delimeter characters for key names
	set ctx_def [dict create\
		lineno 0\
		buf ""\
		state 0\
		prms {globalvars 0}]
	set ctx [dict merge $ctx_def $ctx_init]
	dict set ctx prms [dict merge [dict get $ctx_def prms]\
	  [dict get $ctx_init prms]]
	set err ""
	if {[catch {_parse ctx} tmpl]} {
		set linfo "at line [dict get $ctx lineno]: "
		error "${linfo}$tmpl" "${linfo}$::errorInfo" $::errorCode
	}
	dict set tmpl prms [dict get $ctx prms]
	return $tmpl
}

proc _parse {_ctx} {
	upvar $_ctx ctx
	variable tags
	set attrs {}
	set tmpl [dict create\
	  _priv {}\
	  _chunks_stack {}\
	  chunks {}]
	set errmsg_wrongtok {
	  1 "want tag attribute name"
	  2 "want '=' char"
	  3 "want tag attribute value"}

	while {[set tok [_get_tok ctx]] >= 0} {
#		puts "GOT: '[dict get $ctx tok_str]'#${tok}(L[dict get $ctx lineno])"
		switch [dict get $ctx state] {
			0 {
				# Non tag data
				switch $tok {
					0 {
						_chunk_add tmpl "TEXT" [dict get $ctx tok_str]
					}
					1 {
						set tag_name [dict get $ctx tok_str]
						if {![dict exists $tags $tag_name]} {
							error "Unknown tag '$tag_name'"
						}
						set attrs {}
						dict set ctx state 1
					}
				}
			}
			1 {
				# Tag name has been read. Wait an attribute name or '>' sign.
				switch $tok {
					2 {
						set tag_aname [dict get $ctx tok_str]
						if {[dict exists $attrs $tag_aname]} {
							error "tag attribute '$tag_aname' already set" ""\
							  HTMLTMPLERR
						}
						dict set ctx state 2
					}
					5 {
						_chunk_add tmpl $tag_name $attrs
						dict set ctx state 0
					}
					default {
						error "[dict get $errmsg_wrongtok 1], but got\
						  '[dict get $ctx tok_str]'#$tok" "" HTMLTMPLERR
					}
				}
			}
			2 {
				# Tag attribute name has been read. Wait equal sign.
				switch $tok {
					3 {
						dict set ctx state 3
					}
					default {
						error "[dict get $errmsg_wrongtok 2], but got\
						  '[dict get $ctx tok_str]'#$tok" "" HTMLTMPLERR
					}
				}
			}
			3 {
				# Equal sign has been read. Wait tag attribute value.
				switch $tok {
					2 -
					4 {
						set tag_avalue [dict get $ctx tok_str]
						dict set attrs $tag_aname $tag_avalue
						dict set ctx state 1
					}
					default {
						error "[dict get $errmsg_wrongtok 3], but got\
						  '[dict get $ctx tok_str]'#$tok" "" HTMLTMPLERR
					}
				}
			}
		}
	}
	if {$tok == -2} {
		error "[dict get $errmsg_wrongtok [dict get $ctx state]], but got\
		  '[dict get $ctx buf]'" "" HTMLTMPLERR
	}
	dict unset tmpl _priv
	dict unset tmpl _chunks_stack
	return $tmpl
}

proc _chunk_add {_tmpl type data} {
	upvar $_tmpl tmpl
	variable tags

	if {$type eq "TEXT"} {
		dict lappend tmpl chunks [list "TEXT" $data]
	} else {
		[dict get $tags $type parse] tmpl $data
	}
}

# Get a next token.
# return:
#   0 - text chunk
#   1 - start of a tag(tag name)
#   2 - a tag attribute name
#   3 - an equal sign
#   4 - a tag attribute value
#   5 - end of a tag
proc _get_tok {_ctx} {
	upvar $_ctx ctx
	set str ""
	set tok -1

	while {$tok < 0} {
		if {[dict get $ctx buf] eq ""} {
			if {[[dict get $ctx gets_r] ctx line] < 0} {
				return -1
			}
			dict incr ctx lineno
			if {[dict get $ctx lineno] == 1} {
				dict set ctx buf $line
			} else {
				dict set ctx buf "\n$line"
			}
		}
		switch [dict get $ctx state] {
			0 {
				# Search a start of a tag.
				switch -regexp -indexvar midxs [dict get $ctx buf] {
					{</?TMPL_[^>[:space:]]+} {
						if {[lindex $midxs 0 0] > 0} {
							set tok 0
							set str [string range\
							  [dict get $ctx buf] 0 [lindex $midxs 0 0]-1]
						} else {
							set tok 1
							set str [string range\
							  [dict get $ctx buf] 0 [lindex $midxs 0 1]]
						}
					}
					default {
						set tok 0
						set str [dict get $ctx buf]
					}
				}
			}
			1 -
			2 -
			3 {
				# Get a tag parts.
				switch -regexp -matchvar mstr [dict get $ctx buf] {
					{^\s+} {
						_biteoff_buf ctx [string length [lindex $mstr 0]]
					}
					{^=} {
						set tok 3
						set str =
					}
					{^[A-Za-z0-9_-]+} {
						set tok 2
						set str [lindex $mstr 0]
					}
					{^"([^"\\]+|\\.|)+"} {
						set tok 4
						set str [lindex $mstr 0]
					}
					{^>} {
						set tok 5
						set str [lindex $mstr 0]
					}
					default {
						if {[dict get $ctx buf] ne ""} {
							return -2
						}
					}
				}
			}
		}
	}

	_biteoff_buf ctx [string length $str]
	if {$tok == 1} {
		set str [string range $str 1 end]
	} elseif {$tok == 4} {
		set str [string range $str 1 end-1]
		regsub -all {\\(.)} $str {\1} str
	}
	dict set ctx tok_str $str
	return $tok
}

proc _biteoff_buf {_ctx len} {
	upvar $_ctx ctx
	dict set ctx buf [string range [dict get $ctx buf] $len end]
}

######################################################################
# gets routines
######################################################################
proc gets_from_fh {_ctx _var} {
	upvar $_ctx ctx
	upvar $_var var

	return [gets [dict get $ctx src] var]
}

proc gets_from_str {_ctx _var} {
	upvar $_ctx ctx
	upvar $_var var

	if {[dict get $ctx prms s] > [dict get $ctx prms e]} {
		return -1
	}
	set pos [string first "\n" [dict get $ctx src] [dict get $ctx prms s]]
	if {($pos < 0) || ($pos > [dict get $ctx prms e])} {
		set pos [dict get $ctx prms e]
		set off 0
	} else {
		set off -1
	}
	set var [string range [dict get $ctx src] [dict get $ctx prms s]\
	  ${pos}$off]
	dict set ctx prms s [expr {$pos + 1}]
	return [string length $var]
}

######################################################################
# APPLY ROUTINES
######################################################################
proc apply {tmpl data} {
	set ctx [list [dict get $tmpl chunks] [list $data] [dict get $tmpl prms]]
	set str [_apply $ctx]
	return $str
}

proc _apply {ctx} {
	variable tags
	set str ""

	set chunks [_ctx_chunks_get $ctx]
	foreach chunk $chunks {
		set type [lindex $chunk 0]
		if {$type eq "TEXT"} {
			append str [lindex $chunk 1]
		} else {
			append str [[dict get $tags $type apply] $ctx $chunk]
		}
	}

	return $str
}

######################################################################
# APPLY UTILS
######################################################################
proc _ctx_pval_get {ctx pname} {
	return [dict get [lindex $ctx 2] $pname]
}

proc _ctx_chunks_get {ctx} {
	return [lindex $ctx 0]
}

proc _ctx_data_get {ctx {name ""} {defval ""}} {
	set idx [llength [lindex $ctx 1]]
	incr idx -1
	if {$name eq ""} {
		return [lindex $ctx 1 $idx]
	}
	while 1 {
		set data [lindex $ctx 1 $idx]
		if {[dict exists $data $name]} {
			return [dict get $data $name]
		}
		if {(![_ctx_pval_get $ctx globalvars]) || ($idx == 0)} {
			break;
		}
		incr idx -1
	}
	return $defval
}

proc _ctx_data_exists {ctx name} {
	set idx [llength [lindex $ctx 1]]
	incr idx -1
	while 1 {
		set data [lindex $ctx 1 $idx]
		if {[dict exists $data $name]} {
			return 1
		}
		if {(![_ctx_pval_get $ctx globalvars]) || ($idx == 0)} {
			break;
		}
		incr idx -1
	}
	return 0
}

proc _ctx_level_down {ctx chunks data} {
	return [list $chunks [lreplace [lindex $ctx 1] end+1 end+1 $data]\
	  [lindex $ctx 2]]
}

######################################################################
# PARSE UTILS
######################################################################
proc _push_chunks {_tmpl chunks} {
	upvar $_tmpl tmpl

	dict lappend tmpl _chunks_stack [dict get $tmpl chunks]
	dict set tmpl chunks $chunks
}

proc _pop_chunks {_tmpl} {
	upvar $_tmpl tmpl

	set chunks [dict get $tmpl chunks]
	dict set tmpl chunks [lindex [dict get $tmpl _chunks_stack] end]
	dict set tmpl _chunks_stack [lrange [dict get $tmpl _chunks_stack] 0 end-1]
	return $chunks
}

proc _push_priv {_tmpl priv} {
	upvar $_tmpl tmpl

	dict lappend tmpl _priv $priv
}

proc _pop_priv {_tmpl} {
	upvar $_tmpl tmpl

	set priv [lindex [dict get $tmpl _priv] end]
	dict set tmpl _priv [lrange [dict get $tmpl _priv] 0 end-1]
	return $priv
}

######################################################################
# TMPL_VAR handlers
######################################################################
proc _tmpl_var_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "TMPL_VAR: NAME is missed" "" HTMLTMPLERR
	}
	if {[dict exists $attrs DEFAULT]} {
		set defval [dict get $attrs DEFAULT]
	} else {
		set defval ""
	}
	if {[dict exists $attrs ESCAPE]} {
		set esc [dict get $attrs ESCAPE]
		# If the order of words is changed, then _tmpl_var_apply must be
		# changed too.
		set esc_code [lsearch -exact "NONE HTML JS URI" $esc]
		if {$esc_code < 0} {
			error "TMPL_VAR: ESCAPE is wrong: $esc"
		}
	} else {
		set esc_code 0
	}
	dict lappend tmpl chunks [list "TMPL_VAR"\
	  [dict get $attrs NAME] $defval $esc_code]
}
dict set tags TMPL_VAR parse _tmpl_var_parse

proc _tmpl_var_apply {ctx chunk} {
	set name [lindex $chunk 1]
	set defval [lindex $chunk 2]
	set val [_ctx_data_get $ctx $name $defval]
	switch [lindex $chunk 3] {
		0 {
		}
		1 {
			# &, <, > - for any places
			# ", ' - for element attributes
			set val [string map {& &amp; < &lt; > &gt; \" &quot; \' &#39;}\
			  $val]
		}
		2 {
			set val [string map {\\ \\\\ \' \\' \" \\\" \n \\n \r \\r} $val]
		}
		3 {
			set val [_pctenc_encode [encoding convertto utf-8 $val]]
		}
	}
	return $val
}
dict set tags TMPL_VAR apply _tmpl_var_apply

######################################################################
# TMPL_LOOP handlers
######################################################################
proc _tmpl_loop_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "TMPL_LOOP: NAME is missed" "" HTMLTMPLERR
	}
	_push_chunks tmpl {}
	_push_priv tmpl [list "TMPL_LOOP" $attrs]
}
dict set tags TMPL_LOOP parse _tmpl_loop_parse

proc _tmpl_loop_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	set priv [_pop_priv tmpl]
	if {[lindex $priv 0] ne "TMPL_LOOP"} {
		error "/TMPL_LOOP: there was '[lindex $priv 0]' tag\
		  instead of TMPL_LOOP" "" HTMLTMPLERR
	}
	set attrs [lindex $priv 1]

	set chunks [_pop_chunks tmpl]
	dict lappend tmpl chunks [list "TMPL_LOOP" [dict get $attrs NAME] $chunks]
}
dict set tags /TMPL_LOOP parse _tmpl_loop_end_parse

proc _tmpl_loop_apply {ctx chunk} {
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
dict set tags TMPL_LOOP apply _tmpl_loop_apply

######################################################################
# TMPL_IF handlers
######################################################################
proc _tmpl_if_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	__tmpl_ifunless_parse tmpl $attrs TMPL_IF
}
dict set tags TMPL_IF parse _tmpl_if_parse

proc _tmpl_unless_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	__tmpl_ifunless_parse tmpl $attrs TMPL_UNLESS
}
dict set tags TMPL_UNLESS parse _tmpl_unless_parse

proc __tmpl_ifunless_parse {_tmpl attrs tagname} {
	upvar $_tmpl tmpl

	if {![dict exists $attrs NAME]} {
		error "$tagname: NAME is missed" "" HTMLTMPLERR
	}
	_push_chunks tmpl {}
	_push_priv tmpl [list $tagname $attrs]
}

proc _tmpl_else_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	_push_chunks tmpl {}
	_push_priv tmpl [list "TMPL_ELSE"]
}
dict set tags TMPL_ELSE parse _tmpl_else_parse

proc _tmpl_if_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	__tmpl_ifunless_end_parse tmpl $attrs TMPL_IF
}
dict set tags /TMPL_IF parse _tmpl_if_end_parse

proc _tmpl_unless_end_parse {_tmpl attrs} {
	upvar $_tmpl tmpl

	__tmpl_ifunless_end_parse tmpl $attrs TMPL_UNLESS
}
dict set tags /TMPL_UNLESS parse _tmpl_unless_end_parse

proc __tmpl_ifunless_end_parse {_tmpl attrs tagname} {
	upvar $_tmpl tmpl
	set else_chunks {}

	set priv [_pop_priv tmpl]
	if {[lindex $priv 0] eq "TMPL_ELSE"} {
		set else_chunks [_pop_chunks tmpl]
		set priv [_pop_priv tmpl]
	}
	if {[lindex $priv 0] ne $tagname} {
		error "/$tagname: there was '[lindex $priv 0]' tag\
		  instead of $tagname" "" HTMLTMPLERR
	}
	set attrs [lindex $priv 1]

	set chunks [_pop_chunks tmpl]
	dict lappend tmpl chunks\
	  [list "$tagname" [dict get $attrs NAME] $chunks $else_chunks]
}

proc _tmpl_if_apply {ctx chunk} {
	return [__tmpl_ifunless_apply $ctx $chunk 1]
}
dict set tags TMPL_IF apply _tmpl_if_apply

proc _tmpl_unless_apply {ctx chunk} {
	return [__tmpl_ifunless_apply $ctx $chunk 0]
}
dict set tags TMPL_UNLESS apply _tmpl_unless_apply

proc __tmpl_ifunless_apply {ctx chunk std} {
	set str ""

	set name [lindex $chunk 1]
	set val [_ctx_data_get $ctx $name 0]
	if {$val eq ""} {
		set val 0
	}
	if {![string is boolean -strict $val]} {
		set val 1
	}
	if {bool($val) == $std} {
		set ifchunks [lindex $chunk 2]
		return [_apply [_ctx_level_down $ctx $ifchunks [_ctx_data_get $ctx]]]
	}
	set elsechunks [lindex $chunk 3]
	return [_apply [_ctx_level_down $ctx $elsechunks [_ctx_data_get $ctx]]]
}


}

