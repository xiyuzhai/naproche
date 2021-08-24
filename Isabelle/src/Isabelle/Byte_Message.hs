{- generated by Isabelle -}

{-  Title:      Isabelle/Byte_Message.hs
    Author:     Makarius
    LICENSE:    BSD 3-clause (Isabelle)

Byte-oriented messages.

See "$ISABELLE_HOME/src/Pure/PIDE/byte_message.ML"
and "$ISABELLE_HOME/src/Pure/PIDE/byte_message.scala".
-}

{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}

module Isabelle.Byte_Message (
    write, write_line,
    read, read_block, read_line,
    make_message, write_message, read_message, exchange_message,
    make_line_message, write_line_message, read_line_message,
    read_yxml, write_yxml
  )
where

import Prelude hiding (read)
import Data.Maybe
import qualified Data.ByteString as ByteString
import qualified Isabelle.Bytes as Bytes
import Isabelle.Bytes (Bytes)
import qualified Isabelle.Symbol as Symbol
import qualified Isabelle.UTF8 as UTF8
import qualified Isabelle.XML as XML
import qualified Isabelle.YXML as YXML

import Network.Socket (Socket)
import qualified Network.Socket.ByteString as Socket

import Isabelle.Library
import qualified Isabelle.Value as Value


{- output operations -}

write :: Socket -> [Bytes] -> IO ()
write socket = Socket.sendMany socket . map Bytes.unmake

write_line :: Socket -> Bytes -> IO ()
write_line socket s = write socket [s, "\n"]


{- input operations -}

read :: Socket -> Int -> IO Bytes
read socket n = read_body 0 []
  where
    result = Bytes.concat . reverse
    read_body len ss =
      if len >= n then return (result ss)
      else
        (do
          s <- Socket.recv socket (min (n - len) 8192)
          case ByteString.length s of
            0 -> return (result ss)
            m -> read_body (len + m) (Bytes.make s : ss))

read_block :: Socket -> Int -> IO (Maybe Bytes, Int)
read_block socket n = do
  msg <- read socket n
  let len = Bytes.length msg
  return (if len == n then Just msg else Nothing, len)

read_line :: Socket -> IO (Maybe Bytes)
read_line socket = read_body []
  where
    result = trim_line . Bytes.pack . reverse
    read_body bs = do
      s <- Socket.recv socket 1
      case ByteString.length s of
        0 -> return (if null bs then Nothing else Just (result bs))
        1 ->
          case ByteString.head s of
            10 -> return (Just (result bs))
            b -> read_body (b : bs)


{- messages with multiple chunks (arbitrary content) -}

make_header :: [Int] -> [Bytes]
make_header ns = [space_implode "," (map Value.print_int ns), "\n"]

make_message :: [Bytes] -> [Bytes]
make_message chunks = make_header (map Bytes.length chunks) <> chunks

write_message :: Socket -> [Bytes] -> IO ()
write_message socket = write socket . make_message

parse_header :: Bytes -> [Int]
parse_header line =
  let
    res = map Value.parse_nat (space_explode ',' line)
  in
    if all isJust res then map fromJust res
    else error ("Malformed message header: " <> quote (UTF8.decode line))

read_chunk :: Socket -> Int -> IO Bytes
read_chunk socket n = do
  res <- read_block socket n
  return $
    case res of
      (Just chunk, _) -> chunk
      (Nothing, len) ->
        error ("Malformed message chunk: unexpected EOF after " <>
          show len <> " of " <> show n <> " bytes")

read_message :: Socket -> IO (Maybe [Bytes])
read_message socket = do
  res <- read_line socket
  case res of
    Just line -> Just <$> mapM (read_chunk socket) (parse_header line)
    Nothing -> return Nothing

exchange_message :: Socket -> [Bytes] -> IO (Maybe [Bytes])
exchange_message socket msg = do
  write_message socket msg
  read_message socket


-- hybrid messages: line or length+block (with content restriction)

is_length :: Bytes -> Bool
is_length msg =
  not (Bytes.null msg) && Bytes.all_char (\c -> '0' <= c && c <= '9') msg

is_terminated :: Bytes -> Bool
is_terminated msg =
  not (Bytes.null msg) && Symbol.is_ascii_line_terminator (Bytes.char $ Bytes.last msg)

make_line_message :: Bytes -> [Bytes]
make_line_message msg =
  let n = Bytes.length msg in
    if is_length msg || is_terminated msg then
      error ("Bad content for line message:\n" <> take 100 (UTF8.decode msg))
    else
      (if n > 100 || Bytes.any_char (== '\n') msg then make_header [n + 1] else []) <> [msg, "\n"]

write_line_message :: Socket -> Bytes -> IO ()
write_line_message socket = write socket . make_line_message

read_line_message :: Socket -> IO (Maybe Bytes)
read_line_message socket = do
  opt_line <- read_line socket
  case opt_line of
    Nothing -> return Nothing
    Just line ->
      case Value.parse_nat line of
        Nothing -> return $ Just line
        Just n -> fmap trim_line . fst <$> read_block socket n


read_yxml :: Socket -> IO (Maybe XML.Body)
read_yxml socket = do
  res <- read_line_message socket
  return (YXML.parse_body <$> res)

write_yxml :: Socket -> XML.Body -> IO ()
write_yxml socket body =
  write_line_message socket (YXML.string_of_body body)
