module Handler.Events where

import Import hiding ((==.), (<=.), (>=.), (||.), parseTime, on)
import Database.Esqueleto hiding (Value)
import Helpers.Request
import Helpers.Date
import Type.EventModel
import Data.Time.Format (parseTimeM)
import Data.Text (split)

getEventsR :: TribeId -> Handler Value
getEventsR tid = do
  requireSession

  startTimeString <- lookupGetParam "start_date"
  endTimeString <- lookupGetParam "end_date"
  let startDate = parseGregorianDate <$> ((map unpack) . (split (=='-')) <$> startTimeString)
  let endDate = parseGregorianDate <$> ((map unpack) . (split (=='-')) <$> endTimeString)

  events <- runDB $ findEvents startDate endDate :: Handler [EventModel]
  return $ object ["events" .= events]
  where
    findEvents stime etime = do
      select $
        from $ \(event `LeftOuterJoin` workout `LeftOuterJoin` location) -> do
        on $ event ^. EventLocation ==. location ?. LocationId
        on $ event ^. EventWorkout ==. workout ?. WorkoutId
        where_ (event ^. EventTribe ==. val tid)
        where_ $ ((event ^. EventDate >=. val stime)
          &&. (event ^. EventDate <=. val etime))
          ||. (event ^. EventRecurring ==. val True)
        let vc = sub_select $
                 from $ \v -> do
                 where_ (v ^. VerbalEvent ==. event ^. EventId)
                 return countRows
        let rc = sub_select $
                 from $ \r -> do
                 where_ (r ^. ResultEvent ==. event ^. EventId)
                 return countRows
        return (event, workout, location, vc, rc)

postEventsR :: TribeId -> Handler ()
postEventsR tid = do
  requireTribeAdmin tid
  event <- requireJsonBody :: Handler Event
  _     <- runDB $ insert event
  sendResponseStatus status201 ()

dateFromString :: String -> Maybe UTCTime
dateFromString = parseTimeM True defaultTimeLocale "%Y-%m-%d"
