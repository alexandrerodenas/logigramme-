extends Node
## État du joueur : progression, pièces, expérience, trophées, défi du jour, réglages.
## Tout est enregistré sur l'appareil dans user://progression.json.

signal coins_changed(value: int)
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://progression.json"
const START_COINS := 60

const AIDS := {
	"verify": {"name": "Vérifier", "icon": "check", "cost": 10,
		"desc": "Montre en rouge les cases fausses. Ne coûte pas d'étoile."},
	"loupe": {"name": "Loupe", "icon": "loupe", "cost": 25,
		"desc": "Révèle une bonne association.", "unlock": [0, 3]},
	"eclair": {"name": "Éclair", "icon": "eclair", "cost": 40,
		"desc": "Applique d'un coup tous les indices simples (« est » et « n'est pas »).", "unlock": [0, 8]},
}

const RANKS := [
	[0, "Apprenti"], [120, "Fouineur"], [350, "Détective"], [750, "Inspecteur"],
	[1300, "Commissaire"], [2100, "Légende"],
]

const ACHIEVEMENTS := [
	{"id": "first", "icon": "puzzle", "name": "Premier pas", "desc": "Résoudre une première grille.", "stat": "solved", "goal": 1, "coins": 20},
	{"id": "solved10", "icon": "scroll", "name": "Enquêteur", "desc": "Résoudre 10 grilles.", "stat": "solved", "goal": 10, "coins": 40},
	{"id": "solved40", "icon": "detective", "name": "Fin limier", "desc": "Résoudre 40 grilles.", "stat": "solved", "goal": 40, "coins": 100},
	{"id": "three", "icon": "glow", "name": "Sans faute", "desc": "Obtenir 3 étoiles sur une grille.", "stat": "three_star", "goal": 1, "coins": 20},
	{"id": "three15", "icon": "crown", "name": "Perfectionniste", "desc": "Obtenir 3 étoiles sur 15 grilles.", "stat": "three_star", "goal": 15, "coins": 80},
	{"id": "noaid10", "icon": "target", "name": "Sans filet", "desc": "Résoudre 10 grilles sans aide.", "stat": "no_aid", "goal": 10, "coins": 50},
	{"id": "fast", "icon": "eclair", "name": "Éclair de génie", "desc": "Finir une grille en moins de la moitié du temps.", "stat": "fast", "goal": 1, "coins": 40},
	{"id": "stars50", "icon": "star", "name": "Collectionneur", "desc": "Réunir 50 étoiles.", "stat": "stars", "goal": 50, "coins": 60},
	{"id": "stars150", "icon": "medal", "name": "Constellation", "desc": "Réunir 150 étoiles.", "stat": "stars", "goal": 150, "coins": 150},
	{"id": "boss1", "icon": "crown2", "name": "Tombeur de boss", "desc": "Résoudre une grande énigme de fin de quartier.", "stat": "bosses", "goal": 1, "coins": 50},
	{"id": "boss5", "icon": "crown", "name": "Grand maître", "desc": "Résoudre les 5 grandes énigmes.", "stat": "bosses", "goal": 5, "coins": 200},
	{"id": "flawless", "icon": "heart", "name": "Cœur vaillant", "desc": "Finir un niveau Sans faute sans perdre un seul cœur.", "stat": "flawless", "goal": 1, "coins": 40},
	{"id": "chrono3", "icon": "timer", "name": "Course contre la montre", "desc": "Gagner 3 niveaux Contre-la-montre.", "stat": "chrono", "goal": 3, "coins": 60},
	{"id": "fog3", "icon": "key", "name": "Serrurier", "desc": "Gagner 3 niveaux à indices scellés.", "stat": "fog", "goal": 3, "coins": 60},
	{"id": "daily1", "icon": "calendar", "name": "Rendez-vous", "desc": "Réussir un défi du jour.", "stat": "daily_done", "goal": 1, "coins": 20},
	{"id": "streak3", "icon": "fire", "name": "Habitué", "desc": "Réussir le défi du jour 3 jours de suite.", "stat": "best_streak", "goal": 3, "coins": 50},
	{"id": "streak7", "icon": "fire", "name": "Fidèle", "desc": "Réussir le défi du jour 7 jours de suite.", "stat": "best_streak", "goal": 7, "coins": 120},
	{"id": "world0", "icon": "sunflower", "name": "Main verte", "desc": "Terminer le Jardin.", "stat": "world0", "goal": 1, "coins": 50},
	{"id": "world1", "icon": "coffee", "name": "Barista", "desc": "Terminer le Café.", "stat": "world1", "goal": 1, "coins": 60},
	{"id": "world2", "icon": "anchor", "name": "Capitaine", "desc": "Terminer le Port.", "stat": "world2", "goal": 1, "coins": 70},
	{"id": "world3", "icon": "tent", "name": "Maestro", "desc": "Terminer le Festival.", "stat": "world3", "goal": 1, "coins": 80},
	{"id": "world4", "icon": "telescope", "name": "Astronome", "desc": "Terminer l'Observatoire.", "stat": "world4", "goal": 1, "coins": 100},
]

var data := {}


func _ready() -> void:
	_load()


func _default() -> Dictionary:
	return {
		"version": 2, "coins": START_COINS, "xp": 0,
		"levels": {}, "current": {},
		"daily": {"last": "", "streak": 0},
		"stats": {"solved": 0, "three_star": 0, "no_aid": 0, "fast": 0, "daily_done": 0, "best_streak": 0},
		"achievements": {},
		"settings": {"sound": true, "music": true, "vibration": true},
		"tutorial": false, "seen_aids": {}, "seen_worlds": {"0": true}, "seen_intros": {},
	}


func _load() -> void:
	data = _default()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary and int(parsed.get("version", 0)) == 2:
		for k in parsed:
			if data.has(k) and typeof(data[k]) == TYPE_DICTIONARY and parsed[k] is Dictionary:
				data[k].merge(parsed[k], true)
			else:
				data[k] = parsed[k]


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func reset() -> void:
	data = _default()
	save()
	coins_changed.emit(coins())


# --- Pièces -------------------------------------------------------------------

func coins() -> int:
	return int(data.coins)


func add_coins(n: int) -> void:
	data.coins = coins() + n
	save()
	coins_changed.emit(coins())


func spend(n: int) -> bool:
	if coins() < n:
		return false
	data.coins = coins() - n
	save()
	coins_changed.emit(coins())
	return true


# --- Niveaux ------------------------------------------------------------------

static func level_key(w: int, l: int) -> String:
	return "%d-%d" % [w, l]


func level_stars(w: int, l: int) -> int:
	var rec = data.levels.get(level_key(w, l))
	return int(rec.stars) if rec is Dictionary else 0


func is_solved(w: int, l: int) -> bool:
	return data.levels.has(level_key(w, l))


func total_stars() -> int:
	var t := 0
	for k in data.levels:
		t += int(data.levels[k].stars)
	return t


func world_stars(w: int) -> int:
	var t := 0
	for l in range(1, Worlds.LEVELS_PER_WORLD + 1):
		t += level_stars(w, l)
	return t


func world_done(w: int) -> bool:
	return is_solved(w, Worlds.LEVELS_PER_WORLD)


func is_world_unlocked(w: int) -> bool:
	if w == 0:
		return true
	return world_done(w - 1) and total_stars() >= int(Worlds.WORLDS[w].stars_needed)


func is_level_unlocked(w: int, l: int) -> bool:
	if not is_world_unlocked(w):
		return false
	return l == 1 or is_solved(w, l - 1)


## Le prochain niveau à jouer : [monde, niveau].
func next_level() -> Array:
	for w in Worlds.world_count():
		if not is_world_unlocked(w):
			break
		for l in range(1, Worlds.LEVELS_PER_WORLD + 1):
			if not is_solved(w, l):
				return [w, l]
	for w in range(Worlds.world_count() - 1, -1, -1):
		if is_world_unlocked(w):
			return [w, Worlds.LEVELS_PER_WORLD]
	return [0, 1]


func is_aid_unlocked(id: String) -> bool:
	var u = AIDS[id].get("unlock")
	if u == null:
		return true
	return is_solved(u[0], u[1])


## Temps de référence (en secondes) pour la troisième étoile.
static func par_time(pz: Dictionary) -> int:
	var cells: int = (pz.n_cats * (pz.n_cats - 1) / 2) * pz.items * pz.items
	return 40 + pz.clues.size() * 14 + cells


# --- Partie en cours ----------------------------------------------------------

func get_current(key: String) -> Dictionary:
	var c = data.current.get(key)
	return c if c is Dictionary else {}


func set_current(key: String, state: Dictionary) -> void:
	data.current[key] = state
	save()


# --- Fin de grille ------------------------------------------------------------

## Enregistre une grille résolue et renvoie le détail des récompenses.
func complete(cfg: Dictionary, time_s: float, used_aid: bool, par: int, extra: Dictionary = {}) -> Dictionary:
	var stars := 1
	if not used_aid:
		stars += 1
	if time_s <= par:
		stars += 1
	var r := {"stars": stars, "coins": 0, "xp": 0, "chest": 0, "time": time_s, "par": par,
		"no_aid": not used_aid, "fast": time_s <= par, "new_aids": [], "achievements": [],
		"rank_before": rank_index(), "world_unlocked": -1, "first": false, "streak": 0, "mod_bonus": 0}
	var aids_before := {}
	for id in AIDS:
		aids_before[id] = is_aid_unlocked(id)
	var worlds_before := []
	for w in Worlds.world_count():
		worlds_before.append(is_world_unlocked(w))

	var st: Dictionary = data.stats
	if cfg.get("daily", false):
		var today := today_string()
		data.current.erase("daily-" + today)
		if data.daily.last != today:
			var streak := int(data.daily.streak) + 1 if data.daily.last == yesterday_string() else 1
			data.daily.last = today
			data.daily.streak = streak
			st.best_streak = max(int(st.best_streak), streak)
			st.daily_done = int(st.daily_done) + 1
			r.streak = streak
			r.coins += 40 + 10 * min(streak - 1, 4)
			r.xp += 40
			r.first = true
	else:
		var w: int = cfg.world
		var l: int = cfg.level
		var key := level_key(w, l)
		data.current.erase(key)
		var prev := level_stars(w, l)
		if not is_solved(w, l):
			r.first = true
			r.coins += 10 + 5 * stars
			r.xp += 20 + 10 * stars
			if l % Worlds.CHEST_EVERY == 0:
				r.chest = 40 + 20 * w + (60 if cfg.get("boss", false) else 0)
				r.coins += r.chest
			r.mod_bonus = 15 * cfg.get("mods", []).size()
			r.coins += r.mod_bonus
			data.levels[key] = {"stars": stars, "time": time_s}
		else:
			r.coins += 3 + 5 * max(0, stars - prev)
			r.xp += 5 + 10 * max(0, stars - prev)
			var rec: Dictionary = data.levels[key]
			rec.stars = max(prev, stars)
			rec.time = min(float(rec.time), time_s)
		if l == Worlds.LEVELS_PER_WORLD:
			st["world%d" % w] = 1

	st.solved = int(st.solved) + 1
	if stars == 3:
		st.three_star = int(st.three_star) + 1
	if not used_aid:
		st.no_aid = int(st.no_aid) + 1
	if time_s <= par * 0.5:
		st.fast = int(st.fast) + 1
	st.stars = total_stars()
	var mods: Array = cfg.get("mods", [])
	if cfg.get("boss", false):
		st.bosses = int(st.get("bosses", 0)) + 1
	if mods.has("hearts") and int(extra.get("hearts_lost", 1)) == 0:
		st.flawless = int(st.get("flawless", 0)) + 1
	if mods.has("chrono"):
		st.chrono = int(st.get("chrono", 0)) + 1
	if mods.has("fog"):
		st.fog = int(st.get("fog", 0)) + 1

	data.coins = coins() + r.coins
	data.xp = int(data.xp) + r.xp
	for a in ACHIEVEMENTS:
		if not data.achievements.has(a.id) and int(st.get(a.stat, 0)) >= int(a.goal):
			data.achievements[a.id] = true
			data.coins = coins() + int(a.coins)
			r.achievements.append(a)
	for id in AIDS:
		if not aids_before[id] and is_aid_unlocked(id):
			r.new_aids.append(id)
	for w in Worlds.world_count():
		if not worlds_before[w] and is_world_unlocked(w):
			r.world_unlocked = w
	r.rank_after = rank_index()
	save()
	coins_changed.emit(coins())
	return r


func stat(id: String) -> int:
	if id == "stars":
		return total_stars()
	return int(data.stats.get(id, 0))


# --- Rang ---------------------------------------------------------------------

func xp() -> int:
	return int(data.xp)


func rank_index() -> int:
	var idx := 0
	for i in RANKS.size():
		if xp() >= int(RANKS[i][0]):
			idx = i
	return idx


func rank_name(i: int = -1) -> String:
	return RANKS[rank_index() if i < 0 else i][1]


## Progression vers le rang suivant, entre 0 et 1.
func rank_progress() -> float:
	var i := rank_index()
	if i >= RANKS.size() - 1:
		return 1.0
	var lo: int = RANKS[i][0]
	var hi: int = RANKS[i + 1][0]
	return float(xp() - lo) / float(hi - lo)


# --- Défi du jour -------------------------------------------------------------

static func today_string() -> String:
	return Time.get_date_string_from_system()


static func yesterday_string() -> String:
	var t := Time.get_unix_time_from_datetime_string(today_string()) - 86400
	return Time.get_date_string_from_unix_time(t)


func daily_done_today() -> bool:
	return data.daily.last == today_string()


func daily_streak() -> int:
	var last: String = data.daily.last
	if last == today_string() or last == yesterday_string():
		return int(data.daily.streak)
	return 0


# --- Réglages -----------------------------------------------------------------

func setting(id: String) -> bool:
	return bool(data.settings.get(id, true))


func set_setting(id: String, v: bool) -> void:
	data.settings[id] = v
	save()
