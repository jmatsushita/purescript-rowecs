module ECS where

import Data.Array as A
import Data.IntMap as IM
import Data.Maybe (Maybe, fromJust)
import Data.Record (insert, get, set, delete) as R
import Data.Tuple (Tuple(Tuple))
import Partial.Unsafe (unsafePartial)
import Prelude (($), map)
import Type.Prelude (class IsSymbol, class RowLacks, class RowToList, RLProxy(RLProxy), SProxy(SProxy), RProxy(RProxy))
import Type.Proxy (Proxy2(Proxy2))
import Type.Row (Cons, Nil, kind RowList)

class Storage (c :: Type -> Type) a where
  allocate :: c a
  get :: c a -> Int -> Maybe a
  set :: c a -> Int -> a -> c a
  del :: c a -> Int -> c a
  indices :: c a -> Array Int
  member :: c a -> Int -> Boolean


instance storageIntMap :: Storage IM.IntMap a where
  allocate = IM.empty
  get im ind = IM.lookup ind im
  set im ind val = IM.insert ind val im
  del im ind = IM.delete ind im
  indices im = IM.indices im
  member im ind = IM.member ind im


newtype CompStorage (rowS  :: # Type) = CompStorage (Record rowS)

unCS :: forall rowS . CompStorage rowS -> Record rowS
unCS (CompStorage rec) = rec




read :: forall rowS name a c rowS'
  . Storage c a
  => IsSymbol name
  => RowCons name (c a) rowS' rowS
  => CompStorage rowS -> SProxy name -> Int -> Maybe a
read (CompStorage csrec) spr ind = get v ind
  where
    v = (R.get spr csrec) :: c a


unsafeRead :: forall rowS name a c rowS'
  . IsSymbol name
  => RowCons name (c a) rowS' rowS
  => Storage c a
  => CompStorage rowS -> SProxy name -> Int -> a
unsafeRead (CompStorage csrec) spr ind = unsafePartial $ fromJust $ get v ind
  where
    v = (R.get spr csrec) :: c a


write :: forall rowS name a c rowS'
  . Storage c a
  => IsSymbol name
  => RowCons name (c a) rowS' rowS
  => CompStorage rowS -> SProxy name -> Int -> a -> CompStorage rowS
write (CompStorage csrec) spr ind val = CompStorage stor'
  where
    intmap = (R.get spr csrec) :: c a
    intmap' = set intmap ind val
    stor' = R.set spr intmap' csrec

class AllocateStorage (listS :: RowList) (rowS :: # Type) (c :: Type -> Type) a
    | listS -> c a, listS -> rowS
  where
    allocateStorageImpl :: RLProxy listS -> Record rowS

instance allocateStorageNil :: AllocateStorage Nil () c a where
  allocateStorageImpl _ = {}

instance allocateStorageCons ::
  ( IsSymbol name
  , Storage c a
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowS'
  , AllocateStorage listS' rowS' d b
  ) => AllocateStorage (Cons name (c a) listS') rowS c a
    where
      allocateStorageImpl _ = R.insert nameP allocate rest
        where
          nameP = SProxy :: SProxy name
          rest = allocateStorageImpl (RLProxy :: RLProxy listS') :: Record rowS'

allocateStorage :: forall listS rowS c a
  . RowToList rowS listS
  => AllocateStorage listS rowS c a
  => Storage c a
  => RProxy rowS
  -> CompStorage rowS
allocateStorage _ = CompStorage $ allocateStorageImpl (RLProxy :: RLProxy listS)

class AllocateStorageUniform (c :: Type -> Type) (listD :: RowList)  (rowS :: # Type) a
    | listD c -> rowS a, rowS -> c
  where
    allocateStorageUniformImpl :: RLProxy listD -> Proxy2 c -> Record rowS

instance allocateStorageUniformNil :: AllocateStorageUniform m Nil () a where
  allocateStorageUniformImpl _ _ = {}

instance allocateStorageUniformCons ::
  ( IsSymbol name
  , Storage c a
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowS'
  , AllocateStorageUniform c listD' rowS' b
  ) => AllocateStorageUniform c (Cons name a listD') rowS a where
  allocateStorageUniformImpl _ _ = R.insert nameP allocate rest
    where
      nameP = SProxy :: SProxy name
      rest = allocateStorageUniformImpl (RLProxy :: RLProxy listD') (Proxy2 :: Proxy2 c) :: Record rowS'

allocateStorageUniform :: forall c rowD listD a rowS
  . RowToList rowD listD
  => AllocateStorageUniform c listD rowS a
  => Storage c a
  => RProxy rowD
  -> Proxy2 c
  -> CompStorage rowS
allocateStorageUniform _ cprox = CompStorage $ allocateStorageUniformImpl (RLProxy :: RLProxy listD)  cprox


class ReadStorage (rowS :: # Type) (listD :: RowList) (rowD :: # Type) (c :: Type -> Type)  a
    | listD -> rowD, rowD -> a, listD rowS -> c
  where
    readStorageImpl :: RLProxy listD -> CompStorage rowS -> Int -> Record rowD

instance readStorageNil :: ReadStorage rowS Nil () c a where
   readStorageImpl _ _ _ = {}

instance readStorageCons ::
  ( IsSymbol name
  , Storage c a
  , RowCons name a rowD' rowD
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowD'
  , ReadStorage rowS listD' rowD' d b
  ) => ReadStorage rowS (Cons name a listD') rowD c a
    where
      readStorageImpl _ cstor ind = R.insert nameP val rest
        where
          nameP = SProxy :: SProxy name
          val = unsafeRead cstor nameP ind :: a
          rest = readStorageImpl (RLProxy :: RLProxy listD') cstor ind

readStorage :: forall c rowD rowS listD a
  . RowToList rowD listD
  => ReadStorage rowS listD rowD c a
  => CompStorage rowS
  -> Int
  -> Record rowD
readStorage cstor ind = readStorageImpl (RLProxy :: RLProxy listD) cstor ind

class WriteStorage (rowS :: # Type) (listD :: RowList) (rowD :: # Type) (c :: Type -> Type) a
    | listD -> rowD, rowD -> a, listD -> c a
  where
    writeStorageImpl :: RLProxy listD -> CompStorage rowS -> Int -> Record rowD -> CompStorage rowS

instance writeStorageNil :: WriteStorage rowS Nil () c a where
    writeStorageImpl _ cstor _ _ = cstor


instance writeStorageCons ::
  ( IsSymbol name
  , Storage c a
  , RowCons name a rowD' rowD
  , RowLacks name rowD'
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowS'
  , WriteStorage rowS listD' rowD' d b
  ) => WriteStorage rowS (Cons name a listD') rowD c a
    where
      writeStorageImpl _ cstor ind drec = CompStorage $ R.set nameP nstr $ unCS rest
        where
          nameP = SProxy :: SProxy name
          str = (R.get nameP $ unCS cstor) :: c a
          wrdat = R.get nameP drec
          nstr = set str ind wrdat
          delrec = (R.delete nameP drec) :: Record rowD'
          rest = writeStorageImpl (RLProxy :: RLProxy listD') cstor ind delrec

writeStorage :: forall c rowD rowS listD a
  . RowToList rowD listD
  => WriteStorage rowS listD rowD c a
  => CompStorage rowS
  -> Int
  -> Record rowD
  -> CompStorage rowS
writeStorage = writeStorageImpl (RLProxy :: RLProxy listD)

class IntersectIndices (rowS :: # Type) (listD :: RowList) (rowD :: # Type) (c :: Type -> Type) a
    | listD -> rowD, rowD -> a, listD rowS -> c
  where
    intersectIndicesImpl :: RLProxy listD -> CompStorage rowS -> Array Int

instance intersectIndicesBase ::
  ( Storage c a
  , IsSymbol name
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowS'
  ) => IntersectIndices rowS (Cons name a Nil) rowD c a where
  intersectIndicesImpl _ (CompStorage im) = indices (R.get (SProxy :: SProxy name) im)

instance intersectIndicesRec ::
  ( Storage c a
  , IsSymbol name
  , RowCons name a rowD' rowD
  , RowCons name (c a) rowS' rowS
  , RowLacks name rowD'
  , IntersectIndices rowS listD' rowD' d b
  ) => IntersectIndices rowS (Cons name a listD') rowD c a
    where
      intersectIndicesImpl _ cs = A.filter f rest
        where
          f x = member (R.get nameP (unCS cs)) x
          nameP = SProxy :: SProxy name
          rest = intersectIndicesImpl (RLProxy :: RLProxy listD') cs

intersectIndices :: forall c rowD rowS listD a
  . RowToList rowD listD
  => IntersectIndices rowS listD rowD c a
  => CompStorage rowS
  -> RProxy rowD
  -> Array Int
intersectIndices cstor _ = intersectIndicesImpl (RLProxy :: RLProxy listD) cstor



applyFn ::  forall rowS rowD rowO listD c a
  . RowToList rowD listD
  => ReadStorage rowS listD rowD c a
  => Storage c a
  => CompStorage rowS -> (Record rowD -> Record rowO) -> Int -> Record rowO
applyFn cs f ind = f sel
  where
    sel = readStorage cs ind :: Record rowD

mapFn :: forall rowS rowD rowO listD c a
  . RowToList rowD listD
  => ReadStorage rowS listD rowD c a
  => Storage c a
  => IntersectIndices rowS listD rowD c a
  => CompStorage rowS -> (Record rowD -> Record rowO) -> Array (Tuple Int (Record rowO))
mapFn cs f = map (\x -> Tuple x (applyFn cs f x)) (intersectIndices cs (RProxy :: RProxy rowD))
