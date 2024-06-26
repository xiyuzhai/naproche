{- generated by Isabelle -}
{-  Title:      Isabelle/Process_Result.hs
    Author:     Makarius
    LICENSE:    BSD 3-clause (Isabelle)

Result of system process.

See "$ISABELLE_HOME/src/Pure/System/process_result.ML"
and "$ISABELLE_HOME/src/Pure/System/process_result.scala"
-}
{-# LANGUAGE OverloadedStrings #-}

module Isabelle.Process_Result
    ( ok_rc
    , error_rc
    , failure_rc
    , interrupt_rc
    , timeout_rc
    , T
    , make
    , rc
    , out_lines
    , err_lines
    , timing
    , timing_elapsed
    , out
    , err
    , ok
    , check) where

import           Isabelle.Time (Time)
import qualified Isabelle.Timing as Timing
import           Isabelle.Timing (Timing)
import           Isabelle.Bytes (Bytes)
import           Isabelle.Library

ok_rc, error_rc, failure_rc, interrupt_rc, timeout_rc :: Int
ok_rc = 0

error_rc = 1

failure_rc = 2

interrupt_rc = 130

timeout_rc = 142

data T = Process_Result { _rc :: !Int
                        , _out_lines :: ![Bytes]
                        , _err_lines :: ![Bytes]
                        , _timing :: !Timing
                        }
  deriving (Show, Eq)

make :: Int -> [Bytes] -> [Bytes] -> Timing -> T
make = Process_Result

rc :: T -> Int
rc = _rc

out_lines :: T -> [Bytes]
out_lines = _out_lines

err_lines :: T -> [Bytes]
err_lines = _err_lines

timing :: T -> Timing
timing = _timing

timing_elapsed :: T -> Time
timing_elapsed = Timing.elapsed . timing

out :: T -> Bytes
out = trim_line . cat_lines . out_lines

err :: T -> Bytes
err = trim_line . cat_lines . err_lines

ok :: T -> Bool
ok result = rc result == ok_rc

check :: T -> T
check result = if ok result
               then result
               else error (make_string $ err result)
