{-|
Module      : Builders
Description : MTL equivalent of Smarties.Builders
Copyright   : (c) Peter Lu, 2018
License     : GPL-3
Maintainer  : chippermonky@gmail.com
Stability   : experimental


-}
module Smarties.Builders (
  -- $helper1link
  Utility(..),
  UtilityT(..),
  Perception(..),
  PerceptionT(..),
  Action(..),
  ActionT(..),
  Condition(..),
  ConditionT(..),
  SelfAction(..),
  SelfActionT(..),
  fromUtility,
  fromUtilityT,
  fromPerception,
  fromPerceptionT,
  fromCondition,
  fromConditionT,
  fromAction,
  fromActionT,
  fromSelfAction,
  fromSelfActionT
) where

import           Smarties.Base


-- $helper1link
-- Methods for building nodes out of functions.

-- | Utility nodes produce a monadic return value and always have state SUCCESS
data Utility g p a where
  Utility :: (g -> p -> (a, g)) -> Utility g p a
  SimpleUtility :: (p -> a) -> Utility g p a

-- | transformer variant
data UtilityT g p m a where
  UtilityT :: (Monad m) => (g -> p -> m (a, g)) -> UtilityT g p m a
  SimpleUtilityT :: (Monad m) => (p -> m a) -> UtilityT g p m a

-- | Perception nodes modify the perception
data Perception g p where
  Perception :: (g -> p -> (g, p)) -> Perception g p
  SimplePerception :: (p -> p) -> Perception g p
  -- TODO delete this, just use Perception + Conditional, no need to combine them
  ConditionalPerception :: (g -> p -> (Bool, g, p)) -> Perception g p

-- | transformer variant
data PerceptionT g p m where
  PerceptionT :: (g -> p -> m (g, p)) -> PerceptionT g p m
  SimplePerceptionT :: (p -> m p) -> PerceptionT g p m
  ConditionalPerceptionT :: (g -> p -> m (Bool, g, p)) -> PerceptionT g p m

-- | Action nodes add to the output and always have status SUCCESS
data Action g p o where
  Action :: (g -> p -> (g, o)) -> Action g p o
  SimpleAction :: (p -> o) -> Action g p o

-- | transformer variant
data ActionT g p o m where
  ActionT :: (g -> p -> m (g, o)) -> ActionT g p o m
  SimpleActionT :: (p -> m o) -> ActionT g p o m

-- | Condition nodes have status SUCCESS if they return true and FAIL otherwise
data Condition g p where
  Condition :: (g -> p -> (Bool, g)) -> Condition g p
  SimpleCondition :: (p -> Bool) -> Condition g p

-- | transformer variant
data ConditionT g p m where
  ConditionT :: (g -> p -> m (Bool, g)) -> ConditionT g p m
  SimpleConditionT :: (p -> m Bool) -> ConditionT g p m

-- | SelfAction nodes are Action nodes that also apply the action to the perception
data SelfAction g p o where
  SelfAction :: (SelfActionable p o) => (g -> p -> (g, o)) -> SelfAction g p o
  SimpleSelfAction :: (SelfActionable p o) => (p -> o) -> SelfAction g p o

-- | transformer variant
data SelfActionT g p o m where
  SelfActionT :: (SelfActionable p o) => (g -> p -> m (g, o)) -> SelfActionT g p o m
  SimpleSelfActionT :: (SelfActionable p o) => (p -> m o) -> SelfActionT g p o m

-- | convert UtilityT to NodeSequenceT
fromUtilityT :: (Monad m) => UtilityT g p m a -> NodeSequenceT g p o m a
fromUtilityT n = NodeSequenceT $ case n of
  UtilityT f       -> func f
  SimpleUtilityT f -> func (\g p -> f p >>= \x -> return (x, g))
  where
    func f g p = do
      (a, g') <- f g p
      return (a, g', p, SUCCESS, [])

-- | convert Utility to NodeSequence
fromUtility :: (Monad m) => Utility g p a -> NodeSequenceT g p o m a
fromUtility n = case n of
  Utility f       -> fromUtilityT $ UtilityT (\g p -> return $ f g p)
  SimpleUtility f -> fromUtilityT $ SimpleUtilityT (return . f)

-- | converts PerceptionT to NodeSequenceT
fromPerceptionT :: (Monad m) => PerceptionT g p m -> NodeSequenceT g p o m ()
fromPerceptionT n = NodeSequenceT $ case n of
  PerceptionT f            -> func f
  SimplePerceptionT f      -> func (\g p -> f p >>= \x -> return (g, x))
  ConditionalPerceptionT f -> cfunc f
  where
    func f g p = do
      (g', p') <- f g p
      return ((), g', p', SUCCESS, [])
    cfunc f g p = do
      (b, g', p') <- f g p
      return ((), g', p', if b then SUCCESS else FAIL, [])

-- | converts Perception to NodeSequence
fromPerception :: (Monad m) => Perception g p -> NodeSequenceT g p o m ()
fromPerception n = case n of
  Perception f -> fromPerceptionT $ PerceptionT (\g p -> return $ f g p)
  SimplePerception f -> fromPerceptionT $ SimplePerceptionT (return . f)
  ConditionalPerception f -> fromPerceptionT $ ConditionalPerceptionT (\g p -> return $ f g p)

-- | converts ConditionT to NodeSequenceT
fromConditionT :: (Monad m) => ConditionT g p m -> NodeSequenceT g p o m ()
fromConditionT n = NodeSequenceT $ case n of
  ConditionT f       -> func f
  SimpleConditionT f -> func (\g p -> f p >>= \x -> return (x, g))
  where
    func f g p = do
      (b, g') <- f g p
      return ((), g', p, if b then SUCCESS else FAIL, [])

-- | converts Condition to NodeSequence
fromCondition :: (Monad m) => Condition g p -> NodeSequenceT g p o m ()
fromCondition n = case n of
  Condition f       -> fromConditionT $ ConditionT (\g p -> return $ f g p)
  SimpleCondition f -> fromConditionT $ SimpleConditionT (return . f)

-- | converts ActionT to NodeSequenceT
fromActionT :: (Monad m) => ActionT g p o m -> NodeSequenceT g p o m ()
fromActionT n = NodeSequenceT $ case n of
  ActionT f       -> func f
  SimpleActionT f -> func (\g p -> f p >>= \x -> return (g, x))
  where
    func f g p = do
      (g', o) <- f g p
      return ((), g', p, SUCCESS, [o])

-- | converts Action to NodeSequence
fromAction :: (Monad m) => Action g p o -> NodeSequenceT g p o m ()
fromAction n = case n of
  Action f       -> fromActionT $ ActionT (\g p -> return $ f g p)
  SimpleAction f -> fromActionT $ SimpleActionT (return . f)




-- | converts SelftActionT to NodeSequenceT
-- WARNING: may be deprecated in a future release
fromSelfActionT :: (Monad m) => SelfActionT g p o m -> NodeSequenceT g p o m ()
fromSelfActionT n = NodeSequenceT $ case n of
  SelfActionT f       -> func f
  SimpleSelfActionT f -> func (\g p -> f p >>= \x -> return (g, x))
  where
    func f g p = do
      (g', o) <- f g p
      return ((), g', apply o p, SUCCESS, [o])

-- | converts SelftAction to NodeSequence
-- WARNING: may be deprecated in a future release
fromSelfAction :: (Monad m) => SelfAction g p o -> NodeSequenceT g p o m ()
fromSelfAction n = case n of
  SelfAction f -> fromSelfActionT $ SelfActionT (\g p -> return $ f g p)
  SimpleSelfAction f -> fromSelfActionT $ SimpleSelfActionT (return . f)
