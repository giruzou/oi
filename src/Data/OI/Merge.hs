{-# LANGUAGE TypeOperators #-}
-- |
-- Module      : Data.OI.Merge
-- Copyright   : (c) Nobuo Yamashita 2011-2016
-- License     : BSD3
-- Author      : Nobuo Yamashita
-- Maintainer  : nobsun@sampou.org
-- Stability   : experimental
--
module Data.OI.Merge
 ( -- * merge list
  mergeOI
 ,nmergeOI  
 ) where

import Data.OI.Internal

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (MVar,newEmptyMVar,newMVar,takeMVar,putMVar)
import System.IO.Unsafe (unsafeInterleaveIO)

mergeOI :: [a] -> [a] -> [a] :-> [a]
mergeOI = (iooi .) . mergeIO

nmergeOI :: [[a]] -> [a] :-> [a]
nmergeOI =  iooi . nmergeIO


mergeIO :: [a] -> [a] -> IO [a]
nmergeIO :: [[a]] -> IO [a]

-- $merge
-- The 'mergeIO' and 'nmergeIO' functions fork one thread for each
-- input list that concurrently evaluates that list; the results are
-- merged into a single output list.  

mergeIO ls rs
 = newEmptyMVar                >>= \ tail_node ->
   newMVar tail_node           >>= \ tail_list ->
   newMVar ()                  >>= \ e ->
   newMVar 2                   >>= \ branches_running ->
   let
    buff = (tail_list,e)
   in
    forkIO (suckIO branches_running buff ls) >>
    forkIO (suckIO branches_running buff rs) >>
    takeMVar tail_node  >>= \ val ->
    putMVar e ()        >>
    return val

nmergeIO lss
 = let
    len = length lss
   in
    newEmptyMVar          >>= \ tail_node ->
    newMVar tail_node     >>= \ tail_list ->
    newMVar ()            >>= \ e ->
    newMVar len           >>= \ branches_running ->
    let
     buff = (tail_list,e)
    in
     mapM_ (\ x -> forkIO (suckIO branches_running buff x)) lss >>
     takeMVar tail_node  >>= \ val ->
     putMVar e ()        >>
     return val

type Buffer a
 = (MVar (MVar [a]), MVar ())

suckIO :: MVar Int -> Buffer a -> [a] -> IO ()
suckIO branches_running buff@(tail_list,e) vs
 = case vs of
        [] -> takeMVar branches_running >>= \ val ->
              if val == 1 then
                 takeMVar tail_list     >>= \ node ->
                 putMVar node []        >>
                 putMVar tail_list node
              else
                 putMVar branches_running (val-1)
        (x:xs) ->
                takeMVar e                       >>= \ () ->
                takeMVar tail_list               >>= \ node ->
                newEmptyMVar                     >>= \ next_node ->
                unsafeInterleaveIO (
                        takeMVar next_node  >>= \ y ->
                        putMVar e ()        >>
                        return y)                >>= \ next_node_val ->
                putMVar node (x:next_node_val)   >>
                putMVar tail_list next_node      >>
                suckIO branches_running buff xs





{-
-- The origin of following codes came from Control.Concurrent module.
-- The original codes using Control.Concurrent.QSem were deprecated.
-- The following codes are made by modifying the original code to use
-- Control.Concurrent.SSem module (privided by SafeSemaphore).

mergeIO :: [a] -> [a] -> IO [a]
nmergeIO :: [[a]] -> IO [a]

mergeIO ls rs
 = newEmptyMVar                >>= \ tail_node ->
   newMVar tail_node           >>= \ tail_list ->
   new max_buff_size           >>= \ e ->
   newMVar 2                   >>= \ branches_running ->
   let
    buff = (tail_list,e)
   in
    forkIO (suckIO branches_running buff ls) >>
    forkIO (suckIO branches_running buff rs) >>
    takeMVar tail_node  >>= \ val ->
    signal e            >>
    return val

nmergeIO lss
 = let
    len = length lss
   in
    newEmptyMVar          >>= \ tail_node ->
    newMVar tail_node     >>= \ tail_list ->
    new     max_buff_size >>= \ e ->
    newMVar len           >>= \ branches_running ->
    let
     buff = (tail_list,e)
    in
    mapIO (\ x -> forkIO (suckIO branches_running buff x)) lss >>
    takeMVar tail_node  >>= \ val ->
    signal e            >>
    return val
  where
    mapIO f xs = sequence (map f xs)

max_buff_size  ::  Int
max_buff_size  =   1

type Buffer a
 = (MVar (MVar [a]), SSem)

suckIO :: MVar Int -> Buffer a -> [a] -> IO ()
suckIO branches_running buff@(tail_list,e) vs
 = case vs of
        [] -> takeMVar branches_running >>= \ val ->
              if val == 1 then
                 takeMVar tail_list     >>= \ node ->
                 putMVar node []        >>
                 putMVar tail_list node
              else
                 putMVar branches_running (val-1)
        (x:xs) ->
                wait e                           >>
                takeMVar tail_list               >>= \ node ->
                newEmptyMVar                     >>= \ next_node ->
                unsafeInterleaveIO (
                        takeMVar next_node  >>= \ y ->
                        signal     e        >>
                        return y)                >>= \ next_node_val ->
                putMVar node (x:next_node_val)   >>
                putMVar tail_list next_node      >>
                suckIO branches_running buff xs
-}
