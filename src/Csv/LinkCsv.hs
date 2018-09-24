{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}

module Csv.LinkCsv where

import qualified Data.ByteString.Lazy as B
import           Data.Csv             (FromNamedRecord (..), Header,
                                       decodeByName, (.:))
import qualified Data.Map.Strict      as Map
import           Data.Maybe           (isJust)
import qualified Data.Text            as T
import qualified Data.Vector          as V
import           Link                 (Graph (..), Link (..), OD (..), composeLink, compose)
import qualified System.Directory     as Dir

type Node = Int

type Org = Node
type Dest = Node

type Dist = Double --距離
type Highway = Maybe T.Text
type Oneway = Maybe T.Text
type Bridge = Maybe T.Text
type Width = Maybe T.Text

data LinkCsvOut = LinkCsvOut Org Dest Dist Highway Oneway Bridge Width deriving (Show)

instance FromNamedRecord LinkCsvOut where
  parseNamedRecord m =
    LinkCsvOut
      <$> m .: "nodeIdOrg"
      <*> m .: "nodeIdDest"
      <*> m .: "distance"
      <*> m .: "highway"
      <*> m .: "oneway"
      <*> m .: "bridge"
      <*> m .: "width"



decodeLinkCsv :: FilePath -> IO LinkCsv
decodeLinkCsv fp = do
  cd <- Dir.getCurrentDirectory
  bs <- B.readFile (cd <> "/data/" <> fp)
  let Right (_, ls) = decodeByName bs :: Either String (Header, V.Vector LinkCsvOut)
  return $ makeLinkCsv ls

type LinkCond = (Highway, Bridge, Width)

type LinkWithCond = (Link, LinkCond)

type LinkCsv =
  V.Vector LinkWithCond
  --Map.Map OD (Dist, LinkCond)

makeLinkCsv :: V.Vector LinkCsvOut -> LinkCsv
makeLinkCsv lcos = foldr f [] lcos
  where
    f (LinkCsvOut org dest dist highway oneway bridge width)
      | oneway == Just "yes" = V.cons linkOD
      | oneway == Just "-1" = V.cons linkDO
      | otherwise = V.cons linkOD . V.cons linkDO
      where
        linkOD = (Link (Edge (org :->: dest)) dist, (highway, bridge, width))
        linkDO = (Link (Edge (dest :->: org)) dist, (highway, bridge, width))

showMaybe :: Show a => Maybe a -> String
showMaybe (Just a) = show a
showMaybe Nothing = ""

encodeLinkCsv :: LinkCsv -> String
encodeLinkCsv lc =
  "Orgin,Destination,Distance,Highway,Bridge,Width"
    <> foldr
      (\(Link g dist, (highway_, bridge_, width_)) str_ ->
        let
          org_ :->: dest_ = compose g
        in 
          str_ <> "\n" <> show org_ <> "," <> show dest_ <> "," <> show dist <> "," <> showMaybe highway_ <> "," <> showMaybe bridge_ <> "," <> showMaybe width_)
            "" lc

{-
makeLinkCsvMap :: V.Vector LinkCsv -> LinkCsvMap
makeLinkCsvMap ls = V.foldr f Map.empty ls
  where
    f (LinkCsv org dest dist highway oneway bridge width) =
      Map.insert (org :->: dest) (dist, (highway, oneway, bridge, width))
-}
