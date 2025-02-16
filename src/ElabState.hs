
module ElabState where

import qualified Data.Array.Dynamic.L as A
import Text.Megaparsec.Pos
import Data.IORef

import Common
import Syntax
import Values


-- Top scope state
--------------------------------------------------------------------------------

data EntryDef
  = EDPostulate
  | EDDefinition Tm {-# unpack #-} GV

data EntryTy = EntryTy Tm {-# unpack #-} GV

data TopEntry = TopEntry {
  _entryName  :: {-# unpack #-} (Posed Name),
  _entryDef   :: EntryDef,
  _entryTy    :: {-# unpack #-} EntryTy
  }

top :: A.Array TopEntry
top = runIO A.empty
{-# noinline top #-}

lookupTop :: Lvl -> TopEntry
lookupTop x = runIO (A.unsafeRead top x)
{-# inline lookupTop #-}

topRigidity :: Lvl -> Rigidity
topRigidity x = case _entryDef (lookupTop x) of
  EDPostulate -> Rigid
  _           -> Flex
{-# inline topRigidity #-}

-- Meta state
--------------------------------------------------------------------------------

data MetaEntry
  = MEUnsolved SourcePos
  | MESolved {-# unpack #-} GV Unfoldable Tm SourcePos

metas :: A.Array (A.Array MetaEntry)
metas = runIO A.empty
{-# noinline metas #-}

lookupMetaIO :: Meta -> IO MetaEntry
lookupMetaIO (Meta i j) = do
  arr <- A.unsafeRead metas i
  res <- A.unsafeRead arr j
  pure res
{-# inline lookupMetaIO #-}

lookupMeta :: Meta -> MetaEntry
lookupMeta x = runIO (lookupMetaIO x)
{-# inline lookupMeta #-}

metaRigidity :: Meta -> Rigidity
metaRigidity x = case lookupMeta x of MESolved{} -> Flex; _ -> Rigid
{-# inline metaRigidity #-}

writeMeta :: Meta -> MetaEntry -> IO ()
writeMeta (Meta i j) e = do
  arr <- A.unsafeRead metas i
  A.unsafeWrite arr j e
{-# inline writeMeta #-}

--------------------------------------------------------------------------------

headRigidity :: Head -> Rigidity
headRigidity = \case
  HMeta x -> metaRigidity x
  HTop x  -> topRigidity x
  _       -> Rigid
{-# inline headRigidity #-}

-- Source position state
--------------------------------------------------------------------------------

currPos :: IORef SourcePos
currPos = runIO (newIORef (initialPos ""))
{-# noinline currPos #-}

updPos :: SourcePos -> IO ()
updPos = writeIORef currPos
{-# inline updPos #-}

getPos :: IO SourcePos
getPos = readIORef currPos
{-# inline getPos #-}

withPos :: SourcePos -> IO a -> IO a
withPos pos ma = do
  p <- getPos
  updPos pos
  a <- ma
  updPos p
  pure a
{-# inline withPos #-}

--------------------------------------------------------------------------------

reset :: IO ()
reset = do
  A.clear top
  A.clear metas
  writeIORef currPos (initialPos "")
