{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module PonereChangelog where

import           Import
-- text
import qualified Data.Text.Encoding                   as TE
-- lens
import           Lens.Micro
-- opt-parse
import           Options.Applicative
-- umu-changelog
import           PonereChangelog.Capability.Changelog
import           PonereChangelog.Capability.Git
import           PonereChangelog.Capability.Log
import           PonereChangelog.Command
import           PonereChangelog.Log

newtype AppM a
  = AppM
  { unAppM :: IO a
  } deriving ( Functor, Applicative, Monad, MonadIO )

runAppM :: AppM a -> IO a
runAppM app = unAppM app

startApp :: IO ()
startApp = do
  comm <- showHelpOnErrorExecParser
    ( info ( helper <*> parseVersion <*> parseCommand )
      ( fullDesc <> progDesc umuProgDesc <> header umuHeader ))
  runAppM $ run comm
  where
    run :: Command -> AppM ()
    run comm = case comm of
      CommandUpdate  -> do
        eTag <- getLatestTag
        case eTag of
          Left err  -> logError $ show err
          Right tag -> do
            mCommitMsg <- getLatestCommitMsg
            appendTag tag
            appendHint ( maybe "" TE.decodeUtf8 mCommitMsg )
            logInfo "Appended tag to CHANGELOG.md"
      CommandRead -> do
        readLog

instance ManageGit AppM where
  getLatestTag = getLatestTagImpl
  getLatestCommitMsg = getLatestCommitMsgImpl

instance ManageChangelog AppM where
  appendTag = appendTagImpl
  readLog = readLogImpl
  appendHint = appendHintImpl

instance LogMessage AppM where
  logMessage l = case l ^. logReason of
    Info  -> logMessageImpl l Info
    Debug -> logMessageImpl l Debug
    Error -> logMessageImpl l Error
    Warn  -> logMessageImpl l Warn

logMessageImpl :: MonadIO m => Log -> LogReason -> m ()
logMessageImpl l logR = mkTerminalLog
  ( l ^. logMsg . logMessageText )
  logR
  ( l ^. logMsg . logMessageHeader )

showHelpOnErrorExecParser :: ParserInfo a -> IO a
showHelpOnErrorExecParser = customExecParser ( prefs showHelpOnError )

umuProgDesc :: String
umuProgDesc = "Use umu-changelog to manage the CHANGELOG.md"

umuHeader :: String
umuHeader = "umu-changelog: Manage CHANGELOG.md file"