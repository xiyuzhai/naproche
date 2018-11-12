{-
Authors: Andrei Paskevich (2001 - 2008), Steffen Frerix (2017 - 2018), Makarius (2018)

Syntax of ForThel Instructions.
-}

module Alice.ForTheL.Instruction where

import Control.Monad

import Alice.Data.Instr (Instr)
import qualified Alice.Data.Instr as Instr

import Alice.Parser.Base
import Alice.Parser.Combinators
import Alice.Parser.Primitives

import Alice.Parser.Token


instr :: Parser st Instr
instr = exbrk (readInstr >>= gut)
  where
    gut (Instr.String Instr.Read _) = fail "'read' not allowed here"
    gut (Instr.Command Instr.EXIT) = fail "'exit'/'quit' not allowed here"
    gut i = return i


iRead :: Parser st Instr
iRead = exbrk (readInstr >>= gut)
  where
    gut i@(Instr.String Instr.Read _) = return i
    gut _ = mzero


iExit :: Parser st ()
iExit = exbrk (readInstr >>= gut)
  where
    gut (Instr.Command Instr.EXIT) = return ()
    gut _ = mzero

iDrop :: Parser st Instr.Drop
iDrop = exbrk (wdToken "/" >> readInstrDrop)


readInstr :: Parser st Instr
readInstr =
  readInstrCommand -|- readInstrInt -|- readInstrBool -|- readInstrString -|- readInstrStrings
  where
    readInstrCommand = fmap Instr.Command (readIX Instr.keywordsCommand)
    readInstrInt = liftM2 Instr.Int (readIX Instr.keywordsInt) readInt
    readInstrBool = liftM2 Instr.Bool (readIX Instr.keywordsBool) readBool
    readInstrString = liftM2 Instr.String (readIX Instr.keywordsString) readString
    readInstrStrings = liftM2 Instr.Strings (readIX Instr.keywordsStrings) readStrings

readInt = try $ readString >>= intCheck
  where
    intCheck s = case reads s of
      ((n,[]):_) | n >= 0 -> return n
      _                   -> mzero

readBool = try $ readString >>= boolCheck
  where
    boolCheck "yes" = return True
    boolCheck "on"  = return True
    boolCheck "no"  = return False
    boolCheck "off" = return False
    boolCheck _     = mzero

readString = fmap concat readStrings


readStrings = chainLL1 notClosingBrk
  where
    notClosingBrk = tokenPrim notCl
    notCl t = let tk = showToken t in guard (tk /= "]") >> return tk


readInstrDrop :: Parser st Instr.Drop
readInstrDrop = readInstrCommand -|- readInstrInt -|- readInstrBool -|- readInstrString
  where
    readInstrCommand = fmap Instr.DropCommand (readIX Instr.keywordsCommand)
    readInstrInt = fmap Instr.DropInt (readIX Instr.keywordsInt)
    readInstrBool = fmap Instr.DropBool (readIX Instr.keywordsBool)
    readInstrString = fmap Instr.DropString (readIX Instr.keywordsString)


readIX :: [(a, [String])] -> Parser st a
readIX ix = try $
  anyToken >>= \s -> msum . map (return . fst) $ filter (elem s . snd) ix
