(* The Intel P to C/Pillar Compiler *)
(* Copyright (C) Intel Corporation, April 2010 *)

(* Utilities for dealing with different os path syntax *)

(* This is a simplified model of the OS path syntax that is 
 * intended to play nice with cygwin, and to be simpler to 
 * use and reason about.  It doesn't not support the full
 * generality of the Basis OS.Path facility (but does
 * deal with cygwin paths, unlike OS.Path).
 * 
 * The model of a path is as a volume and a series of links.
 * 
 * Volumes may be a drive letter (e.g. c) or they may be the
 * the special root volume.  
 *
 * An absolute path is one which has a volume.
 *
 * Paths may be reifed as Windows, Cygwin, or Unix path
 * strings.  Relative paths are valid for all three.  
 * An absolute path is valid for:
 *   Windows if the volume is a drive letter
 *   Unix if the volume is root
 *   Cygwin always
 * 
 * Examples:
 *   If volume is C and the links are ["documents and settings", "lpeterse"], 
 *    then the reifications are:
 *    Windows:  C:\documents and settings\lpeterse
 *    Unix: error
 *    Cygwin: /cygdrive/c/documents and settings/lpeterse
 *
 *   If volume is root and the links are ["usr", "lib"],
 *    then the reifications are:
 *    Windows:  error
 *    Unix: /usr/lib
 *    Cygwin: /usr/lib
 * 
 *)

signature PATH = 
sig
  type t 
  datatype volume = Root | Drive of char
  val fromString : string -> t
  val toCygwinString : t -> string
  val toWindowsString : t -> string
  val toUnixString : t -> string
  val toMinGWString : t -> string
  val layout : t -> Layout.t
  (* must be relative *)
  val cons : string * t -> t
  val snoc : t * string -> t
  (* second path must be relative *)
  val append : t * t -> t
  val setVolume : t * volume -> t
  val removeVolume : t -> t
end

structure Path :> PATH =
struct

  datatype volume = Root | Drive of char

  (* arcs are in reverse order *)
  datatype t = PRel of string list
             | PAbs of volume * (string list)


  structure SP = StringParser
  val || = SP.||
  val && = SP.&&

  infix || &&
  val isChar = fn c => SP.satisfy (fn c' => c = c')
  val alpha = SP.satisfy Char.isAlpha
  val ::: = fn (a, b) => SP.map (a && b, fn (a, b) => a ::b)
  val -&& = fn (a, b) => SP.map (a && b, fn (a, b) => b)
  val &&- = fn (a, b) => SP.map (a && b, fn (a, b) => a)
  infixr 5 :::
  infix -&& &&-

  val parseRelative : (string SP.t * char SP.t) -> string List.t SP.t = 
   fn (filename, sep) => 
      let
        val eof = SP.map (SP.atEnd, fn () => [])
        val rec relative = 
         fn () => (filename ::: (sep -&& (SP.$ relative))) ||
                  (filename ::: (sep -&& eof)) ||
                  (filename ::: eof)
        val p = SP.map (SP.$ relative, List.rev)
      in p
      end

  val parseWindowsStyle : t StringParser.t = 
      let
        val invalidFileChar = 
         fn c => (Char.ord c < 32) orelse
                 (c = #"<") orelse
                 (c = #">") orelse
                 (c = #":") orelse
                 (c = #"\"") orelse
                 (c = #"/") orelse
                 (c = #"\\") orelse
                 (c = #"|") orelse
                 (c = #"?") orelse
                 (c = #"*")

        val validFileChar = not o invalidFileChar
        val filename = SP.map (SP.oneOrMore (SP.satisfy validFileChar), String.implode)
        val sep = (isChar #"\\")
        val relative = parseRelative (filename, sep)
        val volume = alpha &&- (isChar #":") &&- sep
        val absolute = volume && relative

        val p = (SP.map (absolute, fn (drive, s) => PAbs (Drive drive, s))) ||
                (SP.map (relative, fn s => PRel s))
      in p
      end

  val parseUnixStyle : t StringParser.t = 
      let
        val invalidFileChar = 
         fn c => (Char.ord c = 0) orelse (c = #"/")
        val validFileChar = not o invalidFileChar
        val filename = SP.map (SP.oneOrMore (SP.satisfy validFileChar), String.implode)
        val sep = (isChar #"/")
        val relative = parseRelative (filename, sep)
        val absolute = sep -&& relative

        val p = (SP.map (absolute, fn s => PAbs (Root, s))) ||
                (SP.map (relative, fn s => PRel s))
      in p
      end

  val parsePath = parseWindowsStyle || parseUnixStyle

  val fromString : string -> t = 
   fn s => 
      let
        val p = 
            (case SP.parse (parsePath, (s, 0))
              of SP.Success (_, p) => p
               | _ => Fail.fail ("Path", "fromString", "Bad path string: " ^ s))
        val path = 
            (case p
              of PAbs (Root, arcs) => 
                 (case List.rev arcs
                   of ("cygdrive" :: vol :: arcs) => 
                      if String.length vol = 1 then 
                        PAbs (Drive (String.sub (vol, 0)), List.rev arcs)
                      else
                        p
                    | _ => p)
               | _ => p)
      in path
      end

  val collapseArcs : string list * string -> string = 
      String.concat o List.rev o List.separate 

  val toCygwinString : t -> string = 
      (fn path => 
          let
            val collapse = fn arcs => collapseArcs (arcs, "/")
            val s = 
                (case path
                  of PRel arcs => collapse arcs
                   | PAbs (Root, arcs) => "/"^collapse arcs
                   | PAbs (Drive c, arcs) => 
                     "/cygdrive/"^(Char.toString c)^"/"^collapse arcs)
          in s
          end)

  val toWindowsString : t -> string =
      (fn path => 
          let
            val collapse = fn arcs => collapseArcs (arcs, "\\")
            val s = 
                (case path
                  of PRel arcs => collapse arcs
                   | PAbs (Root, arcs) => Fail.fail ("Path", "toWindowsString", "Can't use root volume in windows")
                   | PAbs (Drive c, arcs) => (Char.toString c)^":\\"^collapse arcs)
          in s
          end)

  val toUnixString : t -> string =
      (fn path => 
          let
            val collapse = fn arcs => collapseArcs (arcs, "/")
            val s = 
                (case path
                  of PRel arcs => collapse arcs
                   | PAbs (Root, arcs) => "/"^collapse arcs
                   | PAbs (Drive c, arcs) => Fail.fail ("Path", "toUnixString", "Can't use Drive in windows"))
          in s
          end)

  val toMinGWString : t -> string = 
      (fn path => 
          let
            val collapse = fn arcs => collapseArcs (arcs, "/")
            val s = 
                (case path
                  of PRel arcs => collapse arcs
                   | PAbs (Root, arcs) => "/"^collapse arcs
                   | PAbs (Drive c, arcs) => 
                     "/"^(Char.toString c)^"/"^collapse arcs)
          in s
          end)

  val layout : t -> Layout.t = 
      (fn path => 
          let
            val lArcs = List.layout Layout.str 
            val l = 
                (case path
                  of PRel arcs            => Layout.seq [Layout.str "Relative: ", lArcs arcs]
                   | PAbs (Root, arcs)    => Layout.seq [Layout.str "Rooted: ", lArcs arcs]
                   | PAbs (Drive c, arcs) => 
                     let
                       val c = Char.toString c
                     in Layout.seq [Layout.str "Drive ", Layout.str c, Layout.str ": ", lArcs arcs]
                     end)
          in l
          end)

  (* must be relative *)
  val cons : string * t -> t = 
   fn (s, path) => 
      (case path 
        of PRel arcs => PRel (arcs @ [s])
         | PAbs _ => Fail.fail ("Path", "cons", "Can't cons to absolute path"))

  val snoc : t * string -> t =
   fn (path, s) => 
      (case path 
        of PRel arcs => PRel (s::arcs)
         | PAbs (vol, arcs) => PAbs (vol, s::arcs))

  (* second path must be relative *)
  val append : t * t -> t = 
   fn (path1, path2) => 
      (case (path1, path2)
        of (PRel arcs1, PRel arcs2) => PRel (arcs2 @ arcs1)
         | (PAbs (vol, arcs1), PRel arcs2) => PAbs (vol, arcs2 @ arcs1)
         | _ => Fail.fail ("Path", "append", "Can't append absolute path"))

  val setVolume : t * volume -> t = 
   fn (path, vol) => 
      (case path
        of PRel arcs => PAbs (vol, arcs)
         | PAbs (_, arcs) => PAbs (vol, arcs))

  val removeVolume : t -> t = 
   fn path => 
      (case path
        of PRel arcs => path
         | PAbs (_, arcs) => PRel arcs)

end (* structure Path *)
