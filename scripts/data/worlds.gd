class_name Worlds
extends RefCounted
## Les mondes du parcours, leurs catégories thématiques et la courbe de difficulté.
## Chaque valeur de catégorie : [icône, libellé court, prédicat, prédicat négatif].

const LEVELS_PER_WORLD := 8
const CHEST_EVERY := 4

const NAMES := ["Léa", "Hugo", "Chloé", "Louis", "Emma", "Jules", "Inès", "Lucas", "Manon",
	"Nathan", "Camille", "Théo", "Zoé", "Arthur", "Jade", "Paul", "Alice", "Tom", "Lina", "Noé"]
const AVATAR_COLORS := ["#ff7a59", "#5cc9a7", "#6ec3f4", "#a78bfa", "#ffc93c", "#f472b6"]

## Modificateurs des niveaux spéciaux.
const MODS := {
	"hearts": {"icon": "heart", "name": "Sans faute", "color": "#f0507a",
		"desc": "3 cœurs : chaque grille validée avec une erreur en coûte un."},
	"chrono": {"icon": "timer", "name": "Contre-la-montre", "color": "#f59e0b",
		"desc": "Le temps est compté : finis avant la fin du sablier."},
	"fog": {"icon": "key", "name": "Indices scellés", "color": "#7c6cf0",
		"desc": "Certains indices sont sous scellés. Chaque bonne pastille te donne une clé pour en ouvrir un."},
}

## Niveaux spéciaux de chaque quartier : niveau -> modificateurs. Le dernier niveau est toujours la grande énigme.
const SPECIAL := [
	{5: ["hearts"]},
	{4: ["chrono"]},
	{3: ["fog"], 6: ["hearts"]},
	{3: ["chrono"], 6: ["fog"]},
	{2: ["hearts"], 5: ["chrono"]},
	{3: ["fog"], 6: ["hearts"]},
	{2: ["chrono"], 5: ["fog"], 7: ["hearts"]},
	{3: ["hearts", "chrono"], 6: ["fog"]},
	{2: ["fog"], 4: ["chrono"], 6: ["hearts", "fog"]},
	{2: ["chrono"], 4: ["fog", "hearts"], 6: ["chrono", "fog"]},
]
const BOSS_MODS := [["hearts"], ["chrono"], ["fog"], ["hearts"], ["chrono"], ["fog"], ["hearts"],
	["hearts", "chrono"], ["fog", "chrono"], ["hearts", "fog"]]
const BOSS_SIZE := [[4, 4], [4, 4], [4, 4], [4, 5], [4, 5], [5, 4], [5, 4], [5, 4], [5, 4], [5, 4]]

## Nouveaux types d'indices, présentés la première fois qu'ils apparaissent.
const CLUE_INTROS := {
	"pair": {"icon": "puzzle", "title": "Nouvel indice : « Parmi… »",
		"text": "« Parmi Léa et la personne au chien, l'une boit du thé et l'autre du café » : ce sont deux personnes différentes, et chacune a l'une des deux valeurs."},
	"street": {"icon": "house", "title": "Nouvelle catégorie : la rue",
		"text": "Les maisons sont numérotées de gauche à droite. « À gauche de » veut dire un numéro plus petit, « à côté de » un numéro voisin."},
}

const CATS := {
	"animal": {"name": "Animal", "icon": "cat", "values": [
		["cat", "chat", "a un chat", "n'a pas de chat"],
		["dog", "chien", "a un chien", "n'a pas de chien"],
		["rabbit", "lapin", "a un lapin", "n'a pas de lapin"],
		["hamster", "hamster", "a un hamster", "n'a pas de hamster"],
		["parrot", "perroquet", "a un perroquet", "n'a pas de perroquet"],
		["turtle", "tortue", "a une tortue", "n'a pas de tortue"]]},
	"fleur": {"name": "Fleur", "icon": "tulip", "values": [
		["sunflower", "tournesol", "cultive des tournesols", "ne cultive pas de tournesols"],
		["tulip", "tulipe", "cultive des tulipes", "ne cultive pas de tulipes"],
		["rose", "rose", "cultive des roses", "ne cultive pas de roses"],
		["daisy", "marguerite", "cultive des marguerites", "ne cultive pas de marguerites"],
		["blossom", "cerisier", "cultive un cerisier", "ne cultive pas de cerisier"],
		["hyacinth", "jacinthe", "cultive des jacinthes", "ne cultive pas de jacinthes"]]},
	"legume": {"name": "Légume", "icon": "carrot", "values": [
		["carrot", "carotte", "plante des carottes", "ne plante pas de carottes"],
		["tomato", "tomate", "plante des tomates", "ne plante pas de tomates"],
		["cucumber", "concombre", "plante des concombres", "ne plante pas de concombres"],
		["corn", "maïs", "plante du maïs", "ne plante pas de maïs"],
		["potato", "patate", "plante des pommes de terre", "ne plante pas de pommes de terre"],
		["pumpkin", "citrouille", "plante des citrouilles", "ne plante pas de citrouilles"]]},
	"boisson": {"name": "Boisson", "icon": "coffee", "values": [
		["coffee", "café", "commande un café", "ne commande pas de café"],
		["tea", "thé", "commande un thé", "ne commande pas de thé"],
		["juice", "jus", "commande un jus de fruits", "ne commande pas de jus de fruits"],
		["milk", "lait", "commande un verre de lait", "ne commande pas de lait"],
		["lemon", "limonade", "commande une limonade", "ne commande pas de limonade"],
		["bubbletea", "bubble tea", "commande un bubble tea", "ne commande pas de bubble tea"]]},
	"dessert": {"name": "Dessert", "icon": "cake", "values": [
		["cake", "fraisier", "choisit le fraisier", "ne choisit pas le fraisier"],
		["donut", "beignet", "choisit le beignet", "ne choisit pas le beignet"],
		["croissant", "croissant", "choisit le croissant", "ne choisit pas le croissant"],
		["cookie", "cookie", "choisit le cookie", "ne choisit pas le cookie"],
		["cupcake", "cupcake", "choisit le cupcake", "ne choisit pas le cupcake"],
		["flan", "flan", "choisit le flan", "ne choisit pas le flan"]]},
	"fruit": {"name": "Fruit", "icon": "apple", "values": [
		["apple", "pomme", "adore les pommes", "n'aime pas les pommes"],
		["banana", "banane", "adore les bananes", "n'aime pas les bananes"],
		["strawberry", "fraise", "adore les fraises", "n'aime pas les fraises"],
		["grapes", "raisin", "adore le raisin", "n'aime pas le raisin"],
		["cherries", "cerise", "adore les cerises", "n'aime pas les cerises"],
		["pear", "poire", "adore les poires", "n'aime pas les poires"]]},
	"bateau": {"name": "Bateau", "icon": "sailboat", "values": [
		["sailboat", "voilier", "navigue en voilier", "ne navigue pas en voilier"],
		["speedboat", "hors-bord", "navigue en hors-bord", "ne navigue pas en hors-bord"],
		["canoe", "canoë", "navigue en canoë", "ne navigue pas en canoë"],
		["ship", "paquebot", "navigue en paquebot", "ne navigue pas en paquebot"],
		["ferry", "ferry", "navigue en ferry", "ne navigue pas en ferry"],
		["yacht", "yacht", "navigue en yacht", "ne navigue pas en yacht"]]},
	"marin": {"name": "Rencontre", "icon": "dolphin", "values": [
		["dolphin", "dauphin", "a croisé un dauphin", "n'a pas croisé de dauphin"],
		["fish", "poisson", "a croisé un banc de poissons", "n'a pas croisé de poissons"],
		["octopus", "pieuvre", "a croisé une pieuvre", "n'a pas croisé de pieuvre"],
		["crab", "crabe", "a croisé un crabe", "n'a pas croisé de crabe"],
		["whale", "baleine", "a croisé une baleine", "n'a pas croisé de baleine"],
		["seal", "phoque", "a croisé un phoque", "n'a pas croisé de phoque"]]},
	"maison": {"name": "Maison", "icon": "house", "values": [
		["red", "rouge", "habite la maison rouge", "n'habite pas la maison rouge"],
		["blue", "bleue", "habite la maison bleue", "n'habite pas la maison bleue"],
		["green", "verte", "habite la maison verte", "n'habite pas la maison verte"],
		["yellow", "jaune", "habite la maison jaune", "n'habite pas la maison jaune"],
		["purple", "violette", "habite la maison violette", "n'habite pas la maison violette"],
		["orange", "orange", "habite la maison orange", "n'habite pas la maison orange"]]},
	"instrument": {"name": "Instrument", "icon": "guitar", "values": [
		["piano", "piano", "joue du piano", "ne joue pas du piano"],
		["guitar", "guitare", "joue de la guitare", "ne joue pas de la guitare"],
		["violin", "violon", "joue du violon", "ne joue pas du violon"],
		["drum", "batterie", "joue de la batterie", "ne joue pas de la batterie"],
		["trumpet", "trompette", "joue de la trompette", "ne joue pas de la trompette"],
		["accordion", "accordéon", "joue de l'accordéon", "ne joue pas de l'accordéon"]]},
	"sport": {"name": "Sport", "icon": "soccer", "values": [
		["tennis", "tennis", "fait du tennis", "ne fait pas de tennis"],
		["soccer", "football", "fait du football", "ne fait pas de football"],
		["bike", "cyclisme", "fait du vélo", "ne fait pas de vélo"],
		["swim", "natation", "fait de la natation", "ne fait pas de natation"],
		["judo", "judo", "fait du judo", "ne fait pas de judo"],
		["ski", "ski", "fait du ski", "ne fait pas de ski"]]},
	"chapeau": {"name": "Chapeau", "icon": "tophat", "values": [
		["tophat", "haut-forme", "porte le haut-de-forme", "ne porte pas le haut-de-forme"],
		["strawhat", "capeline", "porte la capeline", "ne porte pas la capeline"],
		["cap", "casquette", "porte la casquette", "ne porte pas la casquette"],
		["crown2", "couronne", "porte la couronne", "ne porte pas la couronne"],
		["gradcap", "mortier", "porte le mortier", "ne porte pas le mortier"],
		["helmet", "casque", "porte le casque", "ne porte pas le casque"]]},
	"astre": {"name": "Astre", "icon": "saturn", "values": [
		["moon", "Lune", "observe la Lune", "n'observe pas la Lune"],
		["sun", "Soleil", "observe le Soleil", "n'observe pas le Soleil"],
		["saturn", "Saturne", "observe Saturne", "n'observe pas Saturne"],
		["comet", "comète", "observe la comète", "n'observe pas la comète"],
		["earth", "Terre", "observe la Terre depuis l'ISS", "n'observe pas la Terre"],
		["starfield", "filante", "guette les étoiles filantes", "ne guette pas les étoiles filantes"]]},
	"transport": {"name": "Transport", "icon": "train", "values": [
		["bicycle", "vélo", "vient à vélo", "ne vient pas à vélo"],
		["car", "voiture", "vient en voiture", "ne vient pas en voiture"],
		["bus", "bus", "vient en bus", "ne vient pas en bus"],
		["train", "train", "vient en train", "ne vient pas en train"],
		["plane", "avion", "vient en avion", "ne vient pas en avion"],
		["scooter", "trottinette", "vient en trottinette", "ne vient pas en trottinette"]]},
	"ferme": {"name": "Animal", "icon": "cow", "values": [
		["cow", "vache", "élève des vaches", "n'élève pas de vaches"],
		["pig", "cochon", "élève des cochons", "n'élève pas de cochons"],
		["sheep", "mouton", "élève des moutons", "n'élève pas de moutons"],
		["chicken", "poule", "élève des poules", "n'élève pas de poules"],
		["horse", "cheval", "élève des chevaux", "n'élève pas de chevaux"],
		["goat", "chèvre", "élève des chèvres", "n'élève pas de chèvres"]]},
	"produit": {"name": "Produit", "icon": "cheese", "values": [
		["cheese", "fromage", "vend du fromage", "ne vend pas de fromage"],
		["egg", "œufs", "vend des œufs", "ne vend pas d'œufs"],
		["honey", "miel", "vend du miel", "ne vend pas de miel"],
		["bread", "pain", "vend du pain", "ne vend pas de pain"],
		["milk", "lait", "vend du lait", "ne vend pas de lait"],
		["butter", "beurre", "vend du beurre", "ne vend pas de beurre"]]},
	"outil": {"name": "Outil", "icon": "basket", "values": [
		["basket", "panier", "porte un panier", "ne porte pas de panier"],
		["bucket", "seau", "porte un seau", "ne porte pas de seau"],
		["axe", "hache", "porte une hache", "ne porte pas de hache"],
		["gloves", "gants", "porte des gants", "ne porte pas de gants"],
		["broom", "balai", "porte un balai", "ne porte pas de balai"],
		["scissors", "ciseaux", "porte des ciseaux", "ne porte pas de ciseaux"]]},
	"plage": {"name": "Activité", "icon": "kite", "values": [
		["volley", "volley", "joue au volley", "ne joue pas au volley"],
		["kite", "cerf-volant", "fait du cerf-volant", "ne fait pas de cerf-volant"],
		["surf", "surf", "fait du surf", "ne fait pas de surf"],
		["diving", "plongée", "fait de la plongée", "ne fait pas de plongée"],
		["fishing", "pêche", "va à la pêche", "ne va pas à la pêche"],
		["swim", "nage", "nage au large", "ne nage pas au large"]]},
	"gouter": {"name": "Goûter", "icon": "icecream", "values": [
		["icecream", "glace", "mange une glace", "ne mange pas de glace"],
		["watermelon", "pastèque", "mange de la pastèque", "ne mange pas de pastèque"],
		["hotdog", "hot-dog", "mange un hot-dog", "ne mange pas de hot-dog"],
		["popcorn", "pop-corn", "mange du pop-corn", "ne mange pas de pop-corn"],
		["sandwich", "sandwich", "mange un sandwich", "ne mange pas de sandwich"],
		["granita", "granité", "mange un granité", "ne mange pas de granité"]]},
	"affaire": {"name": "Affaire", "icon": "parasol", "values": [
		["sunglasses", "lunettes", "a des lunettes de soleil", "n'a pas de lunettes de soleil"],
		["thongs", "tongs", "porte des tongs", "ne porte pas de tongs"],
		["parasol", "parasol", "a un parasol", "n'a pas de parasol"],
		["lotion", "crème", "a de la crème solaire", "n'a pas de crème solaire"],
		["bucket", "seau", "a un seau", "n'a pas de seau"],
		["strawhat", "chapeau", "porte un chapeau de paille", "ne porte pas de chapeau de paille"]]},
	"sauvage": {"name": "Animal", "icon": "fox", "values": [
		["fox", "renard", "a vu un renard", "n'a pas vu de renard"],
		["deer", "cerf", "a vu un cerf", "n'a pas vu de cerf"],
		["owl", "hibou", "a vu un hibou", "n'a pas vu de hibou"],
		["hedgehog", "hérisson", "a vu un hérisson", "n'a pas vu de hérisson"],
		["squirrel", "écureuil", "a vu un écureuil", "n'a pas vu d'écureuil"],
		["bear", "ours", "a vu un ours", "n'a pas vu d'ours"]]},
	"cueillette": {"name": "Cueillette", "icon": "mushroom", "values": [
		["mushroom", "champignons", "cueille des champignons", "ne cueille pas de champignons"],
		["chestnut", "châtaignes", "ramasse des châtaignes", "ne ramasse pas de châtaignes"],
		["blueberry", "myrtilles", "cueille des myrtilles", "ne cueille pas de myrtilles"],
		["strawberry", "fraises", "cueille des fraises des bois", "ne cueille pas de fraises des bois"],
		["herb", "herbes", "cueille des herbes", "ne cueille pas d'herbes"],
		["leaves", "feuilles", "ramasse des feuilles", "ne ramasse pas de feuilles"]]},
	"equipement": {"name": "Équipement", "icon": "backpack", "values": [
		["flashlight", "lampe", "a une lampe", "n'a pas de lampe"],
		["compass", "boussole", "a une boussole", "n'a pas de boussole"],
		["map", "carte", "a une carte", "n'a pas de carte"],
		["backpack", "sac", "a un sac à dos", "n'a pas de sac à dos"],
		["rope", "corde", "a une corde", "n'a pas de corde"],
		["log", "bûche", "porte une bûche", "ne porte pas de bûche"]]},
	"hiver": {"name": "Activité", "icon": "ski", "values": [
		["ski", "ski", "fait du ski", "ne fait pas de ski"],
		["snowboard", "snowboard", "fait du snowboard", "ne fait pas de snowboard"],
		["sled", "luge", "fait de la luge", "ne fait pas de luge"],
		["skate", "patin", "fait du patin", "ne fait pas de patin"],
		["climb", "escalade", "fait de l'escalade", "ne fait pas d'escalade"],
		["hiking", "randonnée", "fait de la randonnée", "ne fait pas de randonnée"]]},
	"plat": {"name": "Plat", "icon": "fondue", "values": [
		["fondue", "fondue", "mange une fondue", "ne mange pas de fondue"],
		["soup", "soupe", "mange une soupe", "ne mange pas de soupe"],
		["pretzel", "bretzel", "mange un bretzel", "ne mange pas de bretzel"],
		["chocolate", "chocolat", "boit un chocolat chaud", "ne boit pas de chocolat chaud"],
		["waffle", "gaufre", "mange une gaufre", "ne mange pas de gaufre"],
		["pancakes", "crêpes", "mange des crêpes", "ne mange pas de crêpes"]]},
	"tenue": {"name": "Tenue", "icon": "scarf", "values": [
		["scarf", "écharpe", "porte une écharpe", "ne porte pas d'écharpe"],
		["gloves", "gants", "porte des gants", "ne porte pas de gants"],
		["cap", "casquette", "porte une casquette", "ne porte pas de casquette"],
		["goggles", "masque", "porte un masque de ski", "ne porte pas de masque de ski"],
		["coat", "manteau", "porte un manteau", "ne porte pas de manteau"],
		["boots", "bottes", "porte des bottes", "ne porte pas de bottes"]]},
	"jouet": {"name": "Jouet", "icon": "teddy", "values": [
		["teddy", "nounours", "garde un nounours", "ne garde pas de nounours"],
		["yoyo", "yo-yo", "garde un yo-yo", "ne garde pas de yo-yo"],
		["dice", "dés", "garde des dés", "ne garde pas de dés"],
		["puzzle", "puzzle", "garde un puzzle", "ne garde pas de puzzle"],
		["robot", "robot", "garde un robot", "ne garde pas de robot"],
		["doll", "poupée", "garde une poupée russe", "ne garde pas de poupée russe"]]},
	"loisir": {"name": "Loisir", "icon": "palette", "values": [
		["palette", "peinture", "fait de la peinture", "ne fait pas de peinture"],
		["yarn", "tricot", "tricote", "ne tricote pas"],
		["books", "lecture", "lit des romans", "ne lit pas de romans"],
		["chess", "échecs", "joue aux échecs", "ne joue pas aux échecs"],
		["sewing", "couture", "fait de la couture", "ne fait pas de couture"],
		["camera", "photo", "fait de la photo", "ne fait pas de photo"]]},
	"trouvaille": {"name": "Trouvaille", "icon": "oldkey", "values": [
		["clock", "horloge", "a trouvé une horloge", "n'a pas trouvé d'horloge"],
		["letter", "lettre", "a trouvé une lettre", "n'a pas trouvé de lettre"],
		["oldkey", "clé", "a trouvé une vieille clé", "n'a pas trouvé de vieille clé"],
		["radio", "radio", "a trouvé une radio", "n'a pas trouvé de radio"],
		["crystal", "boule", "a trouvé une boule de cristal", "n'a pas trouvé de boule de cristal"],
		["mirror", "miroir", "a trouvé un miroir", "n'a pas trouvé de miroir"]]},
}

const WORLDS := [
	{"id": "jardin", "name": "Le Jardin", "icon": "sunflower", "tagline": "Premiers pas parmi les fleurs",
		"cats": ["animal", "fleur", "legume"], "ordered": [], "ordered_chance": 0.0, "pair": false, "stars_needed": 0,
		"sky": "#bfe8a8", "ground": "#f4f0d0", "accent": "#4fa35a", "path": "#e8c98a",
		"decor": ["tree", "sunflower", "butterfly", "bee", "mushroom", "herb", "tulip", "pine"],
		"trophy": "Main verte"},
	{"id": "ferme", "name": "La Ferme", "icon": "tractor", "tagline": "Bottes, foin et bonne humeur",
		"cats": ["ferme", "produit", "outil"], "ordered": [], "ordered_chance": 0.0, "pair": false, "stars_needed": 10,
		"sky": "#d6ec9f", "ground": "#f7efd2", "accent": "#c4572f", "path": "#e2bf7c",
		"decor": ["cow", "pig", "sheep", "chicken", "tractor", "barn", "corn", "egg"],
		"trophy": "Fermier"},
	{"id": "cafe", "name": "Le Café", "icon": "coffee", "tagline": "Commandes et gourmandises",
		"cats": ["boisson", "dessert", "fruit"], "ordered": [], "ordered_chance": 0.0, "pair": false, "stars_needed": 20,
		"sky": "#ffd9b0", "ground": "#fbeedd", "accent": "#c06b34", "path": "#d9a877",
		"decor": ["coffee", "croissant", "cupcake", "heart", "donut", "sparkles", "cake", "tea"],
		"trophy": "Barista"},
	{"id": "plage", "name": "La Plage", "icon": "parasol", "tagline": "Sable chaud et glaces",
		"cats": ["plage", "gouter", "affaire"], "ordered": [], "ordered_chance": 0.0, "pair": true, "stars_needed": 32,
		"sky": "#9fe4ec", "ground": "#fff4d8", "accent": "#e8792f", "path": "#f4d495",
		"decor": ["palm", "parasol", "shell", "icecream", "kite", "wave", "sun", "watermelon"],
		"trophy": "Maître nageur"},
	{"id": "port", "name": "Le Port", "icon": "anchor", "tagline": "Embruns et bateaux",
		"cats": ["bateau", "marin", "maison"], "ordered": ["age"], "ordered_chance": 0.3, "pair": true, "stars_needed": 44,
		"sky": "#aee0f7", "ground": "#e4f4fb", "accent": "#2a7fb8", "path": "#f2dfa8",
		"decor": ["wave", "shell", "sailboat", "fish", "crab", "anchor", "whale", "dolphin"],
		"trophy": "Capitaine"},
	{"id": "foret", "name": "La Forêt", "icon": "fox", "tagline": "Sentiers et petites bêtes",
		"cats": ["sauvage", "cueillette", "equipement"], "ordered": ["age"], "ordered_chance": 0.4, "pair": true, "stars_needed": 58,
		"sky": "#b9dfb2", "ground": "#e7f0da", "accent": "#2e7a5c", "path": "#cfa77c",
		"decor": ["pine", "tree", "fox", "owl", "mushroom", "leaves", "hedgehog", "squirrel"],
		"trophy": "Garde forestier"},
	{"id": "festival", "name": "Le Festival", "icon": "tent", "tagline": "Musique, sport et chapeaux",
		"cats": ["instrument", "sport", "chapeau"], "ordered": ["street"], "ordered_chance": 0.5, "pair": true, "stars_needed": 72,
		"sky": "#ffc6dc", "ground": "#fde9f1", "accent": "#c43d7c", "path": "#f8d27a",
		"decor": ["balloon", "tent", "ferris", "carousel", "fireworks", "music", "party", "sparkles"],
		"trophy": "Maestro"},
	{"id": "montagne", "name": "La Montagne", "icon": "mountain", "tagline": "Neige, luge et fondue",
		"cats": ["hiver", "plat", "tenue"], "ordered": ["street"], "ordered_chance": 0.5, "pair": true, "stars_needed": 88,
		"sky": "#cde2f8", "ground": "#f3f8fd", "accent": "#3a6db5", "path": "#b9cde4",
		"decor": ["mountain", "snowflake", "snowman", "ski", "sled", "pine", "fondue", "scarf"],
		"trophy": "Premier de cordée"},
	{"id": "grenier", "name": "Le Grenier", "icon": "teddy", "tagline": "Trésors et vieux jouets",
		"cats": ["jouet", "loisir", "trouvaille"], "ordered": ["age", "street"], "ordered_chance": 0.6, "pair": true, "stars_needed": 104,
		"sky": "#ebd2ad", "ground": "#f8ecd9", "accent": "#9659b3", "path": "#d6b289",
		"decor": ["teddy", "yoyo", "dice", "books", "clock", "candle", "crystal", "doll"],
		"trophy": "Antiquaire"},
	{"id": "observatoire", "name": "L'Observatoire", "icon": "telescope", "tagline": "Les énigmes des étoiles",
		"cats": ["astre", "transport"], "ordered": ["age", "street"], "ordered_chance": 1.0, "pair": true, "stars_needed": 120,
		"sky": "#3b3878", "ground": "#5a4f9e", "accent": "#7c6cf0", "path": "#c9b8ff", "dark": true,
		"decor": ["moon2", "rocket", "milkyway", "sparkles", "glow", "star", "comet", "telescope"],
		"trophy": "Astronome"},
]


static func world_count() -> int:
	return WORLDS.size()


## Taille de grille d'un niveau : [nombre de catégories, nombre de valeurs].
static func level_size(w: int, l: int) -> Array:
	if l == LEVELS_PER_WORLD:
		return BOSS_SIZE[w]
	match w:
		0:
			return [3, 3] if l <= 3 else [3, 4]
		1:
			return [3, 4]
		2:
			return [3, 4] if l <= 4 else [4, 4]
		3, 4:
			return [4, 4]
		5:
			return [4, 4] if l <= 4 else [4, 5]
	return [4, 5]


static func level_mods(w: int, l: int) -> Array:
	if l == LEVELS_PER_WORLD:
		return BOSS_MODS[w]
	return SPECIAL[w].get(l, [])


static func is_boss(l: int) -> bool:
	return l == LEVELS_PER_WORLD


static func level_config(w: int, l: int) -> Dictionary:
	var size := level_size(w, l)
	var cfg := _config(w, size[0], size[1], "monde-%d-niveau-%d" % [w, l])
	cfg.level = l
	cfg.mods = level_mods(w, l)
	cfg.boss = is_boss(l)
	return cfg


## Défi du jour : un monde, une taille et parfois un modificateur tirés de la date.
static func daily_config(date: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("defi-" + date)
	var w := rng.randi_range(0, WORLDS.size() - 1)
	var items := 4 if rng.randf() < 0.6 else 5
	var cfg := _config(w, 4, items, "defi-" + date)
	cfg.daily = true
	cfg.mods = []
	if rng.randf() < 0.5:
		cfg.mods = [MODS.keys()[rng.randi_range(0, MODS.size() - 1)]]
	return cfg


static func _config(w: int, n_cats: int, items: int, seed_text: String) -> Dictionary:
	var world: Dictionary = WORLDS[w]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + "-cats")
	var themed: Array = world.cats.duplicate()
	var ordered: Array = world.ordered.duplicate()
	var slots := n_cats - 1
	var k := 0
	if slots > themed.size():
		k = slots - themed.size()
	elif not ordered.is_empty() and rng.randf() < float(world.ordered_chance):
		k = 1
	k = min(k, ordered.size())
	while themed.size() > slots - k:
		themed.remove_at(rng.randi_range(0, themed.size() - 1))
	while ordered.size() > k:
		ordered.remove_at(rng.randi_range(0, ordered.size() - 1))
	var cats: Array = []
	for id in themed:
		cats.append(CATS[id])
	for kind in ordered:
		cats.append({"ordered": kind})
	return {"world": w, "n_cats": n_cats, "items": items, "cats": cats, "seed": seed_text, "pair": world.pair}


static func color(w: int, key: String) -> Color:
	return Color(WORLDS[w][key])
