#  Unbind(PrintPromptHook);

# Set the prompt to something that pexpect can
# handle
BindGlobal("PrintPromptHook",
function()
  local cp;
  cp := CPROMPT();
  if cp = "gap> " then
    cp := "gap|| ";
  fi;
  if Length(cp)>0 and cp[1] = 'b' then
    cp := "brk|| ";
  fi;
  if Length(cp)>0 and cp[1] = '>' then
    cp := "||";
  fi;
  PRINT_CPROMPT(cp);
end);

# Todo: Maybe depend on the json module and use a rec
BindGlobal("JUPYTER_RunCommand",
function(string)
  local stream, result;

  stream := InputTextString(string);
  result := READ_COMMAND_REAL(stream, true);

  if (Length(result) = 2) and (result[1] = true) then
    Print("{ \"status\": \"ok\", \"result\": \"");
    View(result[2]);
    Print("\"}");
  else
    Print("{ \"status\": \"error\" }");
  fi;
end);

# This is a rather basic helper function to do
# completion. It is related to the completion
# function provided in lib/cmdledit.g in the GAP
# distribution
BindGlobal("JUPYTER_Completion",
function(tok)
  local cand, i;

  cand := IDENTS_BOUND_GVARS();

  for i in cand do
    if PositionSublist(i, tok) = 1 then
      Print(i, "\n");
    fi;
  od;
end);

# This is a really ugly hack, but at the moment
# it works nicely enough to demo stuff.
# In the future we might want to dump the dot
# into a temporary file and then exec dot on it.
BindGlobal("JupyterDotSplash",
function(dot)
    local fn, fd;

    fn := TmpName();
    fd := IO_File(fn, "w");
    IO_Write(fd, dot);
    IO_Close(fd);

    Exec("dot","-Tsvg",fn);

    IO_unlink(fn);
end);


# TikZ draw for jupyter-gap
BindGlobal("JUPYTER_TikZSplash",
function(tikz)
  local fn, header, rnd, ltx, svgfile, stream, svgdata, tojupyter;

  header:=Concatenation( "\\documentclass[crop,tikz]{standalone}\n",
                "\\usepackage{pgfplots}",
                "\\makeatletter\n",
                "\\batchmode\n",
                "\\nonstopmode\n",
                "\\begin{document}",
                "\\begin{tikzpicture}");
  header:=Concatenation(header, tikz);
  header:=Concatenation(header,"\\end{tikzpicture}\n\\end{document}");

  rnd:=String(Random([0..1000]));
  fn := Concatenation("svg_get",rnd);

  PrintTo(Concatenation(fn,".tex"),header);

  ltx:=Concatenation("pdflatex -shell-escape  ",
          Concatenation(fn, ".tex")," > ",Concatenation(fn, ".log2"));
  Exec(ltx);

  if not(IsExistingFile( Concatenation(fn, ".pdf") )) then
    Print("No pdf was created; pdflatex is installed in your system?");
  else
    svgfile:=Concatenation(fn,".svg");
    ltx:=Concatenation("pdf2svg ", Concatenation(fn, ".pdf"), " ",
        svgfile, " >> ",Concatenation(fn, ".log2"));
    Exec(ltx);

    if not(IsExistingFile(svgfile)) then
        Print("No svg was created; pdf2svg is installed in your system?");
    else
        stream := InputTextFile( svgfile );
        if stream <> fail then
            svgdata := ReadAll( stream );
            tojupyter := rec( json := true, source := "gap",
                            data := rec( ("image/svg+xml") := svgdata ),
                            metadata := rec( ("image/svg+xml") := rec( width := 500, height := 500 ) ) );
            CloseStream( stream );
        else
            tojupyter := rec( json := "gap",
                            data := rec( ("text/html") := Concatenation( "Unable to render ", tikz ) ) );
        fi;
        RemoveFile( svgfile );
    fi;
  fi;

  if IsExistingFile( Concatenation(fn, ".log") ) then
    RemoveFile( Concatenation(fn, ".log") );
  fi;
  if IsExistingFile( Concatenation(fn, ".log2") ) then
    RemoveFile( Concatenation(fn, ".log2") );
  fi;
  if IsExistingFile( Concatenation(fn, ".aux") ) then
    RemoveFile( Concatenation(fn, ".aux") );
  fi;
  if IsExistingFile( Concatenation(fn, ".pdf") ) then
    RemoveFile( Concatenation(fn, ".pdf") );
  fi;
  if IsExistingFile( Concatenation(fn, ".tex") ) then
    RemoveFile( Concatenation(fn, ".tex") );
  fi;
  return tojupyter;
end);


# This is another ugly hack to make the GAP Help System
# play ball. Let us please fix this soon.
HELP_VIEWER_INFO.jupyter_online :=
    rec(
         type := "url",
         show := function(url)
             local p,r;

             p := url;

             for r in GAPInfo.RootPaths do
                 p := ReplacedString(url, r, "https://cloud.gap-system.org/");
             od;
             Print("<a target=\"_blank\" href=\"", p, "\">Help</a>\n");
         end
        );

MakeReadWriteGlobal("HELP_SHOW_MATCHES");
UnbindGlobal("HELP_SHOW_MATCHES");
DeclareGlobalFunction("HELP_SHOW_MATCHES");
InstallGlobalFunction(HELP_SHOW_MATCHES, function( books, topic, frombegin )
local   exact,  match,  x,  lines,  cnt,  i,  str,  n;

  # first get lists of exact and other matches
  x := HELP_GET_MATCHES( books, topic, frombegin );
  exact := x[1];
  match := x[2];

  # no topic found
  if 0 = Length(match) and 0 = Length(exact)  then
    Print( "Help: no matching entry found\n" );
    return false;

  # one exact or together one topic found
  elif 1 = Length(exact) or (0 = Length(exact) and 1 = Length(match)) then
    if Length(exact) = 0 then exact := match; fi;
    i := exact[1];
    str := Concatenation("Help: Showing `", i[1].bookname,": ",
                                               StripEscapeSequences(i[1].entries[i[2]][1]), "'\n");
    # to avoid line breaking when str contains escape sequences:
    n := 0;
    while n < Length(str) do
      Print(str{[n+1..Minimum(Length(str),
                                    n + QuoInt(SizeScreen()[1] ,2))]}, "\c");
      n := n + QuoInt(SizeScreen()[1] ,2);
    od;
    HELP_PRINT_MATCH(i);
    return true;

  # more than one topic found, show overview in pager
  else
    lines :=
        ["","Help: several entries match this topic - type ?2 to get match [2]\n"];
        # there is an empty line in the beginning since `tail' will start from line 2
    HELP_LAST.TOPICS:=[];
    cnt := 0;
    # show exact matches first
    match := Concatenation(exact, match);
    for i  in match  do
      cnt := cnt+1;
      topic := Concatenation(i[1].bookname,": ",i[1].entries[i[2]][1]);
		  Add(HELP_LAST.TOPICS, i);
      Add(lines,Concatenation("[",String(cnt),"] ",topic));
    od;
    Pager(rec(lines := lines, formatted := true, start := 2 ));
    return true;
  fi;
end);

# Make sure that we don't insert ugly line breaks into the
# output stream
SetUserPreference("browse", "SelectHelpMatches", false);
SetUserPreference("Pager", "tail");
SetUserPreference("PagerOptions", "");
# This is of course complete nonsense if you're running the jupyter notebook
# on your local machine.
SetHelpViewer("jupyter_online");
