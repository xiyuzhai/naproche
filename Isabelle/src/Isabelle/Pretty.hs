{- generated by Isabelle -}

{-  Title:      Isabelle/Pretty.hs
    Author:     Makarius
    LICENSE:    BSD 3-clause (Isabelle)

Generic pretty printing module.

See "$ISABELLE_HOME/src/Pure/General/pretty.ML".
-}

{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

module Isabelle.Pretty (
  T, symbolic, formatted, unformatted,

  str, brk_indent, brk, fbrk, breaks, fbreaks, blk, block, strs, markup, mark, mark_str, marks_str,
  item, text_fold, keyword1, keyword2, text, paragraph, para, quote, cartouche, separate,
  commas, enclose, enum, list, str_list, big_list)
where

import qualified Data.List as List

import qualified Isabelle.Bytes as Bytes
import Isabelle.Bytes (Bytes)
import Isabelle.Library hiding (enclose, quote, separate, commas)
import qualified Isabelle.Buffer as Buffer
import qualified Isabelle.Markup as Markup
import qualified Isabelle.XML as XML
import qualified Isabelle.YXML as YXML


data T =
    Block Markup.T Bool Int [T]
  | Break Int Int
  | Str Bytes


{- output -}

symbolic_text s = if Bytes.null s then [] else [XML.Text s]

symbolic_markup markup body =
  if Markup.is_empty markup then body
  else [XML.Elem (markup, body)]

symbolic :: T -> XML.Body
symbolic (Block markup consistent indent prts) =
  concatMap symbolic prts
  |> symbolic_markup block_markup
  |> symbolic_markup markup
  where block_markup = if null prts then Markup.empty else Markup.block consistent indent
symbolic (Break wd ind) = [XML.Elem (Markup.break wd ind, symbolic_text (Bytes.spaces wd))]
symbolic (Str s) = symbolic_text s

formatted :: T -> Bytes
formatted = YXML.string_of_body . symbolic

unformatted :: T -> Bytes
unformatted = Buffer.build_content . out
  where
    out (Block markup _ _ prts) =
      let (bg, en) = YXML.output_markup markup
      in Buffer.add bg #> fold out prts #> Buffer.add en
    out (Break _ wd) = Buffer.add (Bytes.spaces wd)
    out (Str s) = Buffer.add s


{- derived operations to create formatting expressions -}

force_nat n | n < 0 = 0
force_nat n = n

str :: BYTES a => a -> T
str = Str . make_bytes

brk_indent :: Int -> Int -> T
brk_indent wd ind = Break (force_nat wd) ind

brk :: Int -> T
brk wd = brk_indent wd 0

fbrk :: T
fbrk = Str "\n"

breaks, fbreaks :: [T] -> [T]
breaks = List.intersperse (brk 1)
fbreaks = List.intersperse fbrk

blk :: (Int, [T]) -> T
blk (indent, es) = Block Markup.empty False (force_nat indent) es

block :: [T] -> T
block prts = blk (2, prts)

strs :: BYTES a => [a] -> T
strs = block . breaks . map str

markup :: Markup.T -> [T] -> T
markup m = Block m False 0

mark :: Markup.T -> T -> T
mark m prt = if m == Markup.empty then prt else markup m [prt]

mark_str :: BYTES a => (Markup.T, a) -> T
mark_str (m, s) = mark m (str s)

marks_str :: BYTES a => ([Markup.T], a) -> T
marks_str (ms, s) = fold_rev mark ms (str s)

item :: [T] -> T
item = markup Markup.item

text_fold :: [T] -> T
text_fold = markup Markup.text_fold

keyword1, keyword2 :: BYTES a => a -> T
keyword1 name = mark_str (Markup.keyword1, name)
keyword2 name = mark_str (Markup.keyword2, name)

text :: BYTES a => a -> [T]
text = breaks . map str . filter (not . Bytes.null) . space_explode ' ' . make_bytes

paragraph :: [T] -> T
paragraph = markup Markup.paragraph

para :: BYTES a => a -> T
para = paragraph . text

quote :: T -> T
quote prt = blk (1, [Str "\"", prt, Str "\""])

cartouche :: T -> T
cartouche prt = blk (1, [Str "\92<open>", prt, Str "\92<close>"])

separate :: BYTES a => a -> [T] -> [T]
separate sep = List.intercalate [str sep, brk 1] . map single

commas :: [T] -> [T]
commas = separate ("," :: Bytes)

enclose :: BYTES a => a -> a -> [T] -> T
enclose lpar rpar prts = block (str lpar : prts <> [str rpar])

enum :: BYTES a => a -> a -> a -> [T] -> T
enum sep lpar rpar = enclose lpar rpar . separate sep

list :: BYTES a => a -> a -> [T] -> T
list = enum ","

str_list :: BYTES a => a -> a -> [a] -> T
str_list lpar rpar = list lpar rpar . map str

big_list :: BYTES a => a -> [T] -> T
big_list name prts = block (fbreaks (str name : prts))
