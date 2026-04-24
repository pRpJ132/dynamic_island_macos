tell application "Music"
            try
                set t to current track
                set trackName to name of t
                set trackArtist to artist of t
                return trackName & "||" & trackArtist
            on error
                return ""
            end try
        end tell