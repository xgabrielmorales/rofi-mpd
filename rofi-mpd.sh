#!/usr/bin/bash
# [MPD CONFIG]
PORT=6600;

# [ROFI CONFIG]
ROFI="rofi -i -dmenu -p Search";
ROFI_MENU="rofi -i -dmenu -p ";

play_song() {
	TITLE=$1;
	ALBUM_NAME=$2;
	ARTIST_NAME=$3;

	if [[ -z $ARTIST_NAME && -z $ALBUM_NAME ]]; then
		SONG_PATH=$(mpc --port $PORT find Title "$TITLE");
	elif [ -z $ARTIST_NAME ]; then
		SONG_PATH=$(mpc --port $PORT find Album "$ALBUM_NAME" Title "$TITLE");
	else
		SONG_PATH=$(mpc --port $PORT find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" Title "$TITLE");
	fi

	# If the playlist is empty, just add the song and play it
	if [ "$(mpc --port $PORT playlist | wc -l)" = "0" ]; then
		mpc --port $PORT add "$SONG_PATH";
		mpc --port $PORT play;

	# If there is at least one song in the playlist, add it in front of it and play it.
	else
		CURRENT_POSITION=$(mpc --port $PORT status | sed -n '2{p;q}' | awk '{print $2}' | sed -E 's/(#|\/.*)//g');
		END_POSITION=$(mpc --port $PORT playlist | wc -l);

		mpc --port $PORT add "$SONG_PATH";
		mpc --port $PORT move $(($END_POSITION+1)) $(($CURRENT_POSITION+1));
		mpc --port $PORT play $(($CURRENT_POSITION+1));
	fi
}

play_playlist() {
	PLAYLIST_NAME=$1

	OPTIONS=$(printf '%s\n%s\n%s\n%s' \
		"Listen now"                  \
		"Add to current playlist"     \
		| $ROFI_MENU "Options");

	if [ "$OPTIONS" = "Listen now" ]; then
		mpc --port $PORT clear
		mpc --port $PORT load "$PLAYLIST_NAME"
		mpc --port $PORT play
	elif [ "$OPTIONS" = "Add to current playlist" ]; then
		mpc --port $PORT load "$PLAYLIST_NAME"
	else
		exit;
	fi

}

list_by_playlist() {
	PLAYLIST=$(mpc --port $PORT lsplaylist | $ROFI);

	[[ -z $PLAYLIST ]] && exit;

	play_playlist $PLAYLIST
}

list_all_songs() {
	TITLE=$(mpc --port $PORT list title | $ROFI);

	[[ -z $TITLE ]] && exit;

	OPTIONS=$(printf '%s\n%s\n%s\n%s' \
		"Listen now"                  \
		"Add to playlist"             \
		| $ROFI_MENU "Options");

	if [ "$OPTIONS" = "Listen now" ]; then
		play_song "$TITLE";
	elif [ "$OPTIONS" = "Add to playlist" ]; then
		mpc --port $PORT find title "$TITLE" | mpc --port $PORT add;
	else
		exit;
	fi
}

list_album_titles() {
	ALBUM_NAME=$1;
	ARTIST_NAME=$2;

	if [ -z $ARTIST_NAME ]; then
		TITLE=$(mpc --port "$PORT" --format %title% find Album "$ALBUM_NAME" | $ROFI);
	else
		TITLE=$(mpc --port "$PORT" --format %title% find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" | $ROFI);
	fi

	[[ -z $TITLE ]] && exit;

	play_song "$TITLE" "$ALBUM_NAME" "$ARTIST_NAME";
}

list_by_album() {
	ARTIST_NAME=$1;

	if [ -z $ARTIST_NAME ]; then
		ALBUM_NAME=$(mpc --port $PORT list Album | $ROFI -p "Search");
	else
		ALBUM_NAME=$(mpc --port $PORT list album AlbumArtist "$ARTIST_NAME" | $ROFI -p "Albums");
	fi

	[[ -z $ALBUM_NAME ]] && exit;

	OPTIONS=$(printf '%s\n%s\n%s\n%s' \
		"Listen to the album"         \
		"Listen to a track"           \
		"Add album to playlist"       \
		"Add a track to the playlist" \
		| $ROFI_MENU "Options");

	if [ "$OPTIONS" = "Listen to the album" ]; then
		mpc --port $PORT clear;

		if [ "$ARTIST_NAME" = "" ]; then
			mpc --port $PORT find Album "$ALBUM_NAME" | mpc --port $PORT add;
		else
			mpc --port $PORT find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" | mpc --port $PORT add;
		fi

		mpc --port $PORT play;
	elif [ "$OPTIONS" = "Listen to a track" ]; then
		list_album_titles "$ALBUM_NAME" "$ARTIST_NAME";
	elif [ "$OPTIONS" = "Add album to playlist" ]; then
		if [ "$ARTIST_NAME" = "" ]; then
			mpc --port $PORT find Album "$ALBUM_NAME" | mpc --port $PORT add;
		else
			mpc --port $PORT find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" | mpc --port $PORT add;
		fi
	elif [ "$OPTIONS" = "Add a track to the playlist" ]; then

		if [ "$ARTIST_NAME" = "" ]; then
			echo $ALBUM_NAME
			TITLE=$(mpc --port $PORT --format %title% find Album "$ALBUM_NAME" | $ROFI);
			SONG_PATH=$(mpc --port $PORT find Album "$ALBUM_NAME" Title "$TITLE");
		else
			TITLE=$(mpc --port $PORT --format %title% find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" | $ROFI);
			SONG_PATH=$(mpc --port $PORT find AlbumArtist "$ARTIST_NAME" Album "$ALBUM_NAME" Title "$TITLE");
		fi

		mpc --port $PORT add "$SONG_PATH";
	else
		exit;
	fi
}

list_by_album_artist() {
	ARTIST_NAME="$(mpc --port $PORT list AlbumArtist | $ROFI -p "Search")";

	[[ -z $ARTIST_NAME ]] && exit;

	list_by_album "$ARTIST_NAME";
}

MENU=$(printf "%s\n%s\n%s\n%s\n" \
	"All Songs"                  \
	"Album Aritst"               \
	"Album"                      \
	"Playlist"                   \
	| $ROFI_MENU "Library");

if [ "$MENU" = "Album Aritst" ]; then
	list_by_album_artist;
elif [ "$MENU" = "Album" ]; then
	list_by_album;
elif [ "$MENU" = "All Songs" ]; then
	list_all_songs;
elif [ "$MENU" = "Playlist" ]; then
	list_by_playlist;
fi
