(* The Haskell Research Compiler *)
(*
 * Redistribution and use in source and binary forms, with or without modification, are permitted
 * provided that the following conditions are met:
 * 1.   Redistributions of source code must retain the above copyright notice, this list of
 * conditions and the following disclaimer.
 * 2.   Redistributions in binary form must reproduce the above copyright notice, this list of
 * conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)


signature MIL_NAME_SMALL_VALUES =
sig
  val program : Config.t
                * (Mil.constant -> bool)
                * Mil.t
                -> Mil.t
end

structure MilNameSmallValues :> MIL_NAME_SMALL_VALUES =
struct
  structure I = Identifier
  structure IM = Identifier.Manager
  structure VD = I.VariableDict
  structure M = Mil
  structure MSTM = MilUtils.SymbolTableManager
  structure MRC = MilRewriterClient

  datatype state = S of {stm : M.symbolTableManager, globals : (M.variable * M.global) list ref}

  datatype env = E of {name : M.constant -> bool, config : Config.t}

  local
    val getS = fn g => fn (S t) => g t
    val getE = fn g => fn (E t) => g t
  in
  val stateGetStm = getS #stm
  val stateGetGlobals = getS #globals
  val envGetConfig = getE #config
  val envGetName = getE #name
  end

  val stateBindGlobal =
   fn (state, t, oper) =>
      let
        val v = MSTM.variableFresh (stateGetStm state, "mnm_#", t, M.VkGlobal)
        val g = M.GSimple oper
        val globals = stateGetGlobals state
        val () = globals := (v, g) :: !globals
      in v
      end

  val nameOperand =
   fn (env, opnd) =>
      (case opnd
        of M.SVariable _ => false
         | M.SConstant c => envGetName env c)

  structure TO = MilType.Typer

  val bind =
   fn (state, env, oper) =>
      let
        val c = envGetConfig env
        val si = I.SymbolInfo.SiManager (stateGetStm state)
        val t = TO.operand (c, si, oper)
        val v = stateBindGlobal (state, t, oper)
      in M.SVariable v
      end

  structure Rewrite =
  MilRewriterF (struct
                  type state      = state
                  type env        = env
                  val config      = envGetConfig
                  val label       = fn _ => MRC.Continue
                  val variable    = fn _ => MRC.Continue
                  val operand     =
                   fn (state, env, oper) =>
                      if nameOperand (env, oper) then
                        MRC.StopWith (env, bind (state, env, oper))
                      else
                        MRC.Stop
                  val instruction = fn _ => MRC.Continue
                  val transfer    = fn _ => MRC.Continue
                  val block       = fn _ => MRC.Continue
                  val global      = fn _ => MRC.Continue
                  val bind        = fn (_, env, _) => (env, NONE)
                  val bindLabel   = fn (_, env, _) => (env, NONE)
                  val indent      = 2
                  val cfgEnum     = fn (_, _, t) => MilUtils.CodeBody.dfsTrees t
                end)


  val program =
   fn (config, name, p) =>
      let
        val M.P {symbolTable, ...} = p
        val stm = IM.fromExistingAll symbolTable
        val glist = ref []
        val state = S {stm = stm, globals = glist}
        val env = E {name = name, config = config}
        val M.P {includes, externs, symbolTable, globals, entry} = Rewrite.program (state, env, p)
        val st = IM.finish stm
        val globals = VD.insertAll (globals, !glist)
        val p = M.P {includes = includes, externs = externs, symbolTable = st, globals = globals, entry = entry}
      in p
      end

end;
