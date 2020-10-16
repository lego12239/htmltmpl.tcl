Overview
=======
htmltmpl package implement a text template engine similar to perl
HTML::Template. The goal is to separate code and markup.

Synopsis
========
htmltmpl::compile_file [-globalvars] FILENAME

htmltmpl::compile_fh [-globalvars] CHAN

htmltmpl::compile_str [-globalvars] STRING

Description
===========
compile_file routine read a template from a file and compiles it.
compile_fh routine read a template from a channel and compiles it.
compile_str routine get a template from a string and compiles it.

A template consist of text and tags. Tags recognized by htmltmpl
are described in the "Template tags" section below.

Each tag has the next structure:

<NAME ATTR_NAME=ATTR_VALUE ...>

Where NAME is a tag name(begin with TMPL_ prefix; e.g. TMPL_VAR).
After a tag name comes attribute name-value pairs.

If a tag attribute value contains whitespace char, =, " or >, then
it must be enclosed in double quotes.

Template tags
=============
htmltmpl:
  TMPL_VAR

      <TMPL_VAR NAME=var_key_name [DEFAULT=value] [ESCAPE=(NONE|HTML|JS|URI)]>

      This is replaced with a value of var_key_name key of a data dict.
      If DEFAULT attribute is specified, then if var_key_name key isn't
      found, a tag is replaced with a value of DEFAULT attribute.
      If ESCAPE attribute is specified, then a value is escaped:
        NONE - the same as no ESCAPE attribute(no escaping)
        HTML - replace &, <, >, " and ' with html entity equivalent
        JS - replace \, ', ", \n, \r with a backslash
        URI - escapes any characters except A-Za-z0-9_.~- according to rfc3986

  TMPL_LOOP

      <TMPL_LOOP NAME=list_key_name>...</TMPL_LOOP>

      For this tag htmltmpl find a key in data dict with list_key_name
      name. It must contains a list. Where each element of a list is
      a data dict for substitution. A content of this element is repeated
      as many times as there are elements in the list with tags
      substitution as expected.

  TMPL_IF

      <TMPL_IF NAME=var_key_name>...<TMPL_ELSE>...</TMPL_IF>

      A content of TMPL_ELSE is included in the output if:
      - var_key_name key isn't exist in a data dict
      - value of a key is an empty string
      - value of a key is a false boolean value(according to Tcl_GetDouble)
      In other case a content of TMPL_IF is included in the output.

  TMPL_INCLUDE

      <TMPL_INCLUDE FILE=file_name>

      A content of file_name file is compiled(on parse stage) and it is saved in
      the resulting compiled template instead of this tag.

 htmltmpl_ifdef:
  TMPL_IFDEF

      <TMPL_IFDEF NAME=var_key_name>...<TMPL_ELSE>...</TMPL_IF>

      A content of TMPL_IF is included in the output if var_key_name key is
      exist in a data dict, otherwise a content of TMPL_ELSE is included
      instead.

Examples
========
~$ cat test.tmpl
```
<html>
<head>
</head>
<body>
  Hello, <TMPL_VAR NAME=name>
  Your items:
  <TMPL_LOOP NAME=items>
    <TMPL_VAR NAME=item_name>: <TMPL_VAR NAME=item_count>
        <br/>
  </TMPL_LOOP>
</body>
</html>
```
~$ cat test.tcl
```
#!/usr/bin/tclsh

lappend auto_path [pwd]/lib
package require htmltmpl
set tmpl [htmltmpl::compile_file test.tmpl]
puts [htmltmpl::apply $tmpl {name John items {{title i1 count 2} {title i2 count 3} {title i3 count 1}}}]
```
~$ ./test.tcl
```
<html>
<head>
</head>
<body>
  Hello, John
  Your items:

    i1: 2
        <br/>

    i2: 3
        <br/>

    i3: 1
        <br/>

</body>
</html>
```
