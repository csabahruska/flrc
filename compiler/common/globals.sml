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


signature GLOBALS =
sig

  val disableOptimizedRationals    : Config.t -> bool
  val disableOptimizedIntegers     : Config.t -> bool

  val features : Config.Feature.feature list
  val debugs   : Config.Debug.debug list
  val controls : Config.Control.control list

end;

structure Globals :> GLOBALS =
struct

  val (disableOptimizedRationalsF, disableOptimizedRationals) =
      Config.Feature.mk ("FLRC:disable-optimized-rationals",
                         "disable optimized rational rep")

  val (disableOptimizedIntegersF, disableOptimizedIntegers) =
      Config.Feature.mk ("FLRC:disable-optimized-integers",
                         "disable optimized integer rep")

  val features = [disableOptimizedRationalsF, disableOptimizedIntegersF]
  val debugs = []
  val controls = []

end;
