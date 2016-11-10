import              Control.Arrow
import              Control.Exception
import              Control.Monad.Reader
import              Data.List
-- import              Data.Text.Internal
import              Network
import              System.Exit
import              System.IO
import              Text.Printf
import              Text.Regex.Posix

-- import qualified    GitHub as G
-- import qualified    GitHub.Issues as GI


ournick = "devbot"
server  = "irc.freenode.org"
port    = 6667
chans   =   [   "#toktok"
            ,   "#toktok-status"
            ]

enabled_repos = [   "toxcore"
                ,   "py-toxcore-c"
                ,   "hs-toxcore"
                ,   "website"
                ]

regex = "(" ++ (intercalate "|" enabled_repos) ++ ")#([0-9]+)"

data Bot = Bot {
    socket :: Handle
}

type Net = ReaderT Bot IO

data User = User
    {   nick :: String
    ,   user :: String
    ,   host :: String
    }

main :: IO ()
main = bracket connect disconnect loop
  where
    disconnect  = hClose . socket
    loop st     = runReaderT run st

connect :: IO Bot
connect = notify $ do
    irc_conn <- connectTo server $ PortNumber $ fromIntegral port
    hSetBuffering irc_conn NoBuffering
    return (Bot irc_conn)
  where
    notify a = bracket_
        (printf "Connecting to %s ... " server >> hFlush stdout)
        (putStrLn "done.")
        a

run :: Net ()
run = do
    write "NICK" ournick
    write "USER" $ ournick++" 0 * :TokTok DevBot"
    mapM (write "JOIN") chans
    asks socket >>= listen

listen :: Handle -> Net ()
listen h = forever $ do
    string <- init `fmap` io (hGetLine h)
    io $ putStrLn string
    if ping string
        then pong string
        else eval (sender string) (target string) (message string)
  where
    forever a = do a; forever a

    sender  = takeWhile (/= ' ') . drop 1
    target  = takeWhile (/= ' ') . dropWhile (/= '#')
    message = drop 1 . dropWhile (/= ':') . drop 1

    ping x    = "PING :" `isPrefixOf` x
    pong x    = write "PONG" $ ':' : drop 6 x

eval :: String -> String -> String -> Net ()
eval sender target "!die" = do
    privMsg target "Sure, I'll just DIE then!"
    write "QUIT" ":My death was ordered" >> io (exitWith ExitSuccess)
eval sender target msg
    | "!echo " `isPrefixOf` msg = privMsg target $ drop 6 msg
    | msg =~ regex = do
        let str = regSearch msg
        privMsg target $ "https://github.com/TokTok/" ++ (takeWhile (/= '#') str) ++ "/pull/" ++ (drop 1 (dropWhile (/= '#') str))
        io (putStrLn str)
    | otherwise = return ()

regSearch :: String -> String
regSearch msg = msg =~ regex

privMsg :: String -> String -> Net ()
privMsg to text = write "PRIVMSG" $ to ++ " :" ++ text

write :: String -> String -> Net ()
write string text = do
    io $ printf    "> %s %s\n" string text
    h <- asks socket
    io $ hPrintf h "%s %s\r\n" string text

io :: IO a -> Net a
io = liftIO

-- checkIssue :: String -> Int -> String
-- checkIssue repo num = do
--     possibleIssue <- G.issueR (G.mkOwnerName "TokTok") (G.mkRepoName repo) (G.mkId num)
--     putStrLn $ show $ formatIssue possibleIssue
--     show $ formatIssue possibleIssue

-- formatIssue issue = G.issueUrl issue

--     -- " opened this issue " ++
--     -- (show $ GitHub.issueCreatedAt issue) ++ "\n" ++
--     -- (GitHub.issueState issue) ++ " with " ++
--     -- (show $ GitHub.issueComments issue) ++ " comments" ++ "\n\n" ++
--     -- (GitHub.issueTitle issue)