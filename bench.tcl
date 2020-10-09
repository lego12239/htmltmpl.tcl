#!/usr/bin/tclsh

#package require profiler
#profiler::init

lappend auto_path [pwd]
package require htmltmpl
#puts $htmltmpl::tags_by_name
#puts $htmltmpl::tags_by_idx

set str "test this <TMPL_LOOP NAME=Q>one\n<TMPL_VAR NAME=v1>\nthree</TMPL_LOOP> shit"
set full $str
for {set i 0} {$i < 1000} {incr i} {
	append full $str
}
puts "source len: [string length $full]"
set tmpl [htmltmpl::compile_str $full]
puts "compiled tmpl len: [string length $tmpl]"
puts [time {htmltmpl::apply $tmpl {Q {{v1 q} {v1 e} {v1 r} {v1 t}}}} 100]

#puts [profiler::print]
