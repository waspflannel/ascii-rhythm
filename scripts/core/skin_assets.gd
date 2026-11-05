class_name SkinAssets
extends RefCounted
## Where the active osu! skin lives. Scripts build every skin path from DIR, so pointing
## it at another skin folder (osu! skins share file names) swaps the art in code.
## Neptune is a dev-only placeholder skin; it is not licensed for release.
# ponytail: scenes (scenes/hit_objects/*, play, hud, main_menu, song_select, results) and
# assets/theme/space_theme.tres still name files under DIR in their ext_resources; a swap
# replaces the folder's files or find-replaces this path there too.

const DIR := "res://assets/skins/neptune/"
const INI := DIR + "skin.ini"
