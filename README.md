Overview
=======
htmltmpl package implement a text template engine similar to perl
HTML::Template. The goal is to separate code and markup.

Synopsis
========
<TMPL_VAR NAME=var_key_name [DEFAULT=value] [ESCAPE=NONE|HTML|JS|URI]>
<TMPL_LOOP NAME=list_key_name>...</TMPL_LOOP>
<TMPL_IF NAME=var_key_name>...<TMPL_ELSE>...</TMPL_IF>
<TMPL_INCLUDE FILE=file_name>

with htmltmpl_ifdef package:
<TMPL_IFDEF NAME=var_key_name>...<TMPL_ELSE>...</TMPL_IF>

Description
===========
If a tag attribute value contains whitespace char, =, " or >, then
it must be enclosed in double quotes.

Template tags
=============
htmltmpl:
  TMPL_VAR
      <TMPL_VAR NAME=var_key_name>
      <TMPL_VAR NAME=var_key_name DEFAULT=value>
      <TMPL_VAR NAME=var_key_name ESCAPE=[NONE|HTML|JS|URI]>

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
      exist in a data dict, otherwise a content of TMPL_ELSE is included instead.
