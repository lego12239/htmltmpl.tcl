Overview
=======
htmltmpl package implement a text template engine similar to perl
HTML::Template. The goal is to separate code and markup.

Synopsis
========
<TMPL_VAR NAME=var_key_name [DEFAULT=value] [ESCAPE=NONE|HTML|JS|URI]>
<TMPL_LOOP NAME=list_key_name>...</TMPL_LOOP>

Template tags
=============
core:
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
