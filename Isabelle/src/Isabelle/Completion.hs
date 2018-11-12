{- generated by Isabelle -}

{-  Title:      Tools/Haskell/Completion.hs
    Author:     Makarius
    LICENSE:    BSD 3-clause (Isabelle)

Completion of names.

See also "$ISABELLE_HOME/src/Pure/General/completion.ML".
-}

module Isabelle.Completion (
    Name, T, names, none, make, markup_element, markup_report, make_report
  ) where

import qualified Data.List as List

import Isabelle.Library
import qualified Isabelle.Properties as Properties
import qualified Isabelle.Markup as Markup
import qualified Isabelle.XML.Encode as Encode
import qualified Isabelle.XML as XML
import qualified Isabelle.YXML as YXML


type Name = (String, (String, String))  -- external name, kind, internal name
data T = Completion Properties.T Int [Name]  -- position, total length, names

names :: Int -> Properties.T -> [Name] -> T
names limit props names = Completion props (length names) (take limit names)

none :: T
none = names 0 [] []

make :: Int -> (String, Properties.T) -> ((String -> Bool) -> [Name]) -> T
make limit (name, props) make_names =
  if name /= "" && name /= "_"
  then names limit props (make_names $ List.isPrefixOf $ clean_name name)
  else none

markup_element :: T -> (Markup.T, XML.Body)
markup_element (Completion props total names) =
  if not (null names) then
    let
      markup = Markup.properties props Markup.completion
      body =
        Encode.pair Encode.int
          (Encode.list (Encode.pair Encode.string (Encode.pair Encode.string Encode.string)))
          (total, names)
    in (markup, body)
  else (Markup.empty, [])

markup_report :: [T] -> String
markup_report [] = ""
markup_report elems =
  YXML.string_of $ XML.Elem (Markup.report, map (XML.Elem . markup_element) elems)

make_report :: Int -> (String, Properties.T) -> ((String -> Bool) -> [Name]) -> String
make_report limit name_props make_names =
  markup_report [make limit name_props make_names]
