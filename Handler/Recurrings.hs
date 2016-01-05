module Handler.Recurrings where

import Import
import qualified Database.Esqueleto as ES
import Helpers.Request
import Type.RecurringModel

getRecurringsR :: TribeId -> Handler Value
getRecurringsR tid = do
  requireSession

  recurrings <- runDB findRecurrings :: Handler [RecurringModel]
  return $ object ["recurrings" .= recurrings]
  where
    findRecurrings = 
      ES.select $
        ES.from $ \(recurring `ES.LeftOuterJoin` workout `ES.LeftOuterJoin` location) -> do
        ES.on $ recurring ES.^. RecurringLocation ES.==. location ES.?. LocationId
        ES.on $ recurring ES.^. RecurringWorkout ES.==. workout ES.?. WorkoutId
        ES.where_ $ recurring ES.^. RecurringTribe ES.==. ES.val tid
        return (recurring, workout, location)

postRecurringsR :: TribeId -> Handler Value
postRecurringsR tid = do
  requireTribeAdmin tid

  recurring <- requireJsonBody :: Handler Recurring
  -- TODO: check for schedule clash
  rid <- runDB $ insert recurring
  sendResponseStatus status201 $ object ["recurring" .= Entity rid recurring]