#!/bin/bash -e
# [MPD CONFIG]
PORT=6600;

# [ROFI CONFIG]
ROFI_THEME_PATH="$HOME/.config/rofi/default/rofi-mpd.rasi"
ROFI="rofi -theme $ROFI_THEME_PATH -i -dmenu";

play_song() {
	local TITLE=$1;
	local ALBUM_NAME=$2;
	local ALBUM_ARTIST=$3;

    local SONG_PATH;

    SONG_PATH=$(mpc \
        --port $PORT \
        --format %file% \
        search \
            AlbumArtist "$ALBUM_ARTIST" \
            Album "$ALBUM_NAME" \
            Title "$TITLE");

    mpc --port $PORT insert "$SONG_PATH";
    mpc --port $PORT next; 
    mpc --port $PORT play;
}

play_playlist() {
	local PLAYLIST_NAME=$1

    local OPTIONS;

	OPTIONS=$(printf '%s\n%s\n' \
		"Listen now"                  \
		"Add to current playlist"     \
		| $ROFI -p "Options");

	case $OPTIONS in
		"Listen now")
			mpc --port $PORT clear;
			mpc --port $PORT load "$PLAYLIST_NAME";
			mpc --port $PORT play;
			;;
		"Add to current playlist")
			mpc --port $PORT load "$PLAYLIST_NAME"
			;;
	esac
}

list_by_playlist() {
    local PLAYLIST;
    local ERROR_MESSAGE;

	PLAYLIST=$(mpc --port $PORT lsplaylist | $ROFI -p "Search");

	if [ -z "$PLAYLIST" ]; then
        ERROR_MESSAGE=""
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

	play_playlist "$PLAYLIST"
}

list_current_playlist() {
    local TITLE;
    local ERROR_MESSAGE;

	TITLE=$(mpc \
        --port $PORT \
        --format "[%position%. %title%]" \
        playlist \
        | $ROFI -p "Search" \
        | grep -Po "(?<=\d\. ).*");

	if [ -z "$TITLE" ]; then
        ERROR_MESSAGE="";
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

	mpc --port $PORT searchplay Title "$TITLE";
}

list_all_songs() {
    local TITLE;
    local ERROR_MESSAGE;
    local OPTIONS;

	TITLE=$(mpc --port $PORT list title | $ROFI -p "Search");

	if [ -z "$TITLE" ]; then
        ERROR_MESSAGE=""
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

	OPTIONS=$(printf '%s\n%s\n' \
		"Listen now"            \
		"Add to playlist"       \
		| $ROFI -p "Options");

	case $OPTIONS in
		"Listen now") play_song "$TITLE";;
		"Add to playlist") mpc --port $PORT findadd title "$TITLE";
	esac
}

list_album_titles() {
	local ALBUM_NAME=$1;
	local ALBUM_ARTIST=$2;

    local TITLE;
    local ERROR_MESSAGE;

    TITLE=$(mpc \
        --port $PORT \
        --format "[%track%. %title%]" \
        search \
            AlbumArtist "$ALBUM_ARTIST" \
            Album "$ALBUM_NAME" \
            | $ROFI -p "Search" \
            | grep -Po "(?<=\d\. ).*");

    if [ -z "$TITLE" ]; then
        ERROR_MESSAGE="No valid title.";
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

    echo "$TITLE"
}

find_add() {
    local ALBUM_NAME=$1;
    local ALBUM_ARTIST=$2;
    local TITLE=$3;

    if [ -n "$ALBUM_ARTIST" ] && [ -n "$ALBUM_NAME" ] && [ -n "$TITLE" ]; then
        mpc --port $PORT findadd Album "$ALBUM_NAME" AlbumArtist "$ALBUM_ARTIST" Title "$TITLE";
    elif [ -n "$ALBUM_ARTIST" ] && [ -n "$ALBUM_NAME" ]; then
        mpc --port $PORT findadd Album "$ALBUM_NAME" AlbumArtist "$ALBUM_ARTIST";
    elif [ -n "$ALBUM_NAME" ]; then
        mpc --port $PORT findadd Album "$ALBUM_NAME";
    fi
}

list_by_album() {
	local ALBUM_ARTIST=$1;

    local TITLE;
    local ALBUM_NAME;
    local ERROR_MESSAGE;
    local EXIST;
    local OPTIONS;

	if [ -z "$ALBUM_ARTIST" ]; then
		ALBUM_NAME=$(mpc --port $PORT list Album | $ROFI -p "Search");
	else
		ALBUM_NAME=$(mpc --port $PORT list album AlbumArtist "$ALBUM_ARTIST" | $ROFI -p "Albums");
	fi

    if [ -z "$ALBUM_NAME" ]; then
        ERROR_MESSAGE=""
        >&2 echo "$ERROR_MESSAGE"
        return 1;
    fi

    EXIST=$(mpc \
        --port $PORT \
        --format %title% \
        search AlbumArtist \
            "$ALBUM_ARTIST"\
            Album "$ALBUM_NAME")

	if [ -z "$EXIST" ]; then
        ERROR_MESSAGE="There is no music by the artist $ALBUM_ARTIST and the album $ALBUM_NAME."
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

	OPTIONS=$(printf '%s\n%s\n%s\n%s' \
		"Listen to the album"         \
		"Listen to a track"           \
		"Add album to playlist"       \
		"Add a track to the playlist" \
		| $ROFI -p "Options");

	case "$OPTIONS" in
		"Listen to the album")
            TITLE=$(list_album_titles "$ALBUM_NAME" "$ALBUM_ARTIST");
            mpc --port $PORT clear;
            find_add "$ALBUM_NAME" "$ALBUM_ARTIST"
			mpc --port $PORT searchplay Title "$TITLE";
			;;
		"Listen to a track")
            TITLE=$(list_album_titles "$ALBUM_NAME" "$ALBUM_ARTIST");
            play_song "$TITLE" "$ALBUM_NAME" "$ALBUM_ARTIST";
			;;
		"Add album to playlist")
            find_add "$ALBUM_NAME" "$ALBUM_ARTIST"
			;;
		"Add a track to the playlist")
            TITLE=$(list_album_titles "$ALBUM_NAME" "$ALBUM_ARTIST");
            find_add "$ALBUM_NAME" "$ALBUM_ARTIST" "$TITLE"
			;;
        *)
            >&2 echo "Please. Select a valid option."
        ;;
	esac
}

list_by_album_artist() {
    local ALBUM_ARTIST;
    local EXIST;

	ALBUM_ARTIST="$(mpc --port $PORT list AlbumArtist | $ROFI -p "Search")";

    if [ -z "$ALBUM_ARTIST" ]; then
        ERROR_MESSAGE=""
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

    EXIST=$(mpc --port $PORT list Album AlbumArtist "$ALBUM_ARTIST");
    if [ -z "$EXIST" ]; then
        ERROR_MESSAGE="You have no music for the given Album-Artist name.";
        >&2 echo "$ERROR_MESSAGE";
        return 1;
    fi

    list_by_album "$ALBUM_ARTIST";
}

MENU=$(
    printf "%s\n%s\n%s\n%s\n%s" \
        "All Songs" \
        "Album Aritst" \
        "Albums" \
        "Playlists" \
        "Current Playlist" \
    | $ROFI -p "Library");

case $MENU in
    "All Songs")
        list_all_songs
        ;;
    "Album Aritst")
        list_by_album_artist
        ;;
    "Albums")
        list_by_album
        ;;
    "Playlists")
        list_by_playlist
        ;;
    "Current Playlist")
        list_current_playlist
        ;;
    *)
        >&2 echo "Please. Select a valid option."
        ;;
esac
